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

class SubsonicLibrarySyncer: LibrarySyncer {

    private let subsonicServerApi: SubsonicServerApi
    private let log = OSLog(subsystem: "Amperfy", category: "SubsonicLibSyncer")
    
    var isSyncAllowed: Bool {
        return Reachability.isConnectedToNetwork()
    }
    
    init(subsonicServerApi: SubsonicServerApi) {
        self.subsonicServerApi = subsonicServerApi
    }
    
    func syncInitial(persistentStorage: PersistentStorage, statusNotifyier: SyncCallbacks?) -> Promise<Void> {
        let library = LibraryStorage(context: persistentStorage.context)

        let syncWave = library.createSyncWave()
        syncWave.setMetaData(fromLibraryChangeDates: LibraryChangeDates())
        library.saveContext()
        
        return firstly { () -> Promise<Data> in
            statusNotifyier?.notifySyncStarted(ofType: .genre, totalCount: 0)
            return self.subsonicServerApi.requestGenres()
        }.then { data in
            persistentStorage.persistentContainer.performAsync { companion in
                let parserDelegate = SsGenreParserDelegate(library: companion.library, syncWave: companion.syncWave, parseNotifier: statusNotifyier)
                try self.parse(data: data, delegate: parserDelegate)
            }
        }.then { () -> Promise<Data> in
            statusNotifyier?.notifySyncStarted(ofType: .artist, totalCount: 0)
            return self.subsonicServerApi.requestArtists()
        }.then { data in
            persistentStorage.persistentContainer.performAsync { companion in
                let parserDelegate = SsArtistParserDelegate(library: companion.library, syncWave: companion.syncWave, subsonicUrlCreator: self.subsonicServerApi, parseNotifier: statusNotifyier)
                try self.parse(data: data, delegate: parserDelegate)
            }
        }.then { auth -> Promise<Void> in
            let artists = library.getArtists().filter{ !$0.id.isEmpty }
            statusNotifyier?.notifySyncStarted(ofType: .album, totalCount: artists.count)
            
            let artistPromises: [() -> Promise<Void>] = artists.compactMap { artist in return {
                return firstly {
                    self.subsonicServerApi.requestArtist(id: artist.id)
                }.then { data in
                    persistentStorage.persistentContainer.performAsync { companion in
                        let parserDelegate = SsAlbumParserDelegate(library: companion.library, syncWave: companion.syncWave, subsonicUrlCreator: self.subsonicServerApi, parseNotifier: statusNotifyier)
                        try self.parse(data: data, delegate: parserDelegate)
                    }
                }.get {
                    statusNotifyier?.notifyParsedObject(ofType: .album)
                }
            }}
            return artistPromises.resolveSequentially()
        }.then { data in
            persistentStorage.persistentContainer.performAsync { companion in
                // Delete duplicated artists due to concurrence
                let allArtists = companion.library.getArtists()
                var uniqueArtists: [String: Artist] = [:]
                for artist in allArtists {
                    if uniqueArtists[artist.id] != nil {
                        let artistAlbums = artist.albums
                        artistAlbums.forEach{ $0.artist = uniqueArtists[artist.id] }
                        os_log("Delete multiple Artist <%s> with id %s", log: self.log, type: .info, artist.name, artist.id)
                        companion.library.deleteArtist(artist: artist)
                    } else {
                        uniqueArtists[artist.id] = artist
                    }
                }
                // Delete duplicated albums due to concurrence
                let albums = companion.library.getAlbums()
                var uniqueAlbums: [String: Album] = [:]
                for album in albums {
                    if uniqueAlbums[album.id] != nil {
                        companion.library.deleteAlbum(album: album)
                    } else {
                        uniqueAlbums[album.id] = album
                    }
                }
            }
        }.get {
            statusNotifyier?.notifySyncStarted(ofType: .playlist, totalCount: 0)
        }.then {
            self.subsonicServerApi.requestPlaylists()
        }.then { data in
            persistentStorage.persistentContainer.performAsync { companion in
                let parserDelegate = SsPlaylistParserDelegate(library: companion.library)
                try self.parse(data: data, delegate: parserDelegate)
            }
        }.then {
            self.subsonicServerApi.requestServerPodcastSupport()
        }.then { isSupported -> Promise<Void> in
            if isSupported {
                statusNotifyier?.notifySyncStarted(ofType: .podcast, totalCount: 0)
                return firstly {
                    self.subsonicServerApi.requestPodcasts()
                }.then { data in
                    persistentStorage.persistentContainer.performAsync { companion in
                        let parserDelegate = SsPodcastParserDelegate(library: companion.library, syncWave: companion.syncWave, subsonicUrlCreator: self.subsonicServerApi, parseNotifier: statusNotifyier)
                        try self.parse(data: data, delegate: parserDelegate)
                    }
                }.then { data in
                    persistentStorage.persistentContainer.performAsync { companion in
                        companion.syncWave.syncState = .Done
                    }
                }
            } else {
                return persistentStorage.persistentContainer.performAsync { companion in
                    companion.syncWave.syncState = .Done
                }
            }
        }
    }
    
