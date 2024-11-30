//
//  SubsonicLibrarySyncer.swift
//  AmperfyKit
//
//  Created by Maximilian Bauer on 05.04.19.
//  Copyright (c) 2019 Maximilian Bauer. All rights reserved.
//
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program.  If not, see <http://www.gnu.org/licenses/>.
//

import Foundation
import CoreData
import os.log
import PromiseKit

class SubsonicLibrarySyncer: CommonLibrarySyncer, LibrarySyncer {

    private let subsonicServerApi: SubsonicServerApi
   
    private static let maxItemCountToPollAtOnce: Int = 500
    
    init(subsonicServerApi: SubsonicServerApi, networkMonitor: NetworkMonitorFacade, performanceMonitor: ThreadPerformanceMonitor, storage: PersistentStorage, eventLogger: EventLogger) {
        self.subsonicServerApi = subsonicServerApi
        super.init(networkMonitor: networkMonitor, performanceMonitor: performanceMonitor, storage: storage, eventLogger: eventLogger)
    }
    
    func syncInitial(statusNotifyier: SyncCallbacks?) -> Promise<Void> {
        return firstly {
            super.createCachedItemRepresentationsInCoreData(statusNotifyier: statusNotifyier)
        }.then { () -> Promise<APIDataResponse> in
            statusNotifyier?.notifySyncStarted(ofType: .genre, totalCount: 0)
            return self.subsonicServerApi.requestGenres()
        }.then { response in
            self.storage.async.perform { asyncCompanion in
                let parserDelegate = SsGenreParserDelegate(performanceMonitor: self.performanceMonitor, library: asyncCompanion.library, parseNotifier: statusNotifyier)
                try self.parse(response: response, delegate: parserDelegate, isThrowingErrorsAllowed: false)
            }
        }.then { () -> Promise<APIDataResponse> in
            statusNotifyier?.notifySyncStarted(ofType: .artist, totalCount: 0)
            return self.subsonicServerApi.requestArtists()
        }.then { response in
            self.storage.async.perform { asyncCompanion in
                let parserDelegate = SsArtistParserDelegate(performanceMonitor: self.performanceMonitor, library: asyncCompanion.library, subsonicUrlCreator: self.subsonicServerApi, parseNotifier: statusNotifyier)
                try self.parse(response: response, delegate: parserDelegate, isThrowingErrorsAllowed: false)
            }
        }.then { auth -> Promise<Void> in
            let artists = self.storage.main.library.getArtists().filter{ !$0.id.isEmpty }
            let albumCount = artists.reduce(0, { $0 + $1.albumCount })
            let pollCountArtist = max(1, Int(ceil(Double(albumCount) / Double(Self.maxItemCountToPollAtOnce))))
            statusNotifyier?.notifySyncStarted(ofType: .album, totalCount: pollCountArtist)
            let artistPromises: [() -> Promise<Void>] = Array(0...pollCountArtist).compactMap { index in return {
                return firstly {
                    self.subsonicServerApi.requestAlbums(offset: index*Self.maxItemCountToPollAtOnce, count: Self.maxItemCountToPollAtOnce)
                }.then { response in
                    self.storage.async.perform { asyncCompanion in
                        let parserDelegate = SsAlbumParserDelegate(performanceMonitor: self.performanceMonitor, library: asyncCompanion.library, subsonicUrlCreator: self.subsonicServerApi, parseNotifier: statusNotifyier)
                        try self.parse(response: response, delegate: parserDelegate, isThrowingErrorsAllowed: false)
                    }
                }.get {
                    statusNotifyier?.notifyParsedObject(ofType: .album)
                }
            }}
            return artistPromises.resolveSequentially()
        }.then { response in
            self.storage.async.perform { asyncCompanion in
                // Delete duplicated artists due to concurrence
                let allArtists = asyncCompanion.library.getArtists()
                var uniqueArtists: [String: Artist] = [:]
                for artist in allArtists {
                    if uniqueArtists[artist.id] != nil {
                        let artistAlbums = artist.albums
                        artistAlbums.forEach{ $0.artist = uniqueArtists[artist.id] }
                        os_log("Delete multiple Artist <%s> with id %s", log: self.log, type: .info, artist.name, artist.id)
                        asyncCompanion.library.deleteArtist(artist: artist)
                    } else {
                        uniqueArtists[artist.id] = artist
                    }
                }
                // Delete duplicated albums due to concurrence
                let albums = asyncCompanion.library.getAlbums()
                var uniqueAlbums: [String: Album] = [:]
                for album in albums {
                    if uniqueAlbums[album.id] != nil {
                        asyncCompanion.library.deleteAlbum(album: album)
                    } else {
                        uniqueAlbums[album.id] = album
                    }
                }
            }
        }.get {
            statusNotifyier?.notifySyncStarted(ofType: .playlist, totalCount: 0)
        }.then {
            self.subsonicServerApi.requestPlaylists()
        }.then { response in
            self.storage.async.perform { asyncCompanion in
                let parserDelegate = SsPlaylistParserDelegate(performanceMonitor: self.performanceMonitor, library: asyncCompanion.library)
                try self.parse(response: response, delegate: parserDelegate, isThrowingErrorsAllowed: false)
            }
        }.then {
            self.subsonicServerApi.requestServerPodcastSupport()
        }.then { isSupported -> Promise<Void> in
            guard isSupported else { return Promise.value }
            statusNotifyier?.notifySyncStarted(ofType: .podcast, totalCount: 0)
            return firstly {
                self.subsonicServerApi.requestPodcasts()
            }.then { response in
                self.storage.async.perform { asyncCompanion in
                    let parserDelegate = SsPodcastParserDelegate(performanceMonitor: self.performanceMonitor, library: asyncCompanion.library, subsonicUrlCreator: self.subsonicServerApi, parseNotifier: statusNotifyier)
                    try self.parse(response: response, delegate: parserDelegate, isThrowingErrorsAllowed: false)
                }
            }
        }
    }
    
