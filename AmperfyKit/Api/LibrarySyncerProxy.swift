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

// MARK: - LibrarySyncerProxy

@MainActor
class LibrarySyncerProxy {
  let backendApi: BackendApi
  let account: Account
  let storage: PersistentStorage

  var activeSyncer: LibrarySyncer { backendApi.createLibrarySyncer(
    account: account,
    storage: storage
  ) }

  init(backendApi: BackendApi, account: Account, storage: PersistentStorage) {
    self.backendApi = backendApi
    self.account = account
    self.storage = storage
  }
}

// MARK: LibrarySyncer

extension LibrarySyncerProxy: LibrarySyncer {
  @MainActor
  func syncInitial(statusNotifyier: SyncCallbacks?) async throws {
    try await activeSyncer.syncInitial(statusNotifyier: statusNotifyier)
  }

  @MainActor
  func sync(genre: Genre) async throws {
    try await activeSyncer.sync(genre: genre)
  }

  @MainActor
  func sync(artist: Artist) async throws {
    try await activeSyncer.sync(artist: artist)
  }

  @MainActor
  func sync(album: Album) async throws {
    try await activeSyncer.sync(album: album)
  }

  @MainActor
  func sync(song: Song) async throws {
    try await activeSyncer.sync(song: song)
  }

  @MainActor
  func sync(podcast: Podcast) async throws {
    try await activeSyncer.sync(podcast: podcast)
  }

  @MainActor
  func syncNewestAlbums(offset: Int, count: Int) async throws {
    try await activeSyncer.syncNewestAlbums(offset: offset, count: count)
  }

  @MainActor
  func syncRecentAlbums(offset: Int, count: Int) async throws {
    try await activeSyncer.syncRecentAlbums(offset: offset, count: count)
  }

  @MainActor
  func syncNewestPodcastEpisodes() async throws {
    try await activeSyncer.syncNewestPodcastEpisodes()
  }

  @MainActor
  func syncFavoriteLibraryElements() async throws {
    try await activeSyncer.syncFavoriteLibraryElements()
  }

  @MainActor
  func syncRadios() async throws {
    try await activeSyncer.syncRadios()
  }

  @MainActor
  func syncDownPlaylistsWithoutSongs() async throws {
    try await activeSyncer.syncDownPlaylistsWithoutSongs()
  }

  @MainActor
  func syncDown(playlist: Playlist) async throws {
    try await activeSyncer.syncDown(playlist: playlist)
  }

  @MainActor
  func syncUpload(playlistToUpdateName playlist: Playlist) async throws {
    try await activeSyncer.syncUpload(playlistToUpdateName: playlist)
  }

  @MainActor
  func syncUpload(playlistToAddSongs playlist: Playlist, songs: [Song]) async throws {
    try await activeSyncer.syncUpload(playlistToAddSongs: playlist, songs: songs)
  }

  @MainActor
  func syncUpload(playlistToDeleteSong playlist: Playlist, index: Int) async throws {
    try await activeSyncer.syncUpload(playlistToDeleteSong: playlist, index: index)
  }

  @MainActor
  func syncUpload(playlistToUpdateOrder playlist: Playlist) async throws {
    try await activeSyncer.syncUpload(playlistToUpdateOrder: playlist)
  }

  @MainActor
  func syncUpload(playlistIdToDelete id: String) async throws {
    try await activeSyncer.syncUpload(playlistIdToDelete: id)
  }

  @MainActor
  func syncDownPodcastsWithoutEpisodes() async throws {
    try await activeSyncer.syncDownPodcastsWithoutEpisodes()
  }

  @MainActor
  func searchArtists(searchText: String) async throws {
    try await activeSyncer.searchArtists(searchText: searchText)
  }

  @MainActor
  func searchAlbums(searchText: String) async throws {
    try await activeSyncer.searchAlbums(searchText: searchText)
  }

  @MainActor
  func searchSongs(searchText: String) async throws {
    try await activeSyncer.searchSongs(searchText: searchText)
  }

  @MainActor
  func syncMusicFolders() async throws {
    try await activeSyncer.syncMusicFolders()
  }

  @MainActor
  func syncIndexes(musicFolder: MusicFolder) async throws {
    try await activeSyncer.syncIndexes(musicFolder: musicFolder)
  }

  @MainActor
  func sync(directory: Directory) async throws {
    try await activeSyncer.sync(directory: directory)
  }

  @MainActor
  func requestRandomSongs(playlist: Playlist, count: Int) async throws {
    try await activeSyncer.requestRandomSongs(playlist: playlist, count: count)
  }

  @MainActor
  func requestPodcastEpisodeDelete(podcastEpisode: PodcastEpisode) async throws {
    try await activeSyncer.requestPodcastEpisodeDelete(podcastEpisode: podcastEpisode)
  }

  @MainActor
  func syncNowPlaying(song: Song, songPosition: NowPlayingSongPosition) async throws {
    try await activeSyncer.syncNowPlaying(song: song, songPosition: songPosition)
  }

  @MainActor
  func scrobble(song: Song, date: Date?) async throws {
    try await activeSyncer.scrobble(song: song, date: date)
  }

  @MainActor
  func setRating(song: Song, rating: Int) async throws {
    try await activeSyncer.setRating(song: song, rating: rating)
  }

  @MainActor
  func setRating(album: Album, rating: Int) async throws {
    try await activeSyncer.setRating(album: album, rating: rating)
  }

  @MainActor
  func setRating(artist: Artist, rating: Int) async throws {
    try await activeSyncer.setRating(artist: artist, rating: rating)
  }

  @MainActor
  func setFavorite(song: Song, isFavorite: Bool) async throws {
    try await activeSyncer.setFavorite(song: song, isFavorite: isFavorite)
  }

  @MainActor
  func setFavorite(album: Album, isFavorite: Bool) async throws {
    try await activeSyncer.setFavorite(album: album, isFavorite: isFavorite)
  }

  @MainActor
  func setFavorite(artist: Artist, isFavorite: Bool) async throws {
    try await activeSyncer.setFavorite(artist: artist, isFavorite: isFavorite)
  }

  @MainActor
  func parseLyrics(relFilePath: URL) async throws -> LyricsList {
    try await activeSyncer.parseLyrics(relFilePath: relFilePath)
  }
}