    func sync(genre: Genre, persistentContainer: NSPersistentContainer) -> Promise<Void> {
        guard isSyncAllowed else { return Promise.value }
        let albumSyncPromises = genre.albums.compactMap { album in return {
            self.sync(album: album, persistentContainer: persistentContainer)
        }}
        return albumSyncPromises.resolveSequentially()
    }
    
    func sync(artist: Artist, persistentContainer: NSPersistentContainer) -> Promise<Void> {
        guard isSyncAllowed else { return Promise.value }
        return firstly {
            subsonicServerApi.requestArtist(id: artist.id)
        }.then { data in
            persistentContainer.performAsync { companion in
                let parserDelegate = SsArtistParserDelegate(library: companion.library, syncWave: companion.syncWave, subsonicUrlCreator: self.subsonicServerApi)
                do {
                    try self.parse(data: data, delegate: parserDelegate)
                } catch {
                    if let responseError = error as? ResponseError, let subsonicError = responseError.asSubsonicError, !subsonicError.isRemoteAvailable {
                        let artistAsync = Artist(managedObject: companion.context.object(with: artist.managedObject.objectID) as! ArtistMO)
                        os_log("Artist <%s> is remote deleted", log: self.log, type: .info, artistAsync.name)
                        artistAsync.remoteStatus = .deleted
                    } else {
                        throw error
                    }
                }
            }
        }.then { () -> Promise<Void> in
            guard artist.remoteStatus == .available else { return Promise.value }
            let albumSyncPromises = artist.albums.compactMap { album in return {
                self.sync(album: album, persistentContainer: persistentContainer)
            }}
            return albumSyncPromises.resolveSequentially()
        }
    }
    