    func sync(genre: Genre) -> Promise<Void> {
        guard isSyncAllowed else { return Promise.value }
        let albumSyncPromises = genre.albums.compactMap { album in return {
            self.sync(album: album)
        }}
        return albumSyncPromises.resolveSequentially()
    }
    
    func sync(artist: Artist) -> Promise<Void> {
        guard isSyncAllowed, !artist.id.isEmpty else { return Promise.value }
        return firstly {
            subsonicServerApi.requestArtist(id: artist.id)
        }.then { response in
            self.storage.async.perform { asyncCompanion in
                let parserDelegate = SsArtistParserDelegate(performanceMonitor: self.performanceMonitor, library: asyncCompanion.library, subsonicUrlCreator: self.subsonicServerApi)
                do {
                    try self.parse(response: response, delegate: parserDelegate)
                } catch {
                    if let responseError = error as? ResponseError, let subsonicError = responseError.asSubsonicError, !subsonicError.isRemoteAvailable {
                        let artistAsync = Artist(managedObject: asyncCompanion.context.object(with: artist.managedObject.objectID) as! ArtistMO)
                        let reportError = ResourceNotAvailableResponseError(statusCode: responseError.statusCode, message: "Artist \"\(artistAsync.name)\" is no longer available on the server.", cleansedURL: response.url?.asCleansedURL(cleanser: self.subsonicServerApi), data: response.data)
                        artistAsync.remoteStatus = .deleted
                        throw reportError
                    } else {
                        throw error
                    }
                }
            }
        }.then { () -> Promise<Void> in
            guard artist.remoteStatus == .available else { return Promise.value }
            let albumSyncPromises = artist.albums.compactMap { album in return {
                self.sync(album: album)
            }}
            return albumSyncPromises.resolveSequentially()
        }
    }
    
    func sync(album: Album) -> Promise<Void> {
        guard isSyncAllowed else { return Promise.value }
        return firstly {
            subsonicServerApi.requestAlbum(id: album.id)
        }.then { response in
            self.storage.async.perform { asyncCompanion in
                let parserDelegate = SsAlbumParserDelegate(performanceMonitor: self.performanceMonitor, library: asyncCompanion.library, subsonicUrlCreator: self.subsonicServerApi)
                do {
                    try self.parse(response: response, delegate: parserDelegate)
                } catch {
                    if let responseError = error as? ResponseError, let subsonicError = responseError.asSubsonicError, !subsonicError.isRemoteAvailable {
                        let albumAsync = Album(managedObject: asyncCompanion.context.object(with: album.managedObject.objectID) as! AlbumMO)
                        let reportError = ResourceNotAvailableResponseError(statusCode: responseError.statusCode, message: "Album \"\(albumAsync.name)\" is no longer available on the server.", cleansedURL: response.url?.asCleansedURL(cleanser: self.subsonicServerApi), data: response.data)
                        albumAsync.markAsRemoteDeleted()
                        throw reportError
                    } else {
                        throw error
                    }
                }
            }
        }.then { () -> Promise<Void> in
            guard album.remoteStatus == .available else { return Promise.value }
            return firstly {
                self.subsonicServerApi.requestAlbum(id: album.id)
            }.then { response in
                self.storage.async.perform { asyncCompanion in
                    let albumAsync = Album(managedObject: asyncCompanion.context.object(with: album.managedObject.objectID) as! AlbumMO)
                    let oldSongs = Set(albumAsync.songs)
                    let parserDelegate = SsSongParserDelegate(performanceMonitor: self.performanceMonitor, library: asyncCompanion.library, subsonicUrlCreator: self.subsonicServerApi)
                    try self.parse(response: response, delegate: parserDelegate)
                    let removedSongs = oldSongs.subtracting(parserDelegate.parsedSongs)
                    removedSongs.lazy.compactMap{$0.asSong}.forEach {
                        os_log("Song <%s> is remote deleted", log: self.log, type: .info, $0.displayString)
                        $0.remoteStatus = .deleted
                        albumAsync.managedObject.removeFromSongs($0.managedObject)
                    }
                    albumAsync.isSongsMetaDataSynced = true
                }
            }
        }
    }
    
