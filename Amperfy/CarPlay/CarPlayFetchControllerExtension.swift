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
    let sortType = appDelegate.storage.settings.user.playlistsSortSetting
    playlistFetchController = PlaylistFetchedResultsController(
      coreDataCompanion: appDelegate.storage.main, account: activeAccount,
      sortType: sortType,
      isGroupedInAlphabeticSections: sortType.asSectionIndexType == .alphabet
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
      coreDataCompanion: appDelegate.storage.main, account: activeAccount,
      isGroupedInAlphabeticSections: true
    )
    podcastFetchController?.delegate = self
    if isOfflineMode {
      podcastFetchController?.search(searchText: "", onlyCached: isOfflineMode)
    } else {
      podcastFetchController?.fetch()
    }
  }

  func createPodcastCachedFetchController() {
    podcastCachedFetchController = PodcastFetchedResultsController(
      coreDataCompanion: appDelegate.storage.main, account: activeAccount,
      isGroupedInAlphabeticSections: true
    )
    podcastCachedFetchController?.delegate = self
    podcastCachedFetchController?.search(searchText: "", onlyCached: true)
  }

  func createRadiosFetchController() {
    radiosFetchController = RadiosFetchedResultsController(
      coreDataCompanion: appDelegate.storage.main, account: activeAccount,
      isGroupedInAlphabeticSections: true
    )
    radiosFetchController?.delegate = self
    radiosFetchController?.fetch()
  }

  func createGenresFetchController() {
    genresFetchController = GenreFetchedResultsController(
      coreDataCompanion: appDelegate.storage.main, account: activeAccount,
      isGroupedInAlphabeticSections: true
    )
    genresFetchController?.delegate = self
    genresFetchController?.search(
      searchText: "",
      onlyCached: isOfflineMode
    )
  }

  func createGenresCachedFetchController() {
    genresCachedFetchController = GenreFetchedResultsController(
      coreDataCompanion: appDelegate.storage.main, account: activeAccount,
      isGroupedInAlphabeticSections: true
    )
    genresCachedFetchController?.delegate = self
    genresCachedFetchController?.search(
      searchText: "",
      onlyCached: true
    )
  }

  func createArtistsFetchController() {
    artistsFetchController = ArtistFetchedResultsController(
      coreDataCompanion: appDelegate.storage.main, account: activeAccount,
      sortType: .name,
      isGroupedInAlphabeticSections: true
    )
    artistsFetchController?.delegate = self
    artistsFetchController?.search(
      searchText: "",
      onlyCached: isOfflineMode,
      displayFilter: appDelegate.storage.settings.user.artistsFilterSetting
    )
  }

  func createArtistsCachedFetchController() {
    artistsCachedFetchController = ArtistFetchedResultsController(
      coreDataCompanion: appDelegate.storage.main, account: activeAccount,
      sortType: .name,
      isGroupedInAlphabeticSections: true
    )
    artistsCachedFetchController?.delegate = self
    artistsCachedFetchController?.search(
      searchText: "",
      onlyCached: true,
      displayFilter: appDelegate.storage.settings.user.artistsFilterSetting
    )
  }

  func createArtistsFavoritesFetchController() {
    artistsFavoritesFetchController = ArtistFetchedResultsController(
      coreDataCompanion: appDelegate.storage.main, account: activeAccount,
      sortType: .name,
      isGroupedInAlphabeticSections: true
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
      coreDataCompanion: appDelegate.storage.main, account: activeAccount,
      sortType: .name,
      isGroupedInAlphabeticSections: true
    )
    artistsFavoritesCachedFetchController?.delegate = self
    artistsFavoritesCachedFetchController?.search(
      searchText: "",
      onlyCached: true,
      displayFilter: .favorites
    )
  }

  func createAlbumsFetchController() {
    albumsFetchController = AlbumFetchedResultsController(
      coreDataCompanion: appDelegate.storage.main, account: activeAccount,
      sortType: .name,
      isGroupedInAlphabeticSections: true
    )
    albumsFetchController?.delegate = self
    albumsFetchController?.search(
      searchText: "",
      onlyCached: isOfflineMode,
      displayFilter: .all
    )
  }

  func createAlbumsCachedFetchController() {
    albumsCachedFetchController = AlbumFetchedResultsController(
      coreDataCompanion: appDelegate.storage.main, account: activeAccount,
      sortType: .name,
      isGroupedInAlphabeticSections: true
    )
    albumsCachedFetchController?.delegate = self
    albumsCachedFetchController?.search(
      searchText: "",
      onlyCached: true,
      displayFilter: .all
    )
  }

  func createAlbumsFavoritesFetchController() {
    let sortType = appDelegate.storage.settings.user.albumsSortSetting
    albumsFavoritesFetchController = AlbumFetchedResultsController(
      coreDataCompanion: appDelegate.storage.main, account: activeAccount,
      sortType: appDelegate.storage.settings.user.albumsSortSetting,
      isGroupedInAlphabeticSections: sortType.asSectionIndexType == .alphabet
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
      coreDataCompanion: appDelegate.storage.main, account: activeAccount,
      sortType: appDelegate.storage.settings.user.albumsSortSetting,
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
      coreDataCompanion: appDelegate.storage.main, account: activeAccount,
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
      coreDataCompanion: appDelegate.storage.main, account: activeAccount,
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
      coreDataCompanion: appDelegate.storage.main, account: activeAccount,
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
      coreDataCompanion: appDelegate.storage.main, account: activeAccount,
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
    var sortSetting = appDelegate.storage.settings.user.songsSortSetting
    if activeAccount.apiType.asServerApiType != .ampache {
      sortSetting = appDelegate.storage.settings.user.favoriteSongSortSetting
    }
    songsFavoritesFetchController = SongsFetchedResultsController(
      coreDataCompanion: appDelegate.storage.main, account: activeAccount,
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
    var sortSetting = appDelegate.storage.settings.user.songsSortSetting
    if activeAccount.apiType.asServerApiType != .ampache {
      sortSetting = appDelegate.storage.settings.user.favoriteSongSortSetting
    }
    songsFavoritesCachedFetchController = SongsFetchedResultsController(
      coreDataCompanion: appDelegate.storage.main, account: activeAccount,
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

  func createPodcastDetailFetchController(podcast: Podcast, onlyCached: Bool) {
    podcastDetailFetchController = PodcastEpisodesFetchedResultsController(
      forPodcast: podcast,
      coreDataCompanion: appDelegate.storage.main,
      isGroupedInAlphabeticSections: false
    )
    podcastDetailFetchController?.delegate = self
    podcastDetailFetchController?.search(searchText: "", onlyCachedSongs: onlyCached)
  }
}