    func sync(album: Album, persistentContainer: NSPersistentContainer) -> Promise<Void> {
        guard isSyncAllowed else { return Promise.value }
        return firstly {
            subsonicServerApi.requestAlbum(id: album.id)
        }.then { data in
            persistentContainer.performAsync { companion in
                let parserDelegate = SsAlbumParserDelegate(library: companion.library, syncWave: companion.syncWave, subsonicUrlCreator: self.subsonicServerApi)
                do {
                    try self.parse(data: data, delegate: parserDelegate)
                } catch {
                    if let responseError = error as? ResponseError, let subsonicError = responseError.asSubsonicError, !subsonicError.isRemoteAvailable {
                        let albumAsync = Album(managedObject: companion.context.object(with: album.managedObject.objectID) as! AlbumMO)
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
                self.subsonicServerApi.requestAlbum(id: album.id)
            }.then { data in
                persistentContainer.performAsync { companion in
                    let albumAsync = Album(managedObject: companion.context.object(with: album.managedObject.objectID) as! AlbumMO)
                    let oldSongs = Set(albumAsync.songs)
                    let parserDelegate = SsSongParserDelegate(library: companion.library, syncWave: companion.syncWave, subsonicUrlCreator: self.subsonicServerApi)
                    try self.parse(data: data, delegate: parserDelegate)
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
    
    func sync(song: Song, persistentContainer: NSPersistentContainer) -> Promise<Void> {
        guard isSyncAllowed else { return Promise.value }
        return firstly {
            subsonicServerApi.requestSongInfo(id: song.id)
        }.then { data in
            persistentContainer.performAsync { companion in
                let parserDelegate = SsSongParserDelegate(library: companion.library, syncWave: companion.syncWave, subsonicUrlCreator: self.subsonicServerApi)
                try self.parse(data: data, delegate: parserDelegate)
            }
        }
    }
    
    func sync(podcast: Podcast, persistentContainer: NSPersistentContainer) -> Promise<Void> {
        guard isSyncAllowed else { return Promise.value }
        return firstly {
            subsonicServerApi.requestServerPodcastSupport()
        }.then { isSupported -> Promise<Void> in
            guard isSupported else { return Promise.value }
            return firstly {
                self.subsonicServerApi.requestPodcastEpisodes(id: podcast.id)
            }.then { data in
                persistentContainer.performAsync { companion in
                    let podcastAsync = Podcast(managedObject: companion.context.object(with: podcast.managedObject.objectID) as! PodcastMO)
                    let oldEpisodes = Set(podcastAsync.episodes)
                    
                    let parserDelegate = SsPodcastEpisodeParserDelegate(podcast: podcastAsync, library: companion.library, syncWave: companion.syncWave, subsonicUrlCreator: self.subsonicServerApi)
                    try self.parse(data: data, delegate: parserDelegate)
                    
                    let deletedEpisodes = oldEpisodes.subtracting(parserDelegate.parsedEpisodes)
                    deletedEpisodes.forEach {
                        os_log("Podcast Episode <%s> is remote deleted", log: self.log, type: .info, $0.displayString)
                        $0.podcastStatus = .deleted
                    }
                }
            }
        }
    }
    
    func syncLatestLibraryElements(persistentStorage: PersistentStorage) -> Promise<Void> {
        guard isSyncAllowed else { return Promise.value }
        os_log("Sync newest albums", log: log, type: .info)
        let library = LibraryStorage(context: persistentStorage.context)
        let oldRecentSongsMain = Set(library.getRecentSongs())
        var parsedAlbumsMain = [Album]()
        var recentlyAddedSongsMain: Set<Song> = Set()
        
        return firstly {
            subsonicServerApi.requestLatestAlbums()
        }.then { data in
            persistentStorage.persistentContainer.performAsync { companion in
                let parserDelegate = SsAlbumParserDelegate(library: companion.library, syncWave: companion.syncWave, subsonicUrlCreator: self.subsonicServerApi)
                try self.parse(data: data, delegate: parserDelegate)
                parsedAlbumsMain = parserDelegate.parsedAlbums.compactMap {
                    Album(managedObject: persistentStorage.context.object(with: $0.managedObject.objectID) as! AlbumMO)
                }
            }
        }.then { () -> Promise<Void> in
            os_log("Sync songs of newest albums", log: self.log, type: .info)
            let albumPromises = parsedAlbumsMain.compactMap { album in return {
                return firstly {
                    self.subsonicServerApi.requestAlbum(id: album.id)
                }.then { data in
                    persistentStorage.persistentContainer.performAsync { companion in
                        let parserDelegate = SsSongParserDelegate(library: companion.library, syncWave: companion.syncWave, subsonicUrlCreator: self.subsonicServerApi)
                        try self.parse(data: data, delegate: parserDelegate)
                        let parsedSongsMain = parserDelegate.parsedSongs.compactMap {
                            Song(managedObject: persistentStorage.context.object(with: $0.managedObject.objectID) as! SongMO)
                        }
                        recentlyAddedSongsMain = recentlyAddedSongsMain.union(Set(parsedSongsMain))
                    }
                }.then { () -> Promise<Void> in
                    album.isSongsMetaDataSynced = true
                    library.saveContext()
                    return Promise.value
                }
            }}
            return albumPromises.resolveSequentially()
        }.get {
            os_log("%i newest Albums synced", log: self.log, type: .info, parsedAlbumsMain.count)
            let notRecentSongsAnymore = oldRecentSongsMain.subtracting(recentlyAddedSongsMain)
            notRecentSongsAnymore.filter{ !$0.id.isEmpty }.forEach { $0.isRecentlyAdded = false }
            recentlyAddedSongsMain.filter{ !$0.id.isEmpty }.forEach { $0.isRecentlyAdded = true }
            library.saveContext()
        }
    }
    
    func syncFavoriteLibraryElements(persistentStorage: PersistentStorage) -> Promise<Void> {
        guard isSyncAllowed else { return Promise.value }
        return firstly {
            self.subsonicServerApi.requestFavoriteElements()
        }.then { data in
            persistentStorage.persistentContainer.performAsync { companion in
                os_log("Sync favorite artists", log: self.log, type: .info)
                let oldFavoriteArtists = Set(companion.library.getFavoriteArtists())
                let parserDelegateArtist = SsArtistParserDelegate(library: companion.library, syncWave: companion.syncWave, subsonicUrlCreator: self.subsonicServerApi)
                try self.parse(data: data, delegate: parserDelegateArtist)
                let notFavoriteArtistsAnymore = oldFavoriteArtists.subtracting(parserDelegateArtist.parsedArtists)
                notFavoriteArtistsAnymore.forEach { $0.isFavorite = false }

                os_log("Sync favorite albums", log: self.log, type: .info)
                let oldFavoriteAlbums = Set(companion.library.getFavoriteAlbums())
                let parserDelegateAlbum = SsAlbumParserDelegate(library: companion.library, syncWave: companion.syncWave, subsonicUrlCreator: self.subsonicServerApi)
                try self.parse(data: data, delegate: parserDelegateAlbum)
                let notFavoriteAlbumsAnymore = oldFavoriteAlbums.subtracting(parserDelegateAlbum.parsedAlbums)
                notFavoriteAlbumsAnymore.forEach { $0.isFavorite = false }
            
                os_log("Sync favorite songs", log: self.log, type: .info)
                let oldFavoriteSongs = Set(companion.library.getFavoriteSongs())
                let parserDelegateSong = SsSongParserDelegate(library: companion.library, syncWave: companion.syncWave, subsonicUrlCreator: self.subsonicServerApi)
                try self.parse(data: data, delegate: parserDelegateSong)
                let notFavoriteSongsAnymore = oldFavoriteSongs.subtracting(parserDelegateSong.parsedSongs)
                notFavoriteSongsAnymore.forEach { $0.isFavorite = false }
            }
        }
    }

    func syncMusicFolders(persistentContainer: NSPersistentContainer) -> Promise<Void> {
        guard isSyncAllowed else { return Promise.value }
        return firstly {
            self.subsonicServerApi.requestMusicFolders()
        }.then { data in
            persistentContainer.performAsync { companion in
                let parserDelegate = SsMusicFolderParserDelegate(library: companion.library, syncWave: companion.syncWave)
                try self.parse(data: data, delegate: parserDelegate)
            }
        }
    }
    
    func syncIndexes(musicFolder: MusicFolder, persistentContainer: NSPersistentContainer) -> Promise<Void> {
        guard isSyncAllowed else { return Promise.value }
        return firstly {
            self.subsonicServerApi.requestIndexes(musicFolderId: musicFolder.id)
        }.then { data in
            persistentContainer.performAsync { companion in
                let musicFolderAsync = MusicFolder(managedObject: companion.context.object(with: musicFolder.managedObject.objectID) as! MusicFolderMO)
                let parserDelegate = SsDirectoryParserDelegate(musicFolder: musicFolderAsync, library: companion.library, syncWave: companion.syncWave, subsonicUrlCreator: self.subsonicServerApi)
                try self.parse(data: data, delegate: parserDelegate)
            }
        }
    }
    
    func sync(directory: Directory, persistentStorage: PersistentStorage) -> Promise<Void> {
        guard isSyncAllowed else { return Promise.value }
        return firstly {
            self.subsonicServerApi.requestMusicDirectory(id: directory.id)
        }.then { data in
            persistentStorage.persistentContainer.performAsync { companion in
                let directoryAsync = Directory(managedObject: companion.context.object(with: directory.managedObject.objectID) as! DirectoryMO)
                let parserDelegate = SsDirectoryParserDelegate(directory: directoryAsync, library: companion.library, syncWave: companion.syncWave, subsonicUrlCreator: self.subsonicServerApi)
                try self.parse(data: data, delegate: parserDelegate)
            }
        }
    }
    
    func requestRandomSongs(playlist: Playlist, count: Int, persistentStorage: PersistentStorage) -> Promise<Void> {
        guard isSyncAllowed else { return Promise.value }
        return firstly {
            self.subsonicServerApi.requestRandomSongs(count: count)
        }.then { data in
            persistentStorage.persistentContainer.performAsync { companion in
                let parserDelegate = SsSongParserDelegate(library: companion.library, syncWave: companion.syncWave, subsonicUrlCreator: self.subsonicServerApi)
                try self.parse(data: data, delegate: parserDelegate)
                playlist.getManagedObject(in: companion.context, library: companion.library).append(playables: parserDelegate.parsedSongs)
            }
        }
    }
    
    func requestPodcastEpisodeDelete(podcastEpisode: PodcastEpisode) -> Promise<Void> {
        guard isSyncAllowed else { return Promise.value }
        return firstly {
            self.subsonicServerApi.requestPodcastEpisodeDelete(id: podcastEpisode.id)
        }.then { data in
            self.parseForError(data: data)
        }
    }
    
    func syncDownPlaylistsWithoutSongs(persistentContainer: NSPersistentContainer) -> Promise<Void> {
        guard isSyncAllowed else { return Promise.value }
        return firstly {
            subsonicServerApi.requestPlaylists()
        }.then { data in
            persistentContainer.performAsync { companion in
                let parserDelegate = SsPlaylistParserDelegate(library: companion.library)
                try self.parse(data: data, delegate: parserDelegate)
            }
        }
    }
    
    func syncDown(playlist: Playlist, persistentContainer: NSPersistentContainer) -> Promise<Void> {
        guard isSyncAllowed, playlist.id != "" else { return Promise.value }
        os_log("Download playlist \"%s\" from server", log: log, type: .info, playlist.name)
        return firstly {
            subsonicServerApi.requestPlaylistSongs(id: playlist.id)
        }.then { data in
            persistentContainer.performAsync { companion in
                let playlistAsync = playlist.getManagedObject(in: companion.context, library: companion.library)
                let parserDelegate = SsPlaylistSongsParserDelegate(playlist: playlistAsync, library: companion.library, syncWave: companion.syncWave, subsonicUrlCreator: self.subsonicServerApi)
                try self.parse(data: data, delegate: parserDelegate)
                playlistAsync.ensureConsistentItemOrder()
            }
        }
    }
    
    private func validatePlaylistId(playlist: Playlist, persistentContainer: NSPersistentContainer) -> Promise<Void> {
        return firstly { () -> Promise<Void> in
            if playlist.id == "" {
                return createPlaylistRemote(playlist: playlist, persistentContainer: persistentContainer)
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
    
    func syncUpload(playlistToUpdateName playlist: Playlist, persistentContainer: NSPersistentContainer) -> Promise<Void> {
        guard isSyncAllowed else { return Promise.value }
        os_log("Upload name on playlist to: \"%s\"", log: log, type: .info, playlist.name)
        return firstly {
            self.validatePlaylistId(playlist: playlist, persistentContainer: persistentContainer)
        }.then {
            self.subsonicServerApi.requestPlaylistUpdate(id: playlist.id, name: playlist.name, songIndicesToRemove: [], songIdsToAdd: [])
        }.then { data in
            self.parseForError(data: data)
        }
    }
    
    func syncUpload(playlistToAddSongs playlist: Playlist, songs: [Song], persistentContainer: NSPersistentContainer) -> Promise<Void> {
        guard isSyncAllowed, !songs.isEmpty else { return Promise.value }
        os_log("Upload SongsAdded on playlist \"%s\"", log: log, type: .info, playlist.name)
        return firstly {
            self.validatePlaylistId(playlist: playlist, persistentContainer: persistentContainer)
        }.then {
            self.subsonicServerApi.requestPlaylistUpdate(id: playlist.id, name: playlist.name, songIndicesToRemove: [], songIdsToAdd: songs.compactMap{ $0.id })
        }.then { data in
            self.parseForError(data: data)
        }
    }
    
    func syncUpload(playlistToDeleteSong playlist: Playlist, index: Int, persistentContainer: NSPersistentContainer) -> Promise<Void> {
        guard isSyncAllowed else { return Promise.value }
        os_log("Upload SongDelete on playlist \"%s\" at index: %i", log: log, type: .info, playlist.name, index)
        return firstly {
            self.validatePlaylistId(playlist: playlist, persistentContainer: persistentContainer)
        }.then {
            self.subsonicServerApi.requestPlaylistUpdate(id: playlist.id, name: playlist.name, songIndicesToRemove: [index], songIdsToAdd: [])
        }.then { data in
            self.parseForError(data: data)
        }
    }
    
    func syncUpload(playlistToUpdateOrder playlist: Playlist, persistentContainer: NSPersistentContainer) -> Promise<Void> {
        guard isSyncAllowed else { return Promise.value }
        os_log("Upload OrderChange on playlist \"%s\"", log: log, type: .info, playlist.name)
        return firstly {
            self.validatePlaylistId(playlist: playlist, persistentContainer: persistentContainer)
        }.then { () -> Promise<Data> in
            let songIdsToAdd = playlist.playables.compactMap{ $0.id }
            let songIndicesToRemove = Array(0...songIdsToAdd.count-1)
            return self.subsonicServerApi.requestPlaylistUpdate(id: playlist.id, name: playlist.name, songIndicesToRemove: songIndicesToRemove, songIdsToAdd: songIdsToAdd)
        }.then { data in
            self.parseForError(data: data)
        }
    }
    
    func syncUpload(playlistIdToDelete id: String) -> Promise<Void> {
        guard isSyncAllowed else { return Promise.value }
        os_log("Upload Delete playlist \"%s\"", log: log, type: .info, id)
        return firstly {
            self.subsonicServerApi.requestPlaylistDelete(id: id)
        }.then { data in
            self.parseForError(data: data)
        }
    }
    
    func syncDownPodcastsWithoutEpisodes(persistentContainer: NSPersistentContainer) -> Promise<Void> {
        guard isSyncAllowed else { return Promise.value }
        return firstly {
            subsonicServerApi.requestServerPodcastSupport()
        }.then { isSupported -> Promise<Void> in
            guard isSupported else { return Promise.value }
            return firstly {
                self.subsonicServerApi.requestPodcasts()
            }.then { data in
                persistentContainer.performAsync { companion in
                    let oldPodcasts = Set(companion.library.getRemoteAvailablePodcasts())
                    
                    let parserDelegate = SsPodcastParserDelegate(library: companion.library, syncWave: companion.syncWave, subsonicUrlCreator: self.subsonicServerApi)
                    try self.parse(data: data, delegate: parserDelegate)
                    
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
            self.subsonicServerApi.requestRecordSongPlay(id: song.id, date: date)
        }.then { data in
            self.parseForError(data: data)
        }
    }
    
    func setRating(song: Song, rating: Int) -> Promise<Void> {
        guard isSyncAllowed, rating >= 0 && rating <= 5 else { return Promise.value }
        os_log("Rate %i stars: %s", log: log, type: .info, rating, song.displayString)
        return firstly {
            self.subsonicServerApi.requestRating(id: song.id, rating: rating)
        }.then { data in
            self.parseForError(data: data)
        }
    }
    
    func setRating(album: Album, rating: Int) -> Promise<Void> {
        guard isSyncAllowed, rating >= 0 && rating <= 5 else { return Promise.value }
        os_log("Rate %i stars: %s", log: log, type: .info, rating, album.name)
        return firstly {
            self.subsonicServerApi.requestRating(id: album.id, rating: rating)
        }.then { data in
            self.parseForError(data: data)
        }
    }
    
    func setRating(artist: Artist, rating: Int) -> Promise<Void> {
        guard isSyncAllowed, rating >= 0 && rating <= 5 else { return Promise.value }
        os_log("Rate %i stars: %s", log: log, type: .info, rating, artist.name)
        return firstly {
            self.subsonicServerApi.requestRating(id: artist.id, rating: rating)
        }.then { data in
            self.parseForError(data: data)
        }
    }
    
    func setFavorite(song: Song, isFavorite: Bool) -> Promise<Void> {
        guard isSyncAllowed else { return Promise.value }
        os_log("Set Favorite %s: %s", log: log, type: .info, isFavorite ? "TRUE" : "FALSE", song.displayString)
        return firstly {
            self.subsonicServerApi.requestSetFavorite(songId: song.id, isFavorite: isFavorite)
        }.then { data in
            self.parseForError(data: data)
        }
    }
    
    func setFavorite(album: Album, isFavorite: Bool) -> Promise<Void> {
        guard isSyncAllowed else { return Promise.value }
        os_log("Set Favorite %s: %s", log: log, type: .info, isFavorite ? "TRUE" : "FALSE", album.name)
        return firstly {
            self.subsonicServerApi.requestSetFavorite(albumId: album.id, isFavorite: isFavorite)
        }.then { data in
            self.parseForError(data: data)
        }
    }
    
    func setFavorite(artist: Artist, isFavorite: Bool) -> Promise<Void> {
        guard isSyncAllowed else { return Promise.value }
        os_log("Set Favorite %s: %s", log: log, type: .info, isFavorite ? "TRUE" : "FALSE", artist.name)
        return firstly {
            self.subsonicServerApi.requestSetFavorite(artistId: artist.id, isFavorite: isFavorite)
        }.then { data in
            self.parseForError(data: data)
        }
    }
    
    func searchArtists(searchText: String, persistentContainer: NSPersistentContainer) -> Promise<Void> {
        guard isSyncAllowed, searchText.count > 0 else { return Promise.value }
        os_log("Search artists via API: \"%s\"", log: log, type: .info, searchText)
        return firstly {
            subsonicServerApi.requestSearchArtists(searchText: searchText)
        }.then { data in
            persistentContainer.performAsync { companion in
                let parserDelegate = SsArtistParserDelegate(library: companion.library, syncWave: companion.syncWave, subsonicUrlCreator: self.subsonicServerApi)
                try self.parse(data: data, delegate: parserDelegate)
            }
        }
    }
    
    func searchAlbums(searchText: String, persistentContainer: NSPersistentContainer) -> Promise<Void> {
        guard isSyncAllowed, searchText.count > 0 else { return Promise.value }
        os_log("Search albums via API: \"%s\"", log: log, type: .info, searchText)
        return firstly {
            subsonicServerApi.requestSearchAlbums(searchText: searchText)
        }.then { data in
            persistentContainer.performAsync { companion in
                let parserDelegate = SsAlbumParserDelegate(library: companion.library, syncWave: companion.syncWave, subsonicUrlCreator: self.subsonicServerApi)
                try self.parse(data: data, delegate: parserDelegate)
            }
        }
    }
    
    func searchSongs(searchText: String, persistentContainer: NSPersistentContainer) -> Promise<Void> {
        guard isSyncAllowed, searchText.count > 0 else { return Promise.value }
        os_log("Search songs via API: \"%s\"", log: log, type: .info, searchText)
        return firstly {
            subsonicServerApi.requestSearchSongs(searchText: searchText)
        }.then { data in
            persistentContainer.performAsync { companion in
                let parserDelegate = SsSongParserDelegate(library: companion.library, syncWave: companion.syncWave, subsonicUrlCreator: self.subsonicServerApi)
                try self.parse(data: data, delegate: parserDelegate)
            }
        }
    }
    
    private func createPlaylistRemote(playlist: Playlist, persistentContainer: NSPersistentContainer) -> Promise<Void> {
        os_log("Create playlist on server", log: log, type: .info)
        return firstly {
            subsonicServerApi.requestPlaylistCreate(name: playlist.name)
        }.then { data in
            persistentContainer.performAsync { companion in
                let playlistAsync = playlist.getManagedObject(in: companion.context, library: companion.library)
                let parserDelegate = SsPlaylistSongsParserDelegate(playlist: playlistAsync, library: companion.library, syncWave: companion.syncWave, subsonicUrlCreator: self.subsonicServerApi)
                try self.parse(data: data, delegate: parserDelegate)
            }
        }.then { () -> Promise<Void> in
            // Old api version -> need to match the created playlist via name
            if playlist.id == "" {
                return self.updatePlaylistIdViaItsName(playlist: playlist, persistentContainer: persistentContainer)
            } else {
                return Promise.value
            }
        }
    }

    private func updatePlaylistIdViaItsName(playlist: Playlist, persistentContainer: NSPersistentContainer) -> Promise<Void> {
        return firstly {
            syncDownPlaylistsWithoutSongs(persistentContainer: persistentContainer)
        }.then {
            persistentContainer.performAsync { companion in
                let playlistAsync = playlist.getManagedObject(in: companion.context, library: companion.library)
                let playlists = companion.library.getPlaylists()
                let nameMatchingPlaylists = playlists.filter{ filterPlaylist in
                    return filterPlaylist.name == playlistAsync.name && filterPlaylist.id != ""
                }
                guard !nameMatchingPlaylists.isEmpty, let firstMatch = nameMatchingPlaylists.first else { return }
                let matchedId = firstMatch.id
                companion.library.deletePlaylist(firstMatch)
                playlistAsync.id = matchedId
            }
        }
    }
    
    private func parseForError(data: Data) -> Promise<Void> {
        Promise<Void> { seal in
            let parserDelegate = SsPingParserDelegate()
            try self.parse(data: data, delegate: parserDelegate)
            seal.fulfill(Void())
        }
    }
    
    private func parse(data: Data, delegate: SsXmlParser) throws {
        let parser = XMLParser(data: data)
        parser.delegate = delegate
        parser.parse()
        if let error = parser.parserError {
            os_log("Error during response parsing: %s", log: self.log, type: .error, error.localizedDescription)
            throw BackendError.parser
        }
        if let error = delegate.error, let _ = error.asSubsonicError {
            throw error
        }
    }
    
}