    func sync(song: Song) -> Promise<Void> {
        guard isSyncAllowed else { return Promise.value }
        return firstly {
            subsonicServerApi.requestSongInfo(id: song.id)
        }.then { response in
            self.storage.async.perform { asyncCompanion in
                let parserDelegate = SsSongParserDelegate(performanceMonitor: self.performanceMonitor, library: asyncCompanion.library, subsonicUrlCreator: self.subsonicServerApi)
                try self.parse(response: response, delegate: parserDelegate)
            }
        }.then {
            self.syncLyrics(song: song)
        }
    }
    
    private func syncLyrics(song: Song) -> Promise<Void> {
        return Promise<Void> { seal in
            firstly {
                self.subsonicServerApi.isOpenSubsonicExtensionSupported(extension: .songLyrics)
            }.then { isSupported -> Promise<Void> in
                guard isSupported else { return Promise.value }
                return firstly {
                    self.subsonicServerApi.requestLyricsBySongId(id: song.id)
                }.then { response in
                    self.storage.async.perform { asyncCompanion in
                        guard let songAsyncMO = asyncCompanion.context.object(with: song.objectID) as? SongMO else { return }
                        let songAsync = Song(managedObject: songAsyncMO)
                        
                        guard let lyricsRelFilePath = self.fileManager.createRelPath(forLyricsOf: songAsync),
                              let lyricsAbsFilePath = self.fileManager.getAbsoluteAmperfyPath(relFilePath: lyricsRelFilePath)
                        else { return }
                        
                        let parserDelegate = SsLyricsParserDelegate(performanceMonitor: self.performanceMonitor)
                        try self.parse(response: response, delegate: parserDelegate, isThrowingErrorsAllowed: false)
                        // save xml response only if it contains valid lyrics
                        if (parserDelegate.lyricsList?.lyrics.count ?? 0) > 0 {
                            do {
                                try self.fileManager.writeDataExcludedFromBackup(data: response.data, to: lyricsAbsFilePath)
                                songAsync.lyricsRelFilePath = lyricsRelFilePath
                                os_log("Lyrics found for <%s> and saved to: %s", log: self.log, type: .info, songAsync.displayString, lyricsRelFilePath.path)
                            } catch {
                                songAsync.lyricsRelFilePath = nil
                            }
                        } else {
                            os_log("No lyrics available for <%s>", log: self.log, type: .info, songAsync.displayString)
                        }
                    }
                }
            }.done {
                seal.fulfill(Void())
            }.catch { error in
                seal.fulfill(Void())
            }
        }
    }
    
    func sync(podcast: Podcast) -> Promise<Void> {
        guard isSyncAllowed else { return Promise.value }
        return firstly {
            subsonicServerApi.requestServerPodcastSupport()
        }.then { isSupported -> Promise<Void> in
            guard isSupported else { return Promise.value }
            return firstly {
                self.subsonicServerApi.requestPodcastEpisodes(id: podcast.id)
            }.then { response in
                self.storage.async.perform { asyncCompanion in
                    let podcastAsync = Podcast(managedObject: asyncCompanion.context.object(with: podcast.managedObject.objectID) as! PodcastMO)
                    let oldEpisodes = Set(podcastAsync.episodes)
                    
                    let parserDelegate = SsPodcastEpisodeParserDelegate(performanceMonitor: self.performanceMonitor, podcast: podcastAsync, library: asyncCompanion.library, subsonicUrlCreator: self.subsonicServerApi)
                    try self.parse(response: response, delegate: parserDelegate)
                    
                    let deletedEpisodes = oldEpisodes.subtracting(parserDelegate.parsedEpisodes)
                    deletedEpisodes.forEach {
                        os_log("Podcast Episode <%s> is remote deleted", log: self.log, type: .info, $0.displayString)
                        $0.podcastStatus = .deleted
                    }
                }
            }
        }
    }
    
    func syncNewestPodcastEpisodes() -> Promise<Void> {
        guard isSyncAllowed else { return Promise.value }
        os_log("Sync newest podcast episodes", log: log, type: .info)
        
        return firstly {
            subsonicServerApi.requestServerPodcastSupport()
        }.then { isSupported -> Promise<Void> in
            guard isSupported else { return Promise.value }
            return firstly {
                self.syncDownPodcastsWithoutEpisodes()
            }.then {
                self.subsonicServerApi.requestNewestPodcasts()
            }.then { response in
                self.storage.async.perform { asyncCompanion in
                    let parserDelegate = SsPodcastEpisodeParserDelegate(performanceMonitor: self.performanceMonitor, podcast: nil, library: asyncCompanion.library, subsonicUrlCreator: self.subsonicServerApi)
                    try self.parse(response: response, delegate: parserDelegate)
                }
            }
        }
    }
    
