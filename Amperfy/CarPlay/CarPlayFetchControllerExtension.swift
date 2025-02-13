//
//  CarPlayFetchControllerExtension.swift
//  Amperfy
//
//  Created by Maximilian Bauer on 31.01.24.
//  Copyright (c) 2024 Maximilian Bauer. All rights reserved.
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

import AmperfyKit
import CarPlay
import CoreData
import Foundation

extension CarPlaySceneDelegate {
  func createPlaylistFetchController() {
    playlistFetchController = PlaylistFetchedResultsController(
      coreDataCompanion: appDelegate.storage.main,
      sortType: appDelegate.storage.settings.playlistsSortSetting,
      isGroupedInAlphabeticSections: false
    )
    playlistFetchController?.delegate = self
    if isOfflineMode {
      playlistFetchController?.search(searchText: "", playlistSearchCategory: .cached)
    } else {
      playlistFetchController?.fetch()
    }
  }

  func createPodcastFetchController() {
    podcastFetchController = PodcastFetchedResultsController(
      coreDataCompanion: appDelegate.storage.main,
      isGroupedInAlphabeticSections: false
    )
    podcastFetchController?.delegate = self
    if isOfflineMode {
      podcastFetchController?.search(searchText: "", onlyCached: isOfflineMode)
    } else {
      podcastFetchController?.fetch()
    }
  }

  func createRadiosFetchController() {
    radiosFetchController = RadiosFetchedResultsController(
      coreDataCompanion: appDelegate.storage.main,
      isGroupedInAlphabeticSections: false
    )
    radiosFetchController?.delegate = self
    radiosFetchController?.fetch()
  }

  func createArtistsFavoritesFetchController() {
    artistsFavoritesFetchController = ArtistFetchedResultsController(
      coreDataCompanion: appDelegate.storage.main,
      sortType: appDelegate.storage.settings.artistsSortSetting,
      isGroupedInAlphabeticSections: false
    )
    artistsFavoritesFetchController?.delegate = self
    artistsFavoritesFetchController?.search(
      searchText: "",
      onlyCached: isOfflineMode,
      displayFilter: .favorites
    )
  }

  func createArtistsFavoritesCachedFetchController() {
    artistsFavoritesCachedFetchController = ArtistFetchedResultsController(
      coreDataCompanion: appDelegate.storage.main,
      sortType: appDelegate.storage.settings.artistsSortSetting,
      isGroupedInAlphabeticSections: false
    )
    artistsFavoritesCachedFetchController?.delegate = self
    artistsFavoritesCachedFetchController?.search(
      searchText: "",
      onlyCached: true,
      displayFilter: .favorites
    )
  }

  func createAlbumsFavoritesFetchController() {
    albumsFavoritesFetchController = AlbumFetchedResultsController(
      coreDataCompanion: appDelegate.storage.main,
      sortType: appDelegate.storage.settings.albumsSortSetting,
      isGroupedInAlphabeticSections: false
    )
    albumsFavoritesFetchController?.delegate = self
    albumsFavoritesFetchController?.search(
      searchText: "",
      onlyCached: isOfflineMode,
      displayFilter: .favorites
    )
  }

  func createAlbumsFavoritesCachedFetchController() {
    albumsFavoritesCachedFetchController = AlbumFetchedResultsController(
      coreDataCompanion: appDelegate.storage.main,
      sortType: appDelegate.storage.settings.albumsSortSetting,
      isGroupedInAlphabeticSections: false
    )
    albumsFavoritesCachedFetchController?.delegate = self
    albumsFavoritesCachedFetchController?.search(
      searchText: "",
      onlyCached: true,
      displayFilter: .favorites
    )
  }

  func createAlbumsNewestFetchController() {
    albumsNewestFetchController = AlbumFetchedResultsController(
      coreDataCompanion: appDelegate.storage.main,
      sortType: .newest,
      isGroupedInAlphabeticSections: false
    )
    albumsNewestFetchController?.delegate = self
    albumsNewestFetchController?.search(
      searchText: "",
      onlyCached: isOfflineMode,
      displayFilter: .newest
    )
  }

  func createAlbumsNewestCachedFetchController() {
    albumsNewestCachedFetchController = AlbumFetchedResultsController(
      coreDataCompanion: appDelegate.storage.main,
      sortType: .newest,
      isGroupedInAlphabeticSections: false
    )
    albumsNewestCachedFetchController?.delegate = self
    albumsNewestCachedFetchController?.search(
      searchText: "",
      onlyCached: true,
      displayFilter: .newest
    )
  }

  func createAlbumsRecentFetchController() {
    albumsRecentFetchController = AlbumFetchedResultsController(
      coreDataCompanion: appDelegate.storage.main,
      sortType: .recent,
      isGroupedInAlphabeticSections: false
    )
    albumsRecentFetchController?.delegate = self
    albumsRecentFetchController?.search(
      searchText: "",
      onlyCached: isOfflineMode,
      displayFilter: .recent
    )
  }

  func createAlbumsRecentCachedFetchController() {
    albumsRecentCachedFetchController = AlbumFetchedResultsController(
      coreDataCompanion: appDelegate.storage.main,
      sortType: .recent,
      isGroupedInAlphabeticSections: false
    )
    albumsRecentCachedFetchController?.delegate = self
    albumsRecentCachedFetchController?.search(
      searchText: "",
      onlyCached: true,
      displayFilter: .recent
    )
  }

  func createSongsFavoritesFetchController() {
    var sortSetting = appDelegate.storage.settings.songsSortSetting
    if appDelegate.backendApi.selectedApi != .ampache {
      sortSetting = appDelegate.storage.settings.favoriteSongSortSetting
    }
    songsFavoritesFetchController = SongsFetchedResultsController(
      coreDataCompanion: appDelegate.storage.main,
      sortType: sortSetting,
      isGroupedInAlphabeticSections: false
    )
    songsFavoritesFetchController?.delegate = self
    songsFavoritesFetchController?.search(
      searchText: "",
      onlyCachedSongs: isOfflineMode,
      displayFilter: .favorites
    )
  }

  func createSongsFavoritesCachedFetchController() {
    var sortSetting = appDelegate.storage.settings.songsSortSetting
    if appDelegate.backendApi.selectedApi != .ampache {
      sortSetting = appDelegate.storage.settings.favoriteSongSortSetting
    }
    songsFavoritesCachedFetchController = SongsFetchedResultsController(
      coreDataCompanion: appDelegate.storage.main,
      sortType: sortSetting,
      isGroupedInAlphabeticSections: false
    )
    songsFavoritesCachedFetchController?.delegate = self
    songsFavoritesCachedFetchController?.search(
      searchText: "",
      onlyCachedSongs: true,
      displayFilter: .favorites
    )
  }

  func createPlaylistDetailFetchController(playlist: Playlist) {
    playlistDetailFetchController = PlaylistItemsFetchedResultsController(
      forPlaylist: playlist,
      coreDataCompanion: appDelegate.storage.main,
      isGroupedInAlphabeticSections: false
    )
    playlistDetailFetchController?.delegate = self
    playlistDetailFetchController?.search(onlyCachedSongs: isOfflineMode)
  }

  func createPodcastDetailFetchController(podcast: Podcast) {
    podcastDetailFetchController = PodcastEpisodesFetchedResultsController(
      forPodcast: podcast,
      coreDataCompanion: appDelegate.storage.main,
      isGroupedInAlphabeticSections: false
    )
    podcastDetailFetchController?.delegate = self
    podcastDetailFetchController?.search(searchText: "", onlyCachedSongs: isOfflineMode)
  }
}
