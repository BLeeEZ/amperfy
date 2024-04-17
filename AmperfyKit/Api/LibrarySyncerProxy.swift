//
//  LibrarySyncerProxy.swift
//  AmperfyKit
//
//  Created by Maximilian Bauer on 09.09.22.
//  Copyright (c) 2022 Maximilian Bauer. All rights reserved.
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
import PromiseKit

class LibrarySyncerProxy {
    
    let backendApi: BackendApi
    let storage: PersistentStorage
    
    var activeSyncer: LibrarySyncer {
        return self.backendApi.createLibrarySyncer(storage: storage)
    }
    
    init(backendApi: BackendApi, storage: PersistentStorage) {
        self.backendApi = backendApi
        self.storage = storage
    }
}

extension LibrarySyncerProxy: LibrarySyncer {
    func syncInitial(statusNotifyier: SyncCallbacks?) -> Promise<Void> {
        return activeSyncer.syncInitial(statusNotifyier: statusNotifyier)
    }
    
    func sync(genre: Genre) -> Promise<Void> {
        return activeSyncer.sync(genre: genre)
    }
    
    func sync(artist: Artist) -> Promise<Void> {
        return activeSyncer.sync(artist: artist)
    }
    
    func sync(album: Album) -> Promise<Void> {
        return activeSyncer.sync(album: album)
    }
    
    func sync(song: Song) -> Promise<Void> {
        return activeSyncer.sync(song: song)
    }
    
    func sync(podcast: Podcast) -> Promise<Void> {
        return activeSyncer.sync(podcast: podcast)
    }
    
    func syncNewestAlbums(offset: Int, count: Int) -> Promise<Void> {
        return activeSyncer.syncNewestAlbums(offset: offset, count: count)
    }
    
    func syncRecentAlbums(offset: Int, count: Int) -> Promise<Void> {
        return activeSyncer.syncRecentAlbums(offset: offset, count: count)
    }
    
    func syncNewestPodcastEpisodes() -> Promise<Void> {
        return activeSyncer.syncNewestPodcastEpisodes()
    }
    
    func syncFavoriteLibraryElements() -> Promise<Void> {
        return activeSyncer.syncFavoriteLibraryElements()
    }
    
    func syncDownPlaylistsWithoutSongs() -> Promise<Void> {
        return activeSyncer.syncDownPlaylistsWithoutSongs()
    }
    
    func syncDown(playlist: Playlist) -> Promise<Void> {
        return activeSyncer.syncDown(playlist: playlist)
    }
    
    func syncUpload(playlistToUpdateName playlist: Playlist) -> Promise<Void> {
        return activeSyncer.syncUpload(playlistToUpdateName: playlist)
    }
    
    func syncUpload(playlistToAddSongs playlist: Playlist, songs: [Song]) -> Promise<Void> {
        return activeSyncer.syncUpload(playlistToAddSongs: playlist, songs: songs)
    }
    
    func syncUpload(playlistToDeleteSong playlist: Playlist, index: Int) -> Promise<Void> {
        return activeSyncer.syncUpload(playlistToDeleteSong: playlist, index: index)
    }
    
    func syncUpload(playlistToUpdateOrder playlist: Playlist) -> Promise<Void> {
        return activeSyncer.syncUpload(playlistToUpdateOrder: playlist)
    }
    
    func syncUpload(playlistIdToDelete id: String) -> Promise<Void> {
        return activeSyncer.syncUpload(playlistIdToDelete: id)
    }
    
    func syncDownPodcastsWithoutEpisodes() -> Promise<Void> {
        return activeSyncer.syncDownPodcastsWithoutEpisodes()
    }
    
    func searchArtists(searchText: String) -> Promise<Void> {
        return activeSyncer.searchArtists(searchText: searchText)
    }
    
    func searchAlbums(searchText: String) -> Promise<Void> {
        return activeSyncer.searchAlbums(searchText: searchText)
    }
    
    func searchSongs(searchText: String) -> Promise<Void> {
        return activeSyncer.searchSongs(searchText: searchText)
    }
    
    func syncMusicFolders() -> Promise<Void> {
        return activeSyncer.syncMusicFolders()
    }
    
    func syncIndexes(musicFolder: MusicFolder) -> Promise<Void> {
        return activeSyncer.syncIndexes(musicFolder: musicFolder)
    }
    
    func sync(directory: Directory) -> Promise<Void> {
        return activeSyncer.sync(directory: directory)
    }
    
    func requestRandomSongs(playlist: Playlist, count: Int) -> Promise<Void> {
        return activeSyncer.requestRandomSongs(playlist: playlist, count: count)
    }
    
    func requestPodcastEpisodeDelete(podcastEpisode: PodcastEpisode) -> Promise<Void> {
        return activeSyncer.requestPodcastEpisodeDelete(podcastEpisode: podcastEpisode)
    }
    
    func syncNowPlaying(song: Song, songPosition: NowPlayingSongPosition) -> Promise<Void> {
        return activeSyncer.syncNowPlaying(song: song, songPosition: songPosition)
    }
    
    func scrobble(song: Song, date: Date?) -> Promise<Void> {
        return activeSyncer.scrobble(song: song, date: date)
    }
    
    func setRating(song: Song, rating: Int) -> Promise<Void> {
        return activeSyncer.setRating(song: song, rating: rating)
    }
    
    func setRating(album: Album, rating: Int) -> Promise<Void> {
        return activeSyncer.setRating(album: album, rating: rating)
    }
    
    func setRating(artist: Artist, rating: Int) -> Promise<Void> {
        return activeSyncer.setRating(artist: artist, rating: rating)
    }
    
    func setFavorite(song: Song, isFavorite: Bool) -> Promise<Void> {
        return activeSyncer.setFavorite(song: song, isFavorite: isFavorite)
    }
    
    func setFavorite(album: Album, isFavorite: Bool) -> Promise<Void> {
        return activeSyncer.setFavorite(album: album, isFavorite: isFavorite)
    }
    
    func setFavorite(artist: Artist, isFavorite: Bool) -> Promise<Void> {
        return activeSyncer.setFavorite(artist: artist, isFavorite: isFavorite)
    }
    
}