    func syncNewestAlbums(offset: Int, count: Int) -> Promise<Void> {
        guard isSyncAllowed else { return Promise.value }
        os_log("Sync newest albums: offset: %i count: %i", log: log, type: .info, offset, count)
        
        return firstly {
            subsonicServerApi.requestNewestAlbums(offset: offset, count: count)
        }.then { response in
            self.storage.async.perform { asyncCompanion in
                let parserDelegate = SsAlbumParserDelegate(performanceMonitor: self.performanceMonitor, library: asyncCompanion.library, subsonicUrlCreator: self.subsonicServerApi)
                try self.parse(response: response, delegate: parserDelegate)
                let oldNewestAlbums = asyncCompanion.library.getNewestAlbums(offset: offset, count: count)
                oldNewestAlbums.forEach { $0.markAsNotNewAnymore() }
                parserDelegate.parsedAlbums.enumerated().forEach { (index, album) in
                    album.updateIsNewestInfo(index: index+1+offset)
                }
            }
        }
    }
    
    func syncRecentAlbums(offset: Int, count: Int) -> Promise<Void> {
        guard isSyncAllowed else { return Promise.value }
        os_log("Sync recent albums: offset: %i count: %i", log: log, type: .info, offset, count)
        
        return firstly {
            subsonicServerApi.requestRecentAlbums(offset: offset, count: count)
        }.then { response in
            self.storage.async.perform { asyncCompanion in
                let parserDelegate = SsAlbumParserDelegate(performanceMonitor: self.performanceMonitor, library: asyncCompanion.library, subsonicUrlCreator: self.subsonicServerApi)
                try self.parse(response: response, delegate: parserDelegate)
                let oldRecentAlbums = asyncCompanion.library.getRecentAlbums(offset: offset, count: count)
                oldRecentAlbums.forEach { $0.markAsNotRecentAnymore() }
                parserDelegate.parsedAlbums.enumerated().forEach { (index, album) in
                    album.updateIsRecentInfo(index: index+1+offset)
                }
            }
        }
    }
    
    func syncFavoriteLibraryElements() -> Promise<Void> {
        guard isSyncAllowed else { return Promise.value }
        return firstly {
            self.subsonicServerApi.requestFavoriteElements()
        }.then { response in
            self.storage.async.perform { asyncCompanion in
                os_log("Sync favorite artists", log: self.log, type: .info)
                let oldFavoriteArtists = Set(asyncCompanion.library.getFavoriteArtists())
                let parserDelegateArtist = SsArtistParserDelegate(performanceMonitor: self.performanceMonitor, library: asyncCompanion.library, subsonicUrlCreator: self.subsonicServerApi)
                try self.parse(response: response, delegate: parserDelegateArtist)
                let notFavoriteArtistsAnymore = oldFavoriteArtists.subtracting(parserDelegateArtist.parsedArtists)
                notFavoriteArtistsAnymore.forEach { $0.isFavorite = false; $0.starredDate = nil }

                os_log("Sync favorite albums", log: self.log, type: .info)
                let oldFavoriteAlbums = Set(asyncCompanion.library.getFavoriteAlbums())
                let parserDelegateAlbum = SsAlbumParserDelegate(performanceMonitor: self.performanceMonitor, library: asyncCompanion.library, subsonicUrlCreator: self.subsonicServerApi)
                try self.parse(response: response, delegate: parserDelegateAlbum)
                let notFavoriteAlbumsAnymore = oldFavoriteAlbums.subtracting(parserDelegateAlbum.parsedAlbums)
                notFavoriteAlbumsAnymore.forEach { $0.isFavorite = false; $0.starredDate = nil }
            
                os_log("Sync favorite songs", log: self.log, type: .info)
                let oldFavoriteSongs = Set(asyncCompanion.library.getFavoriteSongs())
                let parserDelegateSong = SsSongParserDelegate(performanceMonitor: self.performanceMonitor, library: asyncCompanion.library, subsonicUrlCreator: self.subsonicServerApi)
                try self.parse(response: response, delegate: parserDelegateSong)
                let notFavoriteSongsAnymore = oldFavoriteSongs.subtracting(parserDelegateSong.parsedSongs)
                notFavoriteSongsAnymore.forEach { $0.isFavorite = false; $0.starredDate = nil }
            }
        }
    }

