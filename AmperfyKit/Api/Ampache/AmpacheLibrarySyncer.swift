//
//  AmpacheLibrarySyncer.swift
//  AmperfyKit
//
//  Created by Maximilian Bauer on 09.03.19.
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
import UIKit
import PromiseKit

class AmpacheLibrarySyncer: LibrarySyncer {
    
    private let ampacheXmlServerApi: AmpacheXmlServerApi
    private let storage: PersistentStorage
    private let log = OSLog(subsystem: "Amperfy", category: "AmpacheLibSyncer")
    
    var isSyncAllowed: Bool {
        return Reachability.isConnectedToNetwork()
    }
    
    init(ampacheXmlServerApi: AmpacheXmlServerApi, storage: PersistentStorage) {
        self.ampacheXmlServerApi = ampacheXmlServerApi
        self.storage = storage
    }
    
    func syncInitial(statusNotifyier: SyncCallbacks?) -> Promise<Void> {
        return firstly {
            ampacheXmlServerApi.requesetLibraryMetaData()
        }.then { auth -> Promise<APIDataResponse> in
            statusNotifyier?.notifySyncStarted(ofType: .genre, totalCount: auth.genreCount)
            return self.ampacheXmlServerApi.requestGenres()
        }.then { response in
            self.storage.async.perform { asyncCompanion in
                let parserDelegate = GenreParserDelegate(library: asyncCompanion.library, parseNotifier: statusNotifyier)
                try self.parse(response: response, delegate: parserDelegate)
            }
        }.then {
            self.ampacheXmlServerApi.requesetLibraryMetaData()
        }.then { auth -> Promise<Void> in
            statusNotifyier?.notifySyncStarted(ofType: .artist, totalCount: auth.artistCount)
            let pollCountArtist = auth.artistCount / AmpacheXmlServerApi.maxItemCountToPollAtOnce
            let artistPromises: [() -> Promise<Void>] = Array(0...pollCountArtist).compactMap { index in return {
                return firstly {
                    self.ampacheXmlServerApi.requestArtists(startIndex: index*AmpacheXmlServerApi.maxItemCountToPollAtOnce)
                }.then { response in
                    self.storage.async.perform { asyncCompanion in
                        let parserDelegate = ArtistParserDelegate(library: asyncCompanion.library, parseNotifier: statusNotifyier)
                        try self.parse(response: response, delegate: parserDelegate)
                    }
                }
            }}
            return artistPromises.resolveSequentially()
        }.then {
            self.ampacheXmlServerApi.requesetLibraryMetaData()
        }.then { auth -> Promise<AuthentificationHandshake> in
            statusNotifyier?.notifySyncStarted(ofType: .album, totalCount: auth.albumCount)
            let pollCountAlbum = auth.albumCount / AmpacheXmlServerApi.maxItemCountToPollAtOnce
            let albumPromises: [() -> Promise<Void>] = Array(0...pollCountAlbum).compactMap { index in return {
                firstly {
                    self.ampacheXmlServerApi.requestAlbums(startIndex: index*AmpacheXmlServerApi.maxItemCountToPollAtOnce)
                }.then { response in
                    self.storage.async.perform { asyncCompanion in
                        let parserDelegate = AlbumParserDelegate(library: asyncCompanion.library, parseNotifier: statusNotifyier)
                        try self.parse(response: response, delegate: parserDelegate)
                    }
                }
            }}
            return albumPromises.resolveSequentially().map{ (auth) }
        }.then { (auth) -> Promise<APIDataResponse> in
            statusNotifyier?.notifySyncStarted(ofType: .playlist, totalCount: auth.playlistCount)
            return self.ampacheXmlServerApi.requestPlaylists()
        }.then { response in
            self.storage.async.perform { asyncCompanion in
                let parserDelegate = PlaylistParserDelegate(library: asyncCompanion.library, parseNotifier: statusNotifyier)
                try self.parse(response: response, delegate: parserDelegate)
            }
        }.then {
            self.ampacheXmlServerApi.requesetLibraryMetaData()
        }.then { auth in
            self.ampacheXmlServerApi.requestServerPodcastSupport().map{ ($0, auth) }
        }.then { (isSupported, auth) -> Promise<Void> in
            guard isSupported else { return Promise.value }
            statusNotifyier?.notifySyncStarted(ofType: .podcast, totalCount: auth.podcastCount)
            return firstly {
                self.ampacheXmlServerApi.requestPodcasts()
            }.then { response in
                self.storage.async.perform { asyncCompanion in
                    let parserDelegate = PodcastParserDelegate(library: asyncCompanion.library, parseNotifier: statusNotifyier)
                    try self.parse(response: response, delegate: parserDelegate)
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
        guard isSyncAllowed else { return Promise.value }
        return firstly {
            ampacheXmlServerApi.requestArtistInfo(id: artist.id)
        }.then { response in
            self.storage.async.perform { asyncCompanion in
                let parserDelegate = ArtistParserDelegate(library: asyncCompanion.library)
                do {
                    try self.parse(response: response, delegate: parserDelegate)
                } catch {
                    if let responseError = error as? ResponseError, let ampacheError = responseError.asAmpacheError, !ampacheError.isRemoteAvailable {
                        os_log("Artist <%s> is remote deleted", log: self.log, type: .info, artist.name)
                        artist.remoteStatus = .deleted
                    } else {
                        throw error
                    }
                }
            }
        }.then { () -> Promise<Void> in
            guard artist.remoteStatus == .available else { return Promise.value }
            return firstly {
                self.ampacheXmlServerApi.requestArtistAlbums(id: artist.id)
            }.then { response in
                self.storage.async.perform { asyncCompanion in
                    let artistAsync = Artist(managedObject: asyncCompanion.context.object(with: artist.managedObject.objectID) as! ArtistMO)
                    let oldAlbums = Set(artistAsync.albums)
                    let parserDelegate = AlbumParserDelegate(library: asyncCompanion.library)
                    try self.parse(response: response, delegate: parserDelegate)
                    let removedAlbums = oldAlbums.subtracting(parserDelegate.albumsParsed)
                    for album in removedAlbums {
                        os_log("Album <%s> is remote deleted", log: self.log, type: .info, album.name)
                        album.remoteStatus = .deleted
                        album.songs.forEach{
                            os_log("Song <%s> is remote deleted", log: self.log, type: .info, $0.displayString)
                            $0.remoteStatus = .deleted
                        }
                    }
                }
            }.then {
                self.ampacheXmlServerApi.requestArtistSongs(id: artist.id)
            }.then { response in
                self.storage.async.perform { asyncCompanion in
                    let artistAsync = Artist(managedObject: asyncCompanion.context.object(with: artist.managedObject.objectID) as! ArtistMO)
                    let oldSongs = Set(artistAsync.songs)
                    let parserDelegate = SongParserDelegate(library: asyncCompanion.library)
                    try self.parse(response: response, delegate: parserDelegate)
                    let removedSongs = oldSongs.subtracting(parserDelegate.parsedSongs)
                    removedSongs.lazy.compactMap{$0.asSong}.forEach {
                        os_log("Song <%s> is remote deleted", log: self.log, type: .info, $0.displayString)
                        $0.remoteStatus = .deleted
                    }
                }
            }
        }
    }
    
    func sync(album: Album) -> Promise<Void> {
        guard isSyncAllowed else { return Promise.value }
        return firstly {
            ampacheXmlServerApi.requestAlbumInfo(id: album.id)
        }.then { response in
            self.storage.async.perform { asyncCompanion in
                let parserDelegate = AlbumParserDelegate(library: asyncCompanion.library)
                do {
                    try self.parse(response: response, delegate: parserDelegate)
                } catch {
                    if let responseError = error as? ResponseError, let ampacheError = responseError.asAmpacheError, !ampacheError.isRemoteAvailable {
                        let albumAsync = Album(managedObject: asyncCompanion.context.object(with: album.managedObject.objectID) as! AlbumMO)
                        os_log("Album <%s> is remote deleted", log: self.log, type: .info, albumAsync.name)
                        albumAsync.markAsRemoteDeleted()
                    } else {
                        throw error
                    }
                }
            }
        }.then { () -> Promise<Void> in
            guard album.remoteStatus == .available else { return Promise.value }
            return firstly {
                self.ampacheXmlServerApi.requestAlbumSongs(id: album.id)
            }.then { response in
                self.storage.async.perform { asyncCompanion in
                    let albumAsync = Album(managedObject: asyncCompanion.context.object(with: album.managedObject.objectID) as! AlbumMO)
                    let oldSongs = Set(albumAsync.songs)
                    let parserDelegate = SongParserDelegate(library: asyncCompanion.library)
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
            ampacheXmlServerApi.requestSongInfo(id: song.id)
        }.then { response in
            self.storage.async.perform { asyncCompanion in
                let parserDelegate = SongParserDelegate(library: asyncCompanion.library)
                try self.parse(response: response, delegate: parserDelegate)
            }
        }
    }
    
    func sync(podcast: Podcast) -> Promise<Void> {
        guard isSyncAllowed else { return Promise.value }
        return firstly {
            ampacheXmlServerApi.requestServerPodcastSupport()
        }.then { isSupported -> Promise<Void> in
            guard isSupported else { return Promise.value }
            return firstly {
                self.ampacheXmlServerApi.requestPodcastEpisodes(id: podcast.id)
            }.then { response in
                self.storage.async.perform { asyncCompanion in
                    let podcastAsync = Podcast(managedObject: asyncCompanion.context.object(with: podcast.managedObject.objectID) as! PodcastMO)
                    let oldEpisodes = Set(podcastAsync.episodes)
                    
                    let parserDelegate = PodcastEpisodeParserDelegate(podcast: podcastAsync, library: asyncCompanion.library)
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
    
    func syncMusicFolders() -> Promise<Void> {
        guard isSyncAllowed else { return Promise.value }
        return firstly {
            ampacheXmlServerApi.requestCatalogs()
        }.then { response in
            self.storage.async.perform { asyncCompanion in
                let parserDelegate = CatalogParserDelegate(library: asyncCompanion.library)
                try self.parse(response: response, delegate: parserDelegate)
            }
        }
    }
    
    func syncIndexes(musicFolder: MusicFolder) -> Promise<Void> {
        guard isSyncAllowed else { return Promise.value }
        return firstly {
            ampacheXmlServerApi.requestArtistWithinCatalog(id: musicFolder.id)
        }.then { response in
            self.storage.async.perform { asyncCompanion in
                let parserDelegate = ArtistParserDelegate(library: asyncCompanion.library)
                try self.parse(response: response, delegate: parserDelegate)
                
                let musicFolderAsync = MusicFolder(managedObject: asyncCompanion.context.object(with: musicFolder.managedObject.objectID) as! MusicFolderMO)
                let directoriesBeforeFetch = Set(musicFolderAsync.directories)
                var directoriesAfterFetch: Set<Directory> = Set()
                for artist in parserDelegate.artistsParsed {
                    let artistDirId = "artist-\(artist.id)"
                    var curDir: Directory!
                    if let foundDir = asyncCompanion.library.getDirectory(id: artistDirId) {
                        curDir = foundDir
                    } else {
                        curDir = asyncCompanion.library.createDirectory()
                        curDir.id = artistDirId
                    }
                    curDir.name = artist.name
                    musicFolderAsync.managedObject.addToDirectories(curDir.managedObject)
                    directoriesAfterFetch.insert(curDir)
                }
                
                let removedDirectories = directoriesBeforeFetch.subtracting(directoriesAfterFetch)
                removedDirectories.forEach{ asyncCompanion.library.deleteDirectory(directory: $0) }
            }
        }
    }
    
    func sync(directory: Directory) -> Promise<Void> {
        guard isSyncAllowed else { return Promise.value }
        if directory.id.starts(with: "album-") {
            let albumId = String(directory.id.dropFirst("album-".count))
            return self.sync(directory: directory, thatIsAlbumId: albumId)
        } else if directory.id.starts(with: "artist-") {
            let artistId = String(directory.id.dropFirst("artist-".count))
            return self.sync(directory: directory, thatIsArtistId: artistId)
        } else {
            return Promise.value
        }
    }
    
    private func sync(directory: Directory, thatIsAlbumId albumId: String) -> Promise<Void> {
        guard let album = storage.main.library.getAlbum(id: albumId) else { return Promise.value }
        let songsBeforeFetch = Set(directory.songs)
        
        return firstly {
            self.sync(album: album)
        }.then {
            self.storage.async.perform { asyncCompanion in
                let directoryAsync = Directory(managedObject: asyncCompanion.context.object(with: directory.managedObject.objectID) as! DirectoryMO)
                let albumAsync = Album(managedObject: asyncCompanion.context.object(with: album.managedObject.objectID) as! AlbumMO)
                let songsBeforeFetchAsync = Set(songsBeforeFetch.compactMap {
                    Song(managedObject: asyncCompanion.context.object(with: $0.managedObject.objectID) as! SongMO)
                })
                
                directoryAsync.songs.forEach { directoryAsync.managedObject.removeFromSongs($0.managedObject) }
                let songsToRemove = songsBeforeFetchAsync.subtracting(Set(albumAsync.songs.compactMap{$0.asSong}))
                songsToRemove.lazy.compactMap{$0.asSong}.forEach{
                    directoryAsync.managedObject.removeFromSongs($0.managedObject)
                }
                albumAsync.songs.compactMap{$0.asSong}.forEach{
                    directoryAsync.managedObject.addToSongs($0.managedObject)
                }
            }
        }
    }
    
    private func sync(directory: Directory, thatIsArtistId artistId: String) -> Promise<Void> {
        guard let artist = storage.main.library.getArtist(id: artistId) else { return Promise.value }
        let directoriesBeforeFetch = Set(directory.subdirectories)
        
        return firstly {
            self.sync(artist: artist)
        }.then {
            self.storage.async.perform { asyncCompanion in
                let directoryAsync = Directory(managedObject: asyncCompanion.context.object(with: directory.managedObject.objectID) as! DirectoryMO)
                let artistAsync = Artist(managedObject: asyncCompanion.context.object(with: artist.managedObject.objectID) as! ArtistMO)
                let directoriesBeforeFetchAsync = Set(directoriesBeforeFetch.compactMap {
                    Directory(managedObject: asyncCompanion.context.object(with: $0.managedObject.objectID) as! DirectoryMO)
                })
                
                var directoriesAfterFetch: Set<Directory> = Set()
                let artistAlbums = asyncCompanion.library.getAlbums(whichContainsSongsWithArtist: artistAsync)
                for album in artistAlbums {
                    let albumDirId = "album-\(album.id)"
                    var albumDir: Directory!
                    if let foundDir = asyncCompanion.library.getDirectory(id: albumDirId) {
                        albumDir = foundDir
                    } else {
                        albumDir = asyncCompanion.library.createDirectory()
                        albumDir.id = albumDirId
                    }
                    albumDir.name = album.name
                    albumDir.artwork = album.artwork
                    directoryAsync.managedObject.addToSubdirectories(albumDir.managedObject)
                    directoriesAfterFetch.insert(albumDir)
                }
                
                let directoriesToRemove = directoriesBeforeFetchAsync.subtracting(directoriesAfterFetch)
                directoriesToRemove.forEach{
                    directoryAsync.managedObject.removeFromSubdirectories($0.managedObject)
                }
            }
        }
    }
    
    func syncRecentSongs() -> Promise<Void> {
        guard isSyncAllowed else { return Promise.value }
        os_log("Sync recently added songs", log: log, type: .info)
        return firstly {
            ampacheXmlServerApi.requestRecentSongs(count: 50)
        }.then { response in
            self.storage.async.perform { asyncCompanion in
                let oldRecentSongs = Set(asyncCompanion.library.getRecentSongs())
                let oldRecentAlbums = Set(asyncCompanion.library.getRecentAlbums())
                oldRecentAlbums.forEach{ $0.markAsNotRecentAnymore() }
                
                let parserDelegate = SongParserDelegate(library: asyncCompanion.library)
                try self.parse(response: response, delegate: parserDelegate)
                
                parserDelegate.parsedSongs.sortById().reversed().enumerated().forEach { (index, song) in
                    song.recentlyAddedIndex = index
                    if let album = song.album, album.recentlyAddedIndex == 0 {
                        album.recentlyAddedIndex = index
                    }
                }
                let notRecentSongsAnymore = oldRecentSongs.subtracting(parserDelegate.parsedSongs)
                notRecentSongsAnymore.forEach { $0.markAsNotRecentAnymore() }
            }
        }
    }
    
    func syncLatestLibraryElements() -> Promise<Void> {
        return syncRecentSongs()
    }
    
    func syncFavoriteLibraryElements() -> Promise<Void> {
        guard isSyncAllowed else { return Promise.value }
        return firstly {
            self.ampacheXmlServerApi.requestFavoriteArtists()
        }.then { response in
            self.storage.async.perform { asyncCompanion in
                os_log("Sync favorite artists", log: self.log, type: .info)
                let oldFavoriteArtists = Set(asyncCompanion.library.getFavoriteArtists())
                
                let parserDelegate = ArtistParserDelegate(library: asyncCompanion.library)
                try self.parse(response: response, delegate: parserDelegate)
                
                let notFavoriteArtistsAnymore = oldFavoriteArtists.subtracting(parserDelegate.artistsParsed)
                notFavoriteArtistsAnymore.forEach { $0.isFavorite = false }
            }
        }.then {
            self.ampacheXmlServerApi.requestFavoriteAlbums()
        }.then { response in
            self.storage.async.perform { asyncCompanion in
                os_log("Sync favorite albums", log: self.log, type: .info)
                let oldFavoriteAlbums = Set(asyncCompanion.library.getFavoriteAlbums())
                
                let parserDelegate = AlbumParserDelegate(library: asyncCompanion.library)
                try self.parse(response: response, delegate: parserDelegate)
                
                let notFavoriteAlbumsAnymore = oldFavoriteAlbums.subtracting(parserDelegate.albumsParsed)
                notFavoriteAlbumsAnymore.forEach { $0.isFavorite = false }
            }
        }.then {
            self.ampacheXmlServerApi.requestFavoriteSongs()
        }.then { response in
            self.storage.async.perform { asyncCompanion in
                os_log("Sync favorite songs", log: self.log, type: .info)
                let oldFavoriteSongs = Set(asyncCompanion.library.getFavoriteSongs())
                
                let parserDelegate = SongParserDelegate(library: asyncCompanion.library)
                try self.parse(response: response, delegate: parserDelegate)
                
                let notFavoriteSongsAnymore = oldFavoriteSongs.subtracting(parserDelegate.parsedSongs)
                notFavoriteSongsAnymore.forEach { $0.isFavorite = false }
            }
        }
    }
    
    func requestRandomSongs(playlist: Playlist, count: Int) -> Promise<Void> {
        guard isSyncAllowed else { return Promise.value }
        return firstly {
            ampacheXmlServerApi.requestRandomSongs(count: count)
        }.then { response in
            self.storage.async.perform { asyncCompanion in
                let parserDelegate = SongParserDelegate(library: asyncCompanion.library, parseNotifier: nil)
                try self.parse(response: response, delegate: parserDelegate)
                playlist.getManagedObject(in: asyncCompanion.context, library: asyncCompanion.library).append(playables: parserDelegate.parsedSongs)
            }
        }
    }
    
    func requestPodcastEpisodeDelete(podcastEpisode: PodcastEpisode) -> Promise<Void> {
        guard isSyncAllowed else { return Promise.value }
        return firstly {
            ampacheXmlServerApi.requestPodcastEpisodeDelete(id: podcastEpisode.id)
        }.then { response in
            self.parseForError(response: response)
        }
    }

    func syncDownPlaylistsWithoutSongs() -> Promise<Void> {
        guard isSyncAllowed else { return Promise.value }
        return firstly {
            ampacheXmlServerApi.requestPlaylists()
        }.then { response in
            self.storage.async.perform { asyncCompanion in
                let parserDelegate = PlaylistParserDelegate(library: asyncCompanion.library, parseNotifier: nil)
                try self.parse(response: response, delegate: parserDelegate)
            }
        }
    }
    
    func syncDown(playlist: Playlist) -> Promise<Void> {
        guard isSyncAllowed else { return Promise.value }
        os_log("Download playlist \"%s\" from server", log: log, type: .info, playlist.name)
        return firstly {
            validatePlaylistId(playlist: playlist)
        }.get {
            os_log("Sync songs of playlist \"%s\"", log: self.log, type: .info, playlist.name)
        }.then {
            self.ampacheXmlServerApi.requestPlaylistSongs(id: playlist.id)
        }.then { response in
            self.storage.async.perform { asyncCompanion in
                let playlistAsync = playlist.getManagedObject(in: asyncCompanion.context, library: asyncCompanion.library)
                let parserDelegate = PlaylistSongsParserDelegate(playlist: playlistAsync, library: asyncCompanion.library)
                try self.parse(response: response, delegate: parserDelegate)
                playlistAsync.ensureConsistentItemOrder()
            }
        }
    }
    
    func syncUpload(playlistToAddSongs playlist: Playlist, songs: [Song]) -> Promise<Void> {
        guard isSyncAllowed, !songs.isEmpty else { return Promise.value }
        os_log("Upload SongsAdded on playlist \"%s\"", log: log, type: .info, playlist.name)
        return firstly {
            validatePlaylistId(playlist: playlist)
        }.then { () -> Promise<Void> in
            let playlistAddSongPromises = songs.compactMap { song in return {
                return firstly {
                    self.ampacheXmlServerApi.requestPlaylistAddSong(playlistId: playlist.id, songId: song.id)
                }.then { response in
                    self.parseForError(response: response)
                }
            }}
            return playlistAddSongPromises.resolveSequentially()
        }
    }
    
    func syncUpload(playlistToDeleteSong playlist: Playlist, index: Int) -> Promise<Void> {
        guard isSyncAllowed else { return Promise.value }
        os_log("Upload SongDelete on playlist \"%s\" at index: %i", log: log, type: .info, playlist.name, index)
        return firstly {
            self.validatePlaylistId(playlist: playlist)
        }.then {
            self.ampacheXmlServerApi.requestPlaylistDeleteItem(id: playlist.id, index: index)
        }.then { response in
            self.parseForError(response: response)
        }
    }
    
    func syncUpload(playlistToUpdateName playlist: Playlist) -> Promise<Void> {
        guard isSyncAllowed else { return Promise.value }
        os_log("Upload name on playlist to: \"%s\"", log: log, type: .info, playlist.name)
        return firstly {
            self.ampacheXmlServerApi.requestPlaylistEditOnlyName(id: playlist.id, name: playlist.name)
        }.then { response in
            self.parseForError(response: response)
        }
    }
    
    func syncUpload(playlistToUpdateOrder playlist: Playlist) -> Promise<Void> {
        guard isSyncAllowed, playlist.songCount > 0 else { return Promise.value }
        os_log("Upload OrderChange on playlist \"%s\"", log: log, type: .info, playlist.name)
        let songIds = playlist.playables.compactMap{ $0.id }
        guard !songIds.isEmpty else { return Promise.value }
        return firstly {
            self.ampacheXmlServerApi.requestPlaylistEdit(id: playlist.id, songsIds: songIds)
        }.then { response in
            self.parseForError(response: response)
        }
    }
    
    func syncUpload(playlistIdToDelete id: String) -> Promise<Void> {
        guard isSyncAllowed else { return Promise.value }
        os_log("Upload Delete playlist \"%s\"", log: log, type: .info, id)
        return firstly {
            self.ampacheXmlServerApi.requestPlaylistDelete(id: id)
        }.then { response in
            self.parseForError(response: response)
        }
    }
    
    private func validatePlaylistId(playlist: Playlist) -> Promise<Void> {
        return firstly {
            self.ampacheXmlServerApi.requestPlaylist(id: playlist.id)
        }.then { response in
            self.storage.async.perform { asyncCompanion in
                let playlistAsync = playlist.getManagedObject(in: asyncCompanion.context, library: asyncCompanion.library)
                let parserDelegate = PlaylistParserDelegate(library: asyncCompanion.library, parseNotifier: nil, playlistToValidate: playlistAsync)
                try self.parse(response: response, delegate: parserDelegate)
            }
        }.then { () -> Promise<Void> in
            guard playlist.id == "" else { return Promise.value }
            os_log("Create playlist on server", log: self.log, type: .info)
            return firstly {
                self.ampacheXmlServerApi.requestPlaylistCreate(name: playlist.name)
            }.then { response in
                self.storage.async.perform { asyncCompanion in
                    let playlistAsync = playlist.getManagedObject(in: asyncCompanion.context, library: asyncCompanion.library)
                    let parserDelegate = PlaylistParserDelegate(library: asyncCompanion.library, parseNotifier: nil, playlistToValidate: playlistAsync)
                    try self.parse(response: response, delegate: parserDelegate)
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
    }
    
    func syncDownPodcastsWithoutEpisodes() -> Promise<Void> {
        guard isSyncAllowed else { return Promise.value }
        return firstly {
            self.ampacheXmlServerApi.requestServerPodcastSupport()
        }.then { isSupported -> Promise<Void> in
            guard isSupported else { return Promise.value}
            return firstly {
                self.ampacheXmlServerApi.requestPodcasts()
            }.then { response in
                self.storage.async.perform { asyncCompanion in
                    let oldPodcasts = Set(asyncCompanion.library.getRemoteAvailablePodcasts())
                    
                    let parserDelegate = PodcastParserDelegate(library: asyncCompanion.library)
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
    
    func scrobble(song: Song, date: Date?) -> Promise<Void> {
        guard isSyncAllowed else { return Promise.value }
        if let date = date {
            os_log("Scrobbled at %s: %s", log: log, type: .info, date.description, song.displayString)
        } else {
            os_log("Scrobble now: %s", log: log, type: .info, song.displayString)
        }
        return firstly {
            self.ampacheXmlServerApi.requestRecordPlay(songId: song.id, date: date)
        }.then { response in
            self.parseForError(response: response)
        }
    }
    
    func setRating(song: Song, rating: Int) -> Promise<Void> {
        guard isSyncAllowed, rating >= 0 && rating <= 5 else { return Promise.value }
        os_log("Rate %i stars: %s", log: log, type: .info, rating, song.displayString)
        return firstly {
            self.ampacheXmlServerApi.requestRate(songId: song.id, rating: rating)
        }.then { response in
            self.parseForError(response: response)
        }
    }
    
    func setRating(album: Album, rating: Int) -> Promise<Void> {
        guard isSyncAllowed, rating >= 0 && rating <= 5 else { return Promise.value }
        os_log("Rate %i stars: %s", log: log, type: .info, rating, album.name)
        return firstly {
            self.ampacheXmlServerApi.requestRate(albumId: album.id, rating: rating)
        }.then { response in
            self.parseForError(response: response)
        }
    }
    
    func setRating(artist: Artist, rating: Int) -> Promise<Void> {
        guard isSyncAllowed, rating >= 0 && rating <= 5 else { return Promise.value }
        os_log("Rate %i stars: %s", log: log, type: .info, rating, artist.name)
        return firstly {
            self.ampacheXmlServerApi.requestRate(artistId: artist.id, rating: rating)
        }.then { response in
            self.parseForError(response: response)
        }
    }
    
    func setFavorite(song: Song, isFavorite: Bool) -> Promise<Void> {
        guard isSyncAllowed else { return Promise.value }
        os_log("Set Favorite %s: %s", log: log, type: .info, isFavorite ? "TRUE" : "FALSE", song.displayString)
        return firstly {
            self.ampacheXmlServerApi.requestSetFavorite(songId: song.id, isFavorite: isFavorite)
        }.then { response in
            self.parseForError(response: response)
        }
    }
    
    func setFavorite(album: Album, isFavorite: Bool) -> Promise<Void> {
        guard isSyncAllowed else { return Promise.value }
        os_log("Set Favorite %s: %s", log: log, type: .info, isFavorite ? "TRUE" : "FALSE", album.name)
        return firstly {
            self.ampacheXmlServerApi.requestSetFavorite(albumId: album.id, isFavorite: isFavorite)
        }.then { response in
            self.parseForError(response: response)
        }
    }
    
    func setFavorite(artist: Artist, isFavorite: Bool) -> Promise<Void> {
        guard isSyncAllowed else { return Promise.value }
        os_log("Set Favorite %s: %s", log: log, type: .info, isFavorite ? "TRUE" : "FALSE", artist.name)
        return firstly {
            self.ampacheXmlServerApi.requestSetFavorite(artistId: artist.id, isFavorite: isFavorite)
        }.then { response in
            self.parseForError(response: response)
        }
    }

    func searchArtists(searchText: String) -> Promise<Void> {
        guard isSyncAllowed, searchText.count > 0 else { return Promise.value }
        os_log("Search artists via API: \"%s\"", log: log, type: .info, searchText)
        return firstly {
            ampacheXmlServerApi.requestSearchArtists(searchText: searchText)
        }.then { response in
            self.storage.async.perform { asyncCompanion in
                let parserDelegate = ArtistParserDelegate(library: asyncCompanion.library)
                try self.parse(response: response, delegate: parserDelegate)
            }
        }
    }
    
    func searchAlbums(searchText: String) -> Promise<Void> {
        guard isSyncAllowed, searchText.count > 0 else { return Promise.value }
        os_log("Search albums via API: \"%s\"", log: log, type: .info, searchText)
        return firstly {
            ampacheXmlServerApi.requestSearchAlbums(searchText: searchText)
        }.then { response in
            self.storage.async.perform { asyncCompanion in
                let parserDelegate = AlbumParserDelegate(library: asyncCompanion.library)
                try self.parse(response: response, delegate: parserDelegate)
            }
        }
    }
    
    func searchSongs(searchText: String) -> Promise<Void> {
        guard isSyncAllowed, searchText.count > 0 else { return Promise.value }
        os_log("Search songs via API: \"%s\"", log: log, type: .info, searchText)
        return firstly {
            ampacheXmlServerApi.requestSearchSongs(searchText: searchText)
        }.then { response in
            self.storage.async.perform { asyncCompanion in
                let parserDelegate = SongParserDelegate(library: asyncCompanion.library)
                try self.parse(response: response, delegate: parserDelegate)
            }
        }
    }
    
    private func parseForError(response: APIDataResponse) -> Promise<Void> {
        Promise<Void> { seal in
            let parserDelegate = AmpacheXmlParser()
            try self.parse(response: response, delegate: parserDelegate)
            seal.fulfill(Void())
        }
    }
    
    private func parse(response: APIDataResponse, delegate: AmpacheXmlParser) throws {
        let parser = XMLParser(data: response.data)
        parser.delegate = delegate
        parser.parse()
        if let error = parser.parserError {
            os_log("Error during response parsing: %s", log: self.log, type: .error, error.localizedDescription)
            throw XMLParserResponseError(cleansedURL: response.url.asCleansedURL(cleanser: ampacheXmlServerApi))
        }
        if let error = delegate.error, let ampacheError = error.ampacheError, ampacheError.shouldErrorBeDisplayedToUser {
            throw ResponseError.createFromAmpacheError(cleansedURL: response.url.asCleansedURL(cleanser: ampacheXmlServerApi), error: error)
        }
    }

}
