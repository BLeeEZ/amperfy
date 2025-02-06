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
    
    @MainActor func syncInitial(statusNotifyier: SyncCallbacks?) async throws {
        try await super.createCachedItemRepresentationsInCoreData(statusNotifyier: statusNotifyier)
        
        statusNotifyier?.notifySyncStarted(ofType: .genre, totalCount: 0)
        let genreResponse = try await self.subsonicServerApi.requestGenres()
        try await self.storage.async.perform { asyncCompanion in
            let parserDelegate = SsGenreParserDelegate(performanceMonitor: self.performanceMonitor, library: asyncCompanion.library, parseNotifier: statusNotifyier)
            try self.parse(response: genreResponse, delegate: parserDelegate, isThrowingErrorsAllowed: false)
        }
        
        statusNotifyier?.notifySyncStarted(ofType: .artist, totalCount: 0)
        let artistsResponse = try await self.subsonicServerApi.requestArtists()
        try await self.storage.async.perform { asyncCompanion in
            let parserDelegate = SsArtistParserDelegate(performanceMonitor: self.performanceMonitor, library: asyncCompanion.library, subsonicUrlCreator: self.subsonicServerApi, parseNotifier: statusNotifyier)
            try self.parse(response: artistsResponse, delegate: parserDelegate, isThrowingErrorsAllowed: false)
        }
        
        var pollCountArtist = 0
        self.storage.main.perform { companion in
            let artists = companion.library.getArtists().filter{ !$0.id.isEmpty }
            let albumCount = artists.reduce(0, { $0 + $1.remoteAlbumCount })
            pollCountArtist = max(1, Int(ceil(Double(albumCount) / Double(Self.maxItemCountToPollAtOnce))))
        }
        statusNotifyier?.notifySyncStarted(ofType: .album, totalCount: pollCountArtist)
        try await withThrowingTaskGroup(of: Void.self) { taskGroup in
            for index in Array(0...pollCountArtist) {
                taskGroup.addTask { @MainActor in
                    let albumsResponse = try await self.subsonicServerApi.requestAlbums(offset: index*Self.maxItemCountToPollAtOnce, count: Self.maxItemCountToPollAtOnce)
                    try await self.storage.async.perform { asyncCompanion in
                        let parserDelegate = SsAlbumParserDelegate(performanceMonitor: self.performanceMonitor, library: asyncCompanion.library, subsonicUrlCreator: self.subsonicServerApi, parseNotifier: statusNotifyier)
                        try self.parse(response: albumsResponse, delegate: parserDelegate, isThrowingErrorsAllowed: false)
                    }
                    statusNotifyier?.notifyParsedObject(ofType: .album)
                }
            }
            try await taskGroup.waitForAll()
        }
        
        try await self.storage.async.perform { asyncCompanion in
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
        
        statusNotifyier?.notifySyncStarted(ofType: .playlist, totalCount: 0)
        let playlistsResponse = try await self.subsonicServerApi.requestPlaylists()
        try await self.storage.async.perform { asyncCompanion in
            let parserDelegate = SsPlaylistParserDelegate(performanceMonitor: self.performanceMonitor, library: asyncCompanion.library)
            try self.parse(response: playlistsResponse, delegate: parserDelegate, isThrowingErrorsAllowed: false)
        }
        
        let isSupported = try await self.subsonicServerApi.requestServerPodcastSupport()
        guard isSupported else { return }
        statusNotifyier?.notifySyncStarted(ofType: .podcast, totalCount: 0)
        let podcastsResponse = try await self.subsonicServerApi.requestPodcasts()
        try await self.storage.async.perform { asyncCompanion in
            let parserDelegate = SsPodcastParserDelegate(performanceMonitor: self.performanceMonitor, library: asyncCompanion.library, subsonicUrlCreator: self.subsonicServerApi, parseNotifier: statusNotifyier)
            try self.parse(response: podcastsResponse, delegate: parserDelegate, isThrowingErrorsAllowed: false)
            parserDelegate.performPostParseOperations()
        }
    }
    
    @MainActor func sync(genre: Genre) async throws {
        guard isSyncAllowed else { return }
        try await withThrowingTaskGroup(of: Void.self) { taskGroup in
            genre.albums.forEach { album in
                taskGroup.addTask { @MainActor in
                    try await self.sync(album: album)
                }
            }
            try await taskGroup.waitForAll()
        }
    }
    
    @MainActor func sync(artist: Artist) async throws {
        guard isSyncAllowed, !artist.id.isEmpty else { return }
        let response = try await subsonicServerApi.requestArtist(id: artist.id)
        try await self.storage.async.perform { asyncCompanion in
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
        guard artist.remoteStatus == .available else { return }
        try await withThrowingTaskGroup(of: Void.self) { taskGroup in
            artist.albums.forEach { album in
                taskGroup.addTask { @MainActor in
                    try await self.sync(album: album)
                }
            }
            try await taskGroup.waitForAll()
        }
    }
    
    @MainActor func sync(album: Album) async throws {
        guard isSyncAllowed else { return }
        let albumsResponse = try await subsonicServerApi.requestAlbum(id: album.id)
        try await self.storage.async.perform { asyncCompanion in
            let parserDelegate = SsAlbumParserDelegate(performanceMonitor: self.performanceMonitor, library: asyncCompanion.library, subsonicUrlCreator: self.subsonicServerApi)
            do {
                try self.parse(response: albumsResponse, delegate: parserDelegate)
            } catch {
                if let responseError = error as? ResponseError, let subsonicError = responseError.asSubsonicError, !subsonicError.isRemoteAvailable {
                    let albumAsync = Album(managedObject: asyncCompanion.context.object(with: album.managedObject.objectID) as! AlbumMO)
                    let reportError = ResourceNotAvailableResponseError(statusCode: responseError.statusCode, message: "Album \"\(albumAsync.name)\" is no longer available on the server.", cleansedURL: albumsResponse.url?.asCleansedURL(cleanser: self.subsonicServerApi), data: albumsResponse.data)
                    albumAsync.markAsRemoteDeleted()
                    throw reportError
                } else {
                    throw error
                }
            }
        }
        
        guard album.remoteStatus == .available else { return }
        let albumResponse = try await self.subsonicServerApi.requestAlbum(id: album.id)
        try await self.storage.async.perform { asyncCompanion in
            let albumAsync = Album(managedObject: asyncCompanion.context.object(with: album.managedObject.objectID) as! AlbumMO)
            let oldSongs = Set(albumAsync.songs)
            let parserDelegate = SsSongParserDelegate(performanceMonitor: self.performanceMonitor, library: asyncCompanion.library, subsonicUrlCreator: self.subsonicServerApi)
            try self.parse(response: albumResponse, delegate: parserDelegate)
            let removedSongs = oldSongs.subtracting(parserDelegate.parsedSongs)
            removedSongs.lazy.compactMap{$0.asSong}.forEach {
                os_log("Song <%s> is remote deleted", log: self.log, type: .info, $0.displayString)
                $0.remoteStatus = .deleted
                albumAsync.managedObject.removeFromSongs($0.managedObject)
            }
            albumAsync.isCached = parserDelegate.isCollectionCached
            albumAsync.isSongsMetaDataSynced = true
        }
    }
    
    @MainActor func sync(song: Song) async throws {
        guard isSyncAllowed else { return }
        let response = try await subsonicServerApi.requestSongInfo(id: song.id)
        try await self.storage.async.perform { asyncCompanion in
            let parserDelegate = SsSongParserDelegate(performanceMonitor: self.performanceMonitor, library: asyncCompanion.library, subsonicUrlCreator: self.subsonicServerApi)
            try self.parse(response: response, delegate: parserDelegate)
        }
        try await self.syncLyrics(song: song)
    }
    
    @MainActor private func syncLyrics(song: Song) async throws {
        do {
            let isSupported = await self.subsonicServerApi.isOpenSubsonicExtensionSupported(extension: .songLyrics)
            guard isSupported else { return }
            let response = try await self.subsonicServerApi.requestLyricsBySongId(id: song.id)
            try await self.storage.async.perform { asyncCompanion in
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
        } catch {
            // do nothing
        }
    }
    
    @MainActor func sync(podcast: Podcast) async throws {
        guard isSyncAllowed else { return }
        let isSupported = try await subsonicServerApi.requestServerPodcastSupport()
        guard isSupported else { return }
        let response = try await self.subsonicServerApi.requestPodcastEpisodes(id: podcast.id)
        try await self.storage.async.perform { asyncCompanion in
            let podcastAsync = Podcast(managedObject: asyncCompanion.context.object(with: podcast.managedObject.objectID) as! PodcastMO)
            let oldEpisodes = Set(podcastAsync.episodes)
            
            let parserDelegate = SsPodcastEpisodeParserDelegate(performanceMonitor: self.performanceMonitor, podcast: podcastAsync, library: asyncCompanion.library, subsonicUrlCreator: self.subsonicServerApi)
            try self.parse(response: response, delegate: parserDelegate)
            parserDelegate.performPostParseOperations()
            
            let deletedEpisodes = oldEpisodes.subtracting(parserDelegate.parsedEpisodes)
            deletedEpisodes.forEach {
                os_log("Podcast Episode <%s> is remote deleted", log: self.log, type: .info, $0.displayString)
                $0.podcastStatus = .deleted
            }
            podcastAsync.isCached = parserDelegate.isCollectionCached
        }
    }
    
    @MainActor func syncNewestPodcastEpisodes() async throws {
        guard isSyncAllowed else { return }
        os_log("Sync newest podcast episodes", log: log, type: .info)
        let isSupported = try await subsonicServerApi.requestServerPodcastSupport()
        guard isSupported else { return }
        try await self.syncDownPodcastsWithoutEpisodes()
        let response = try await self.subsonicServerApi.requestNewestPodcasts()
        try await self.storage.async.perform { asyncCompanion in
            let parserDelegate = SsPodcastEpisodeParserDelegate(performanceMonitor: self.performanceMonitor, podcast: nil, library: asyncCompanion.library, subsonicUrlCreator: self.subsonicServerApi)
            try self.parse(response: response, delegate: parserDelegate)
            parserDelegate.performPostParseOperations()
        }
    }
    
    @MainActor func syncNewestAlbums(offset: Int, count: Int) async throws {
        guard isSyncAllowed else { return }
        os_log("Sync newest albums: offset: %i count: %i", log: log, type: .info, offset, count)
        let response = try await subsonicServerApi.requestNewestAlbums(offset: offset, count: count)
        try await self.storage.async.perform { asyncCompanion in
            let parserDelegate = SsAlbumParserDelegate(performanceMonitor: self.performanceMonitor, library: asyncCompanion.library, subsonicUrlCreator: self.subsonicServerApi)
            try self.parse(response: response, delegate: parserDelegate)
            let oldNewestAlbums = asyncCompanion.library.getNewestAlbums(offset: offset, count: count)
            oldNewestAlbums.forEach { $0.markAsNotNewAnymore() }
            parserDelegate.parsedAlbums.enumerated().forEach { (index, album) in
                album.updateIsNewestInfo(index: index+1+offset)
            }
        }
    }
    
    @MainActor func syncRecentAlbums(offset: Int, count: Int) async throws {
        guard isSyncAllowed else { return }
        os_log("Sync recent albums: offset: %i count: %i", log: log, type: .info, offset, count)
        let response = try await subsonicServerApi.requestRecentAlbums(offset: offset, count: count)
        try await self.storage.async.perform { asyncCompanion in
            let parserDelegate = SsAlbumParserDelegate(performanceMonitor: self.performanceMonitor, library: asyncCompanion.library, subsonicUrlCreator: self.subsonicServerApi)
            try self.parse(response: response, delegate: parserDelegate)
            let oldRecentAlbums = asyncCompanion.library.getRecentAlbums(offset: offset, count: count)
            oldRecentAlbums.forEach { $0.markAsNotRecentAnymore() }
            parserDelegate.parsedAlbums.enumerated().forEach { (index, album) in
                album.updateIsRecentInfo(index: index+1+offset)
            }
        }
    }
    
    @MainActor func syncFavoriteLibraryElements() async throws {
        guard isSyncAllowed else { return }
        let response = try await self.subsonicServerApi.requestFavoriteElements()
        try await self.storage.async.perform { asyncCompanion in
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
    
    @MainActor func syncRadios() async throws {
        guard isSyncAllowed else { return }
        let response = try await self.subsonicServerApi.requestRadios()
        try await self.storage.async.perform { asyncCompanion in
            let oldRadios = Set(asyncCompanion.library.getRadios())
            
            let parserDelegate = SsRadioParserDelegate(performanceMonitor: self.performanceMonitor, library: asyncCompanion.library)
            try self.parse(response: response, delegate: parserDelegate)
            
            let deletedRadios = oldRadios.subtracting(parserDelegate.parsedRadios)
            deletedRadios.forEach {
                os_log("Radio <%s> is remote deleted", log: self.log, type: .info, $0.displayString)
                $0.remoteStatus = .deleted
            }
        }
    }

    @MainActor func syncMusicFolders() async throws {
        guard isSyncAllowed else { return }
        let response = try await self.subsonicServerApi.requestMusicFolders()
        try await self.storage.async.perform { asyncCompanion in
            let parserDelegate = SsMusicFolderParserDelegate(performanceMonitor: self.performanceMonitor, library: asyncCompanion.library)
            try self.parse(response: response, delegate: parserDelegate)
        }
    }
    
    @MainActor func syncIndexes(musicFolder: MusicFolder) async throws {
        guard isSyncAllowed else { return }
        let response = try await self.subsonicServerApi.requestIndexes(musicFolderId: musicFolder.id)
        try await self.storage.async.perform { asyncCompanion in
            let musicFolderAsync = MusicFolder(managedObject: asyncCompanion.context.object(with: musicFolder.managedObject.objectID) as! MusicFolderMO)
            let parserDelegate = SsDirectoryParserDelegate(performanceMonitor: self.performanceMonitor, musicFolder: musicFolderAsync, library: asyncCompanion.library, subsonicUrlCreator: self.subsonicServerApi)
            try self.parse(response: response, delegate: parserDelegate)
            musicFolderAsync.isCached = parserDelegate.isCollectionCached
        }
    }
    
    @MainActor func sync(directory: Directory) async throws {
        guard isSyncAllowed else { return }
        let response = try await self.subsonicServerApi.requestMusicDirectory(id: directory.id)
        try await self.storage.async.perform { asyncCompanion in
            let directoryAsync = Directory(managedObject: asyncCompanion.context.object(with: directory.managedObject.objectID) as! DirectoryMO)
            let parserDelegate = SsDirectoryParserDelegate(performanceMonitor: self.performanceMonitor, directory: directoryAsync, library: asyncCompanion.library, subsonicUrlCreator: self.subsonicServerApi)
            try self.parse(response: response, delegate: parserDelegate)
            directoryAsync.isCached = parserDelegate.isCollectionCached
        }
    }
    
    @MainActor func requestRandomSongs(playlist: Playlist, count: Int) async throws {
        guard isSyncAllowed else { return }
        let response = try await self.subsonicServerApi.requestRandomSongs(count: count)
        try await self.storage.async.perform { asyncCompanion in
            let parserDelegate = SsSongParserDelegate(performanceMonitor: self.performanceMonitor, library: asyncCompanion.library, subsonicUrlCreator: self.subsonicServerApi)
            try self.parse(response: response, delegate: parserDelegate)
            playlist.getManagedObject(in: asyncCompanion.context, library: asyncCompanion.library).append(playables: parserDelegate.parsedSongs)
        }
    }
    
    @MainActor func requestPodcastEpisodeDelete(podcastEpisode: PodcastEpisode) async throws {
        guard isSyncAllowed else { return }
        let response = try await self.subsonicServerApi.requestPodcastEpisodeDelete(id: podcastEpisode.id)
        try self.parseForError(response: response)
    }
    
    @MainActor func syncDownPlaylistsWithoutSongs() async throws {
        guard isSyncAllowed else { return }
        let response = try await subsonicServerApi.requestPlaylists()
        try await self.storage.async.perform { asyncCompanion in
            let parserDelegate = SsPlaylistParserDelegate(performanceMonitor: self.performanceMonitor, library: asyncCompanion.library)
            try self.parse(response: response, delegate: parserDelegate)
        }
    }
    
    @MainActor func syncDown(playlist: Playlist) async throws {
        guard isSyncAllowed, playlist.id != "" else { return }
        os_log("Download playlist \"%s\" from server", log: log, type: .info, playlist.name)
        let response = try await subsonicServerApi.requestPlaylistSongs(id: playlist.id)
        try await self.storage.async.perform { asyncCompanion in
            let playlistAsync = playlist.getManagedObject(in: asyncCompanion.context, library: asyncCompanion.library)
            let parserDelegate = SsPlaylistSongsParserDelegate(performanceMonitor: self.performanceMonitor, playlist: playlistAsync, library: asyncCompanion.library, subsonicUrlCreator: self.subsonicServerApi)
            try self.parse(response: response, delegate: parserDelegate)
            playlistAsync.isCached = parserDelegate.isCollectionCached
        }
    }
    
    @MainActor private func validatePlaylistId(playlist: Playlist) async throws {
        if playlist.id == "" {
            try await createPlaylistRemote(playlist: playlist)
        }
        if playlist.id == "" {
            os_log("Playlist id was not assigned after creation", log: self.log, type: .info)
            throw BackendError.incorrectServerBehavior(message: "Playlist id was not assigned after creation")
        }
    }
    
    @MainActor func syncUpload(playlistToUpdateName playlist: Playlist) async throws {
        guard isSyncAllowed else { return }
        os_log("Upload name on playlist to: \"%s\"", log: log, type: .info, playlist.name)
        try await self.validatePlaylistId(playlist: playlist)
        let response = try await self.subsonicServerApi.requestPlaylistUpdate(id: playlist.id, name: playlist.name, songIndicesToRemove: [], songIdsToAdd: [])
        try self.parseForError(response: response)
    }
    
    @MainActor func syncUpload(playlistToAddSongs playlist: Playlist, songs: [Song]) async throws {
        guard isSyncAllowed, !songs.isEmpty else { return }
        os_log("Upload SongsAdded on playlist \"%s\"", log: log, type: .info, playlist.name)
        try await self.validatePlaylistId(playlist: playlist)
        let response = try await self.subsonicServerApi.requestPlaylistUpdate(id: playlist.id, name: playlist.name, songIndicesToRemove: [], songIdsToAdd: songs.compactMap{ $0.id })
        try self.parseForError(response: response)
    }
    
    @MainActor func syncUpload(playlistToDeleteSong playlist: Playlist, index: Int) async throws {
        guard isSyncAllowed else { return }
        os_log("Upload SongDelete on playlist \"%s\" at index: %i", log: log, type: .info, playlist.name, index)
        try await self.validatePlaylistId(playlist: playlist)
        let response = try await self.subsonicServerApi.requestPlaylistUpdate(id: playlist.id, name: playlist.name, songIndicesToRemove: [index], songIdsToAdd: [])
        try self.parseForError(response: response)
    }
    
    @MainActor func syncUpload(playlistToUpdateOrder playlist: Playlist) async throws {
        guard isSyncAllowed else { return }
        os_log("Upload OrderChange on playlist \"%s\"", log: log, type: .info, playlist.name)
        try await self.validatePlaylistId(playlist: playlist)
        let songIdsToAdd = playlist.playables.compactMap{ $0.id }
        let songIndicesToRemove = Array(0...songIdsToAdd.count-1)
        let response = try await self.subsonicServerApi.requestPlaylistUpdate(id: playlist.id, name: playlist.name, songIndicesToRemove: songIndicesToRemove, songIdsToAdd: songIdsToAdd)
        try self.parseForError(response: response)
    }
    
    @MainActor func syncUpload(playlistIdToDelete id: String) async throws {
        guard isSyncAllowed else { return }
        os_log("Upload Delete playlist \"%s\"", log: log, type: .info, id)
        let response = try await self.subsonicServerApi.requestPlaylistDelete(id: id)
        try self.parseForError(response: response)
    }
    
    @MainActor func syncDownPodcastsWithoutEpisodes() async throws {
        guard isSyncAllowed else { return }
        let isSupported = try await subsonicServerApi.requestServerPodcastSupport()
        guard isSupported else { return }
        
        let response = try await self.subsonicServerApi.requestPodcasts()
        try await self.storage.async.perform { asyncCompanion in
            let oldPodcasts = Set(asyncCompanion.library.getRemoteAvailablePodcasts())
            
            let parserDelegate = SsPodcastParserDelegate(performanceMonitor: self.performanceMonitor, library: asyncCompanion.library, subsonicUrlCreator: self.subsonicServerApi)
            try self.parse(response: response, delegate: parserDelegate)
            parserDelegate.performPostParseOperations()
            
            let deletedPodcasts = oldPodcasts.subtracting(parserDelegate.parsedPodcasts)
            deletedPodcasts.forEach {
                os_log("Podcast <%s> is remote deleted", log: self.log, type: .info, $0.title)
                $0.remoteStatus = .deleted
            }
        }
    }
    
    @MainActor func syncNowPlaying(song: Song, songPosition: NowPlayingSongPosition) async throws {
        guard isSyncAllowed else { return }
        switch songPosition {
        case .start:
            return try await scrobble(song: song, submission: false)
        case .end:
            return try await scrobble(song: song, submission: true)
        }
    }
    
    @MainActor func scrobble(song: Song, date: Date?) async throws {
        return try await scrobble(song: song, submission: true, date: date)
    }
    
    @MainActor private func scrobble(song: Song, submission: Bool, date: Date? = nil) async throws {
        guard isSyncAllowed else { return }
        if !submission {
            os_log("Now Playing Beginn: %s", log: log, type: .info, song.displayString)
        } else if let date = date {
            os_log("Scrobbled at %s: %s", log: log, type: .info, date.description, song.displayString)
        } else {
            os_log("Now Playing End (Scrobble): %s", log: log, type: .info, song.displayString)
        }
        let response = try await self.subsonicServerApi.requestScrobble(id: song.id, submission: submission, date: date)
        try self.parseForError(response: response)
    }
    
    @MainActor func setRating(song: Song, rating: Int) async throws {
        guard isSyncAllowed, rating >= 0 && rating <= 5 else { return }
        os_log("Rate %i stars: %s", log: log, type: .info, rating, song.displayString)
        let response = try await self.subsonicServerApi.requestRating(id: song.id, rating: rating)
        try self.parseForError(response: response)
    }
    
    @MainActor func setRating(album: Album, rating: Int) async throws {
        guard isSyncAllowed, rating >= 0 && rating <= 5 else { return }
        os_log("Rate %i stars: %s", log: log, type: .info, rating, album.name)
        let response = try await self.subsonicServerApi.requestRating(id: album.id, rating: rating)
        try self.parseForError(response: response)
    }
    
    @MainActor func setRating(artist: Artist, rating: Int) async throws {
        guard isSyncAllowed, rating >= 0 && rating <= 5 else { return }
        os_log("Rate %i stars: %s", log: log, type: .info, rating, artist.name)
        let response = try await self.subsonicServerApi.requestRating(id: artist.id, rating: rating)
        try self.parseForError(response: response)
    }
    
    @MainActor func setFavorite(song: Song, isFavorite: Bool) async throws {
        guard isSyncAllowed else { return }
        os_log("Set Favorite %s: %s", log: log, type: .info, isFavorite ? "TRUE" : "FALSE", song.displayString)
        let response = try await self.subsonicServerApi.requestSetFavorite(songId: song.id, isFavorite: isFavorite)
        try self.parseForError(response: response)
    }
    
    @MainActor func setFavorite(album: Album, isFavorite: Bool) async throws {
        guard isSyncAllowed else { return }
        os_log("Set Favorite %s: %s", log: log, type: .info, isFavorite ? "TRUE" : "FALSE", album.name)
        let response = try await self.subsonicServerApi.requestSetFavorite(albumId: album.id, isFavorite: isFavorite)
        try self.parseForError(response: response)
    }
    
    @MainActor func setFavorite(artist: Artist, isFavorite: Bool) async throws {
        guard isSyncAllowed else { return }
        os_log("Set Favorite %s: %s", log: log, type: .info, isFavorite ? "TRUE" : "FALSE", artist.name)
        let response = try await self.subsonicServerApi.requestSetFavorite(artistId: artist.id, isFavorite: isFavorite)
        try self.parseForError(response: response)
    }
    
    @MainActor func searchArtists(searchText: String) async throws {
        guard isSyncAllowed, searchText.count > 0 else { return }
        os_log("Search artists via API: \"%s\"", log: log, type: .info, searchText)
        let response = try await subsonicServerApi.requestSearchArtists(searchText: searchText)
        try await self.storage.async.perform { asyncCompanion in
            let parserDelegate = SsArtistParserDelegate(performanceMonitor: self.performanceMonitor, library: asyncCompanion.library, subsonicUrlCreator: self.subsonicServerApi)
            try self.parse(response: response, delegate: parserDelegate)
        }
    }
    
    @MainActor func searchAlbums(searchText: String) async throws {
        guard isSyncAllowed, searchText.count > 0 else { return }
        os_log("Search albums via API: \"%s\"", log: log, type: .info, searchText)
        let response = try await subsonicServerApi.requestSearchAlbums(searchText: searchText)
        try await self.storage.async.perform { asyncCompanion in
            let parserDelegate = SsAlbumParserDelegate(performanceMonitor: self.performanceMonitor, library: asyncCompanion.library, subsonicUrlCreator: self.subsonicServerApi)
            try self.parse(response: response, delegate: parserDelegate)
        }
    }
    
    @MainActor func searchSongs(searchText: String) async throws {
        guard isSyncAllowed, searchText.count > 0 else { return }
        os_log("Search songs via API: \"%s\"", log: log, type: .info, searchText)
        let response = try await subsonicServerApi.requestSearchSongs(searchText: searchText)
        try await self.storage.async.perform { asyncCompanion in
            let parserDelegate = SsSongParserDelegate(performanceMonitor: self.performanceMonitor, library: asyncCompanion.library, subsonicUrlCreator: self.subsonicServerApi)
            try self.parse(response: response, delegate: parserDelegate)
        }
    }
    
    @MainActor func parseLyrics(relFilePath: URL) async throws -> LyricsList {
        let parserDelegate = SsLyricsParserDelegate(performanceMonitor: self.performanceMonitor)
        guard let absFilePath = self.fileManager.getAbsoluteAmperfyPath(relFilePath: relFilePath) else {
            throw XMLParserResponseError(cleansedURL: nil, data: nil)
        }
        do {
            try self.parse(absFilePath: absFilePath, delegate: parserDelegate, isThrowingErrorsAllowed: false)
        } catch {
            throw XMLParserResponseError(cleansedURL: nil, data: nil)
        }
        guard let lyricsList = parserDelegate.lyricsList else {
            throw XMLParserResponseError(cleansedURL: nil, data: nil)
        }
        return lyricsList
    }
    
    @MainActor private func createPlaylistRemote(playlist: Playlist) async throws {
        os_log("Create playlist on server", log: log, type: .info)
        let response = try await subsonicServerApi.requestPlaylistCreate(name: playlist.name)
        try await self.storage.async.perform { asyncCompanion in
            let playlistAsync = playlist.getManagedObject(in: asyncCompanion.context, library: asyncCompanion.library)
            let parserDelegate = SsPlaylistSongsParserDelegate(performanceMonitor: self.performanceMonitor, playlist: playlistAsync, library: asyncCompanion.library, subsonicUrlCreator: self.subsonicServerApi)
            try self.parse(response: response, delegate: parserDelegate)
        }
        // Old api version -> need to match the created playlist via name
        if playlist.id == "" {
            try await self.updatePlaylistIdViaItsName(playlist: playlist)
        }
    }

    @MainActor private func updatePlaylistIdViaItsName(playlist: Playlist) async throws {
        try await syncDownPlaylistsWithoutSongs()
        try await self.storage.async.perform { asyncCompanion in
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
    
    private func parseForError(response: APIDataResponse) throws {
        let parserDelegate = SsPingParserDelegate(performanceMonitor: self.performanceMonitor)
        try self.parse(response: response, delegate: parserDelegate)
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
