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

import Foundation
import CarPlay
import AmperfyKit
import CoreData

extension CarPlaySceneDelegate {
    func createPlaylistFetchController() {
        playlistFetchController = PlaylistFetchedResultsController(coreDataCompanion: appDelegate.storage.main, sortType: appDelegate.storage.settings.playlistsSortSetting, isGroupedInAlphabeticSections: false)
        playlistFetchController?.delegate = self
        if isOfflineMode {
            playlistFetchController?.search(searchText: "", playlistSearchCategory: .cached)
        } else {
            playlistFetchController?.fetch()
        }
    }
    func createPodcastFetchController() {
        podcastFetchController = PodcastFetchedResultsController(coreDataCompanion: appDelegate.storage.main, isGroupedInAlphabeticSections: false)
        podcastFetchController?.delegate = self
        if isOfflineMode {
            podcastFetchController?.search(searchText: "", onlyCached: isOfflineMode)
        } else {
            podcastFetchController?.fetch()
        }
    }
    func createArtistsFavoritesFetchController() {
        artistsFavoritesFetchController = ArtistFetchedResultsController(coreDataCompanion: appDelegate.storage.main, sortType: appDelegate.storage.settings.artistsSortSetting, isGroupedInAlphabeticSections: false)
        artistsFavoritesFetchController?.delegate = self
        artistsFavoritesFetchController?.search(searchText: "", onlyCached: isOfflineMode, displayFilter: .favorites)
    }
    func createAlbumsFavoritesFetchController() {
        albumsFavoritesFetchController = AlbumFetchedResultsController(coreDataCompanion: appDelegate.storage.main, sortType: appDelegate.storage.settings.albumsSortSetting, isGroupedInAlphabeticSections: false)
        albumsFavoritesFetchController?.delegate = self
        albumsFavoritesFetchController?.search(searchText: "", onlyCached: isOfflineMode, displayFilter: .favorites)
    }
    func createAlbumsNewestFetchController() {
        albumsNewestFetchController = AlbumFetchedResultsController(coreDataCompanion: appDelegate.storage.main, sortType: .newest, isGroupedInAlphabeticSections: false)
        albumsNewestFetchController?.delegate = self
        albumsNewestFetchController?.search(searchText: "", onlyCached: isOfflineMode, displayFilter: .newest)
    }
    func createAlbumsRecentFetchController() {
        albumsRecentFetchController = AlbumFetchedResultsController(coreDataCompanion: appDelegate.storage.main, sortType: .recent, isGroupedInAlphabeticSections: false)
        albumsRecentFetchController?.delegate = self
        albumsRecentFetchController?.search(searchText: "", onlyCached: isOfflineMode, displayFilter: .recent)
    }
    func createSongsFavoritesFetchController() {
        songsFavoritesFetchController = SongsFetchedResultsController(coreDataCompanion: appDelegate.storage.main, sortType: appDelegate.storage.settings.songsSortSetting, isGroupedInAlphabeticSections: false)
        songsFavoritesFetchController?.delegate = self
        songsFavoritesFetchController?.search(searchText: "", onlyCachedSongs: isOfflineMode, displayFilter: .favorites)
    }
    func createPlaylistDetailFetchController(playlist: Playlist) {
        playlistDetailFetchController = PlaylistItemsFetchedResultsController(forPlaylist: playlist, coreDataCompanion: appDelegate.storage.main, isGroupedInAlphabeticSections: false)
        playlistDetailFetchController?.delegate = self
        playlistDetailFetchController?.search(onlyCachedSongs: isOfflineMode)
    }
    func createPodcastDetailFetchController(podcast: Podcast) {
        podcastDetailFetchController = PodcastEpisodesFetchedResultsController(forPodcast: podcast, coreDataCompanion: appDelegate.storage.main, isGroupedInAlphabeticSections: false)
        podcastDetailFetchController?.delegate = self
        podcastDetailFetchController?.search(searchText: "", onlyCachedSongs: isOfflineMode)
    }
}