    func syncMusicFolders() -> Promise<Void> {
        guard isSyncAllowed else { return Promise.value }
        return firstly {
            self.subsonicServerApi.requestMusicFolders()
        }.then { response in
            self.storage.async.perform { asyncCompanion in
                let parserDelegate = SsMusicFolderParserDelegate(performanceMonitor: self.performanceMonitor, library: asyncCompanion.library)
                try self.parse(response: response, delegate: parserDelegate)
            }
        }
    }
    
    func syncIndexes(musicFolder: MusicFolder) -> Promise<Void> {
        guard isSyncAllowed else { return Promise.value }
        return firstly {
            self.subsonicServerApi.requestIndexes(musicFolderId: musicFolder.id)
        }.then { response in
            self.storage.async.perform { asyncCompanion in
                let musicFolderAsync = MusicFolder(managedObject: asyncCompanion.context.object(with: musicFolder.managedObject.objectID) as! MusicFolderMO)
                let parserDelegate = SsDirectoryParserDelegate(performanceMonitor: self.performanceMonitor, musicFolder: musicFolderAsync, library: asyncCompanion.library, subsonicUrlCreator: self.subsonicServerApi)
                try self.parse(response: response, delegate: parserDelegate)
            }
        }
    }
    
    func sync(directory: Directory) -> Promise<Void> {
        guard isSyncAllowed else { return Promise.value }
        return firstly {
            self.subsonicServerApi.requestMusicDirectory(id: directory.id)
        }.then { response in
            self.storage.async.perform { asyncCompanion in
                let directoryAsync = Directory(managedObject: asyncCompanion.context.object(with: directory.managedObject.objectID) as! DirectoryMO)
                let parserDelegate = SsDirectoryParserDelegate(performanceMonitor: self.performanceMonitor, directory: directoryAsync, library: asyncCompanion.library, subsonicUrlCreator: self.subsonicServerApi)
                try self.parse(response: response, delegate: parserDelegate)
            }
        }
    }
    
    func requestRandomSongs(playlist: Playlist, count: Int) -> Promise<Void> {
        guard isSyncAllowed else { return Promise.value }
        return firstly {
            self.subsonicServerApi.requestRandomSongs(count: count)
        }.then { response in
            self.storage.async.perform { asyncCompanion in
                let parserDelegate = SsSongParserDelegate(performanceMonitor: self.performanceMonitor, library: asyncCompanion.library, subsonicUrlCreator: self.subsonicServerApi)
                try self.parse(response: response, delegate: parserDelegate)
                playlist.getManagedObject(in: asyncCompanion.context, library: asyncCompanion.library).append(playables: parserDelegate.parsedSongs)
            }
        }
    }
    
    func requestPodcastEpisodeDelete(podcastEpisode: PodcastEpisode) -> Promise<Void> {
        guard isSyncAllowed else { return Promise.value }
        return firstly {
            self.subsonicServerApi.requestPodcastEpisodeDelete(id: podcastEpisode.id)
        }.then { response in
            self.parseForError(response: response)
        }
    }
    
    func syncDownPlaylistsWithoutSongs() -> Promise<Void> {
        guard isSyncAllowed else { return Promise.value }
        return firstly {
            subsonicServerApi.requestPlaylists()
        }.then { response in
            self.storage.async.perform { asyncCompanion in
                let parserDelegate = SsPlaylistParserDelegate(performanceMonitor: self.performanceMonitor, library: asyncCompanion.library)
                try self.parse(response: response, delegate: parserDelegate)
            }
        }
    }
    
    func syncDown(playlist: Playlist) -> Promise<Void> {
        guard isSyncAllowed, playlist.id != "" else { return Promise.value }
        os_log("Download playlist \"%s\" from server", log: log, type: .info, playlist.name)
        return firstly {
            subsonicServerApi.requestPlaylistSongs(id: playlist.id)
        }.then { response in
            self.storage.async.perform { asyncCompanion in
                let playlistAsync = playlist.getManagedObject(in: asyncCompanion.context, library: asyncCompanion.library)
                let parserDelegate = SsPlaylistSongsParserDelegate(performanceMonitor: self.performanceMonitor, playlist: playlistAsync, library: asyncCompanion.library, subsonicUrlCreator: self.subsonicServerApi)
                try self.parse(response: response, delegate: parserDelegate)
                playlistAsync.ensureConsistentItemOrder()
                playlistAsync.updateArtworkItems(isInitialUpdate: false)
            }
        }
    }
    
    private func validatePlaylistId(playlist: Playlist) -> Promise<Void> {
        return firstly { () -> Promise<Void> in
            if playlist.id == "" {
                return createPlaylistRemote(playlist: playlist)
            } else {
                return Promise.value
            }
        }.then { () -> Promise<Void> in
            if playlist.id == "" {
                os_log("Playlist id was not assigned after creation", log: self.log, type: .info)
                return Promise(error: BackendError.incorrectServerBehavior(message: "Playlist id was not assigned after creation"))
            } else {
                return Promise.value
            }
        }
    }
    
    func syncUpload(playlistToUpdateName playlist: Playlist) -> Promise<Void> {
        guard isSyncAllowed else { return Promise.value }
        os_log("Upload name on playlist to: \"%s\"", log: log, type: .info, playlist.name)
        return firstly {
            self.validatePlaylistId(playlist: playlist)
        }.then {
            self.subsonicServerApi.requestPlaylistUpdate(id: playlist.id, name: playlist.name, songIndicesToRemove: [], songIdsToAdd: [])
        }.then { response in
            self.parseForError(response: response)
        }
    }
    
    func syncUpload(playlistToAddSongs playlist: Playlist, songs: [Song]) -> Promise<Void> {
        guard isSyncAllowed, !songs.isEmpty else { return Promise.value }
        os_log("Upload SongsAdded on playlist \"%s\"", log: log, type: .info, playlist.name)
        return firstly {
            self.validatePlaylistId(playlist: playlist)
        }.then {
            self.subsonicServerApi.requestPlaylistUpdate(id: playlist.id, name: playlist.name, songIndicesToRemove: [], songIdsToAdd: songs.compactMap{ $0.id })
        }.then { response in
            self.parseForError(response: response)
        }
    }
    
    func syncUpload(playlistToDeleteSong playlist: Playlist, index: Int) -> Promise<Void> {
        guard isSyncAllowed else { return Promise.value }
        os_log("Upload SongDelete on playlist \"%s\" at index: %i", log: log, type: .info, playlist.name, index)
        return firstly {
            self.validatePlaylistId(playlist: playlist)
        }.then {
            self.subsonicServerApi.requestPlaylistUpdate(id: playlist.id, name: playlist.name, songIndicesToRemove: [index], songIdsToAdd: [])
        }.then { response in
            self.parseForError(response: response)
        }
    }
    
    func syncUpload(playlistToUpdateOrder playlist: Playlist) -> Promise<Void> {
        guard isSyncAllowed else { return Promise.value }
        os_log("Upload OrderChange on playlist \"%s\"", log: log, type: .info, playlist.name)
        return firstly {
            self.validatePlaylistId(playlist: playlist)
        }.then { () -> Promise<APIDataResponse> in
            let songIdsToAdd = playlist.playables.compactMap{ $0.id }
            let songIndicesToRemove = Array(0...songIdsToAdd.count-1)
            return self.subsonicServerApi.requestPlaylistUpdate(id: playlist.id, name: playlist.name, songIndicesToRemove: songIndicesToRemove, songIdsToAdd: songIdsToAdd)
        }.then { response in
            self.parseForError(response: response)
        }
    }
    
    func syncUpload(playlistIdToDelete id: String) -> Promise<Void> {
        guard isSyncAllowed else { return Promise.value }
        os_log("Upload Delete playlist \"%s\"", log: log, type: .info, id)
        return firstly {
            self.subsonicServerApi.requestPlaylistDelete(id: id)
        }.then { response in
            self.parseForError(response: response)
        }
    }
    
    func syncDownPodcastsWithoutEpisodes() -> Promise<Void> {
        guard isSyncAllowed else { return Promise.value }
        return firstly {
            subsonicServerApi.requestServerPodcastSupport()
        }.then { isSupported -> Promise<Void> in
            guard isSupported else { return Promise.value }
            return firstly {
                self.subsonicServerApi.requestPodcasts()
            }.then { response in
                self.storage.async.perform { asyncCompanion in
                    let oldPodcasts = Set(asyncCompanion.library.getRemoteAvailablePodcasts())
                    
                    let parserDelegate = SsPodcastParserDelegate(performanceMonitor: self.performanceMonitor, library: asyncCompanion.library, subsonicUrlCreator: self.subsonicServerApi)
                    try self.parse(response: response, delegate: parserDelegate)
                    
                    let deletedPodcasts = oldPodcasts.subtracting(parserDelegate.parsedPodcasts)
                    deletedPodcasts.forEach {
                        os_log("Podcast <%s> is remote deleted", log: self.log, type: .info, $0.title)
                        $0.remoteStatus = .deleted
                    }
                }
            }
        }
    }
    
    func syncNowPlaying(song: Song, songPosition: NowPlayingSongPosition) -> Promise<Void> {
        guard isSyncAllowed else { return Promise.value }
        switch songPosition {
        case .start:
            return scrobble(song: song, submission: false)
        case .end:
            return scrobble(song: song, submission: true)
        }
    }
    
    func scrobble(song: Song, date: Date?) -> Promise<Void> {
        return scrobble(song: song, submission: true, date: date)
    }
    
    private func scrobble(song: Song, submission: Bool, date: Date? = nil) -> Promise<Void> {
        guard isSyncAllowed else { return Promise.value }
        if !submission {
            os_log("Now Playing Beginn: %s", log: log, type: .info, song.displayString)
        } else if let date = date {
            os_log("Scrobbled at %s: %s", log: log, type: .info, date.description, song.displayString)
        } else {
            os_log("Now Playing End (Scrobble): %s", log: log, type: .info, song.displayString)
        }
        
        return firstly {
            self.subsonicServerApi.requestScrobble(id: song.id, submission: submission, date: date)
        }.then { response in
            self.parseForError(response: response)
        }
    }
    
    func setRating(song: Song, rating: Int) -> Promise<Void> {
        guard isSyncAllowed, rating >= 0 && rating <= 5 else { return Promise.value }
        os_log("Rate %i stars: %s", log: log, type: .info, rating, song.displayString)
        return firstly {
            self.subsonicServerApi.requestRating(id: song.id, rating: rating)
        }.then { response in
            self.parseForError(response: response)
        }
    }
    
    func setRating(album: Album, rating: Int) -> Promise<Void> {
        guard isSyncAllowed, rating >= 0 && rating <= 5 else { return Promise.value }
        os_log("Rate %i stars: %s", log: log, type: .info, rating, album.name)
        return firstly {
            self.subsonicServerApi.requestRating(id: album.id, rating: rating)
        }.then { response in
            self.parseForError(response: response)
        }
    }
    
    func setRating(artist: Artist, rating: Int) -> Promise<Void> {
        guard isSyncAllowed, rating >= 0 && rating <= 5 else { return Promise.value }
        os_log("Rate %i stars: %s", log: log, type: .info, rating, artist.name)
        return firstly {
            self.subsonicServerApi.requestRating(id: artist.id, rating: rating)
        }.then { response in
            self.parseForError(response: response)
        }
    }
    
    func setFavorite(song: Song, isFavorite: Bool) -> Promise<Void> {
        guard isSyncAllowed else { return Promise.value }
        os_log("Set Favorite %s: %s", log: log, type: .info, isFavorite ? "TRUE" : "FALSE", song.displayString)
        return firstly {
            self.subsonicServerApi.requestSetFavorite(songId: song.id, isFavorite: isFavorite)
        }.then { response in
            self.parseForError(response: response)
        }
    }
    
    func setFavorite(album: Album, isFavorite: Bool) -> Promise<Void> {
        guard isSyncAllowed else { return Promise.value }
        os_log("Set Favorite %s: %s", log: log, type: .info, isFavorite ? "TRUE" : "FALSE", album.name)
        return firstly {
            self.subsonicServerApi.requestSetFavorite(albumId: album.id, isFavorite: isFavorite)
        }.then { response in
            self.parseForError(response: response)
        }
    }
    
    func setFavorite(artist: Artist, isFavorite: Bool) -> Promise<Void> {
        guard isSyncAllowed else { return Promise.value }
        os_log("Set Favorite %s: %s", log: log, type: .info, isFavorite ? "TRUE" : "FALSE", artist.name)
        return firstly {
            self.subsonicServerApi.requestSetFavorite(artistId: artist.id, isFavorite: isFavorite)
        }.then { response in
            self.parseForError(response: response)
        }
    }
    
    func searchArtists(searchText: String) -> Promise<Void> {
        guard isSyncAllowed, searchText.count > 0 else { return Promise.value }
        os_log("Search artists via API: \"%s\"", log: log, type: .info, searchText)
        return firstly {
            subsonicServerApi.requestSearchArtists(searchText: searchText)
        }.then { response in
            self.storage.async.perform { asyncCompanion in
                let parserDelegate = SsArtistParserDelegate(performanceMonitor: self.performanceMonitor, library: asyncCompanion.library, subsonicUrlCreator: self.subsonicServerApi)
                try self.parse(response: response, delegate: parserDelegate)
            }
        }
    }
    
    func searchAlbums(searchText: String) -> Promise<Void> {
        guard isSyncAllowed, searchText.count > 0 else { return Promise.value }
        os_log("Search albums via API: \"%s\"", log: log, type: .info, searchText)
        return firstly {
            subsonicServerApi.requestSearchAlbums(searchText: searchText)
        }.then { response in
            self.storage.async.perform { asyncCompanion in
                let parserDelegate = SsAlbumParserDelegate(performanceMonitor: self.performanceMonitor, library: asyncCompanion.library, subsonicUrlCreator: self.subsonicServerApi)
                try self.parse(response: response, delegate: parserDelegate)
            }
        }
    }
    
    func searchSongs(searchText: String) -> Promise<Void> {
        guard isSyncAllowed, searchText.count > 0 else { return Promise.value }
        os_log("Search songs via API: \"%s\"", log: log, type: .info, searchText)
        return firstly {
            subsonicServerApi.requestSearchSongs(searchText: searchText)
        }.then { response in
            self.storage.async.perform { asyncCompanion in
                let parserDelegate = SsSongParserDelegate(performanceMonitor: self.performanceMonitor, library: asyncCompanion.library, subsonicUrlCreator: self.subsonicServerApi)
                try self.parse(response: response, delegate: parserDelegate)
            }
        }
    }
    
    func parseLyrics(relFilePath: URL) -> Promise<LyricsList> {
        return Promise<LyricsList> { seal in
            DispatchQueue.global().async {
                do {
                    let parserDelegate = SsLyricsParserDelegate(performanceMonitor: self.performanceMonitor)
                    guard let absFilePath = self.fileManager.getAbsoluteAmperfyPath(relFilePath: relFilePath) else {
                        seal.reject(XMLParserResponseError(cleansedURL: nil, data: nil))
                        return
                    }
                    try self.parse(absFilePath: absFilePath, delegate: parserDelegate, isThrowingErrorsAllowed: false)
                    guard let lyricsList = parserDelegate.lyricsList else {
                        seal.reject(XMLParserResponseError(cleansedURL: nil, data: nil))
                        return
                    }
                    seal.fulfill(lyricsList)
                } catch {
                    seal.reject(XMLParserResponseError(cleansedURL: nil, data: nil))
                }
            }
        }
    }
    
    private func createPlaylistRemote(playlist: Playlist) -> Promise<Void> {
        os_log("Create playlist on server", log: log, type: .info)
        return firstly {
            subsonicServerApi.requestPlaylistCreate(name: playlist.name)
        }.then { response in
            self.storage.async.perform { asyncCompanion in
                let playlistAsync = playlist.getManagedObject(in: asyncCompanion.context, library: asyncCompanion.library)
                let parserDelegate = SsPlaylistSongsParserDelegate(performanceMonitor: self.performanceMonitor, playlist: playlistAsync, library: asyncCompanion.library, subsonicUrlCreator: self.subsonicServerApi)
                try self.parse(response: response, delegate: parserDelegate)
            }
        }.then { () -> Promise<Void> in
            // Old api version -> need to match the created playlist via name
            if playlist.id == "" {
                return self.updatePlaylistIdViaItsName(playlist: playlist)
            } else {
                return Promise.value
            }
        }
    }

    private func updatePlaylistIdViaItsName(playlist: Playlist) -> Promise<Void> {
        return firstly {
            syncDownPlaylistsWithoutSongs()
        }.then {
            self.storage.async.perform { asyncCompanion in
                let playlistAsync = playlist.getManagedObject(in: asyncCompanion.context, library: asyncCompanion.library)
                let playlists = asyncCompanion.library.getPlaylists()
                let nameMatchingPlaylists = playlists.filter{ filterPlaylist in
                    return filterPlaylist.name == playlistAsync.name && filterPlaylist.id != ""
                }
                guard !nameMatchingPlaylists.isEmpty, let firstMatch = nameMatchingPlaylists.first else { return }
                let matchedId = firstMatch.id
                asyncCompanion.library.deletePlaylist(firstMatch)
                playlistAsync.id = matchedId
            }
        }
    }
    
    private func parseForError(response: APIDataResponse) -> Promise<Void> {
        Promise<Void> { seal in
            let parserDelegate = SsPingParserDelegate(performanceMonitor: self.performanceMonitor)
            try self.parse(response: response, delegate: parserDelegate)
            seal.fulfill(Void())
        }
    }
    
    private func parse(response: APIDataResponse, delegate: SsXmlParser, isThrowingErrorsAllowed: Bool = true) throws {
        let parser = XMLParser(data: response.data)
        parser.delegate = delegate
        parser.parse()
        if let error = parser.parserError, isThrowingErrorsAllowed {
            os_log("Error during response parsing: %s", log: self.log, type: .error, error.localizedDescription)
            throw XMLParserResponseError(cleansedURL: response.url?.asCleansedURL(cleanser: subsonicServerApi), data: response.data)
        }
        if let error = delegate.error, let _ = error.subsonicError, isThrowingErrorsAllowed {
            throw ResponseError.createFromSubsonicError(cleansedURL: response.url?.asCleansedURL(cleanser: subsonicServerApi), error: error, data: response.data)
        }
    }
    
    private func parse(absFilePath: URL, delegate: SsXmlParser, isThrowingErrorsAllowed: Bool = true) throws {
        guard let parser = XMLParser(contentsOf: absFilePath) else {
            throw XMLParserResponseError(cleansedURL: nil, data: nil)
        }
        parser.delegate = delegate
        parser.parse()
        if let error = parser.parserError, isThrowingErrorsAllowed {
            os_log("Error during response parsing: %s", log: self.log, type: .error, error.localizedDescription)
            throw XMLParserResponseError(cleansedURL: nil, data: nil)
        }
        if let error = delegate.error, let _ = error.subsonicError, isThrowingErrorsAllowed {
            throw XMLParserResponseError(cleansedURL: nil, data: nil)
        }
    }
    
}
