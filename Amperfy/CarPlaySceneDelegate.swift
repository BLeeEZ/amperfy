//
//  CarPlaySceneDelegate.swift
//  Amperfy
//
//  Created by Maximilian Bauer on 17.08.22.
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
import UIKit
import CarPlay
import CoreData
import OSLog
import AmperfyKit

class CarPlaySceneDelegate: UIResponder, CPTemplateApplicationSceneDelegate, NSFetchedResultsControllerDelegate {
    
    static let maxTreeDepth = 4
    
    lazy var appDelegate = {
        return UIApplication.shared.delegate as! AppDelegate
    }()
    private let log = OSLog(subsystem: "Amperfy", category: "CarPlay")
    private static let assistantConfig = CPAssistantCellConfiguration(position: .top, visibility: .always, assistantAction: .playMedia)
    var isOfflineMode: Bool {
        return appDelegate.storage.settings.isOfflineMode
    }
    var artworkDisplayPreference: ArtworkDisplayPreference {
        return self.appDelegate.storage.settings.artworkDisplayPreference
    }
    
    var interfaceController: CPInterfaceController?
    var traits: UITraitCollection {
        return self.interfaceController?.carTraitCollection ?? UITraitCollection.maxDisplayScale
    }
    
    /// CarPlay connected
    func templateApplicationScene(_ templateApplicationScene: CPTemplateApplicationScene, didConnect interfaceController: CPInterfaceController) {
        os_log("didConnect CarPlay", log: self.log, type: .info)
        appDelegate.notificationHandler.register(self, selector: #selector(refreshSort), name: .fetchControllerSortChanged, object: nil)
              
        createPlaylistFetchController()
        createPodcastFetchController()
        //
        createArtistsFavoritesFetchController()
        createAlbumsFavoritesFetchController()
        createAlbumsRecentlyAddedFetchController()
        createSongsFavoritesFetchController()
        createSongsRecentlyAddedFetchController()
        
        self.interfaceController = interfaceController
        self.configureNowPlayingTemplate()
        self.displayInitTabTemplate()
    }
    
    /// CarPlay disconnected
    func templateApplicationScene(_ templateApplicationScene: CPTemplateApplicationScene, didDisconnect interfaceController: CPInterfaceController, from window: CPWindow) {
        os_log("didDisconnect CarPlay", log: self.log, type: .info)
        self.interfaceController = nil
    }
    
    @objc private func refreshSort() {
        if playlistFetchController?.sortType != appDelegate.storage.settings.playlistsSortSetting {
            os_log("RefreshSort: PlaylistFetchController", log: self.log, type: .info)
            createPlaylistFetchController()
            playlistTab.updateSections([CPListSection(items: createPlaylistsSections(treeDepth: 1))])
        }
        if artistsFavoritesFetchController?.sortType != appDelegate.storage.settings.artistsSortSetting {
            os_log("RefreshSort: ArtistsFavoritesFetchController", log: self.log, type: .info)
            createArtistsFavoritesFetchController()
        }
        if albumsFavoritesFetchController?.sortType != appDelegate.storage.settings.albumsSortSetting {
            os_log("RefreshSort: AlbumsFavoritesFetchController", log: self.log, type: .info)
            createAlbumsFavoritesFetchController()
        }
        if songsFavoritesFetchController?.sortType != appDelegate.storage.settings.songsSortSetting {
            os_log("RefreshSort: SongsFavoritesFetchController", log: self.log, type: .info)
            createSongsFavoritesFetchController()
        }
    }

    
    lazy var libraryTab = {
        return self.createLibraryTab()
    }()
    lazy var playlistTab = {
        return self.createPlaylistsTab()
    }()
    lazy var podcastTab = {
        return self.createPodcastsTab()
    }()
    
    var playlistFetchController: PlaylistFetchedResultsController?
    func createPlaylistFetchController() {
        playlistFetchController = PlaylistFetchedResultsController(coreDataCompanion: appDelegate.storage.main, sortType: appDelegate.storage.settings.playlistsSortSetting, isGroupedInAlphabeticSections: false)
        playlistFetchController?.delegate = self
        playlistFetchController?.fetch()
    }
    var podcastFetchController: PodcastFetchedResultsController?
    func createPodcastFetchController() {
        podcastFetchController = PodcastFetchedResultsController(coreDataCompanion: appDelegate.storage.main, isGroupedInAlphabeticSections: false)
        podcastFetchController?.delegate = self
        podcastFetchController?.fetch()
    }
    var artistsFavoritesFetchController: ArtistFetchedResultsController?
    func createArtistsFavoritesFetchController() {
        artistsFavoritesFetchController = ArtistFetchedResultsController(coreDataCompanion: appDelegate.storage.main, sortType: appDelegate.storage.settings.artistsSortSetting, isGroupedInAlphabeticSections: false)
        artistsFavoritesFetchController?.delegate = self
        artistsFavoritesFetchController?.search(searchText: "", onlyCached: isOfflineMode, displayFilter: .favorites)
    }
    var albumsFavoritesFetchController: AlbumFetchedResultsController?
    func createAlbumsFavoritesFetchController() {
        albumsFavoritesFetchController = AlbumFetchedResultsController(coreDataCompanion: appDelegate.storage.main, sortType: appDelegate.storage.settings.albumsSortSetting, isGroupedInAlphabeticSections: false)
        albumsFavoritesFetchController?.delegate = self
        albumsFavoritesFetchController?.search(searchText: "", onlyCached: isOfflineMode, displayFilter: .favorites)
    }
    var albumsRecentlyAddedFetchController: AlbumFetchedResultsController?
    func createAlbumsRecentlyAddedFetchController() {
        albumsRecentlyAddedFetchController = AlbumFetchedResultsController(coreDataCompanion: appDelegate.storage.main, sortType: .recentlyAddedIndex, isGroupedInAlphabeticSections: false)
        albumsRecentlyAddedFetchController?.delegate = self
        albumsRecentlyAddedFetchController?.search(searchText: "", onlyCached: isOfflineMode, displayFilter: .recentlyAdded)
    }
    var songsFavoritesFetchController: SongsFetchedResultsController?
    func createSongsFavoritesFetchController() {
        songsFavoritesFetchController = SongsFetchedResultsController(coreDataCompanion: appDelegate.storage.main, sortType: appDelegate.storage.settings.songsSortSetting, isGroupedInAlphabeticSections: false)
        songsFavoritesFetchController?.delegate = self
        songsFavoritesFetchController?.search(searchText: "", onlyCachedSongs: isOfflineMode, displayFilter: .favorites)
    }
    var songsRecentlyAddedFetchController: SongsFetchedResultsController?
    func createSongsRecentlyAddedFetchController() {
        songsRecentlyAddedFetchController = SongsFetchedResultsController(coreDataCompanion: appDelegate.storage.main, sortType: .recentlyAddedIndex, isGroupedInAlphabeticSections: false)
        songsRecentlyAddedFetchController?.delegate = self
        songsRecentlyAddedFetchController?.search(searchText: "", onlyCachedSongs: isOfflineMode, displayFilter: .recentlyAdded)
    }
    
    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        if let playlistFetchController = playlistFetchController, controller == playlistFetchController.fetchResultsController {
            playlistTab.updateSections([CPListSection(items: createPlaylistsSections(treeDepth: 1))])
        }
        if let podcastFetchController = podcastFetchController, controller == podcastFetchController.fetchResultsController {
            podcastTab.updateSections([CPListSection(items: createPodcastsSections(treeDepth: 1))])
        }
    }
    
    private func displayInitTabTemplate() {
        let tab = CPTabBarTemplate(templates: [
            libraryTab,
            playlistTab,
            podcastTab
        ])
        self.interfaceController?.setRootTemplate(tab, animated: true, completion: nil)
    }
    
    private func configureNowPlayingTemplate() {
        CPNowPlayingTemplate.shared.updateNowPlayingButtons([
            CPNowPlayingRepeatButton(handler: { [weak self] button in
                guard let `self` = self else { return }
                self.appDelegate.player.setRepeatMode(self.appDelegate.player.repeatMode.nextMode)
            }),
            CPNowPlayingShuffleButton(handler: { [weak self] button in
                guard let `self` = self else { return }
                self.appDelegate.player.toggleShuffle()
            })
        ])
    }
    
    private func createLibrarySections() -> [CPListTemplateItem] {
        let playlistSection = CPListItem(text: "Playlists", detailText: nil, image: nil, accessoryImage: nil, accessoryType: .disclosureIndicator)
        playlistSection.handler = { [weak self] item, completion in
            guard let `self` = self else { completion(); return }
            let sections = self.createPlaylistsSections(treeDepth: 1)
            let playlistTemplate = CPListTemplate(title: "Playlists", sections: [
                CPListSection(items: sections)
            ])
            self.interfaceController?.pushTemplate(playlistTemplate, animated: true, completion: nil)
            completion()
        }
        
        let artistsSection = CPListItem(text: "Artists", detailText: nil, image: nil, accessoryImage: nil, accessoryType: .disclosureIndicator)
        artistsSection.handler = { [weak self] item, completion in
            guard let `self` = self else { completion(); return }
            let sections = self.createArtistsSections(treeDepth: 1)
            let playlistTemplate = CPListTemplate(title: "Artists", sections: [
                CPListSection(items: sections)
            ])
            self.interfaceController?.pushTemplate(playlistTemplate, animated: true, completion: nil)
            completion()
        }
        
        let albumsSection = CPListItem(text: "Albums", detailText: nil, image: nil, accessoryImage: nil, accessoryType: .disclosureIndicator)
        albumsSection.handler = { [weak self] item, completion in
            guard let `self` = self else { completion(); return }
            let sections = self.createAlbumsSections(treeDepth: 1)
            let playlistTemplate = CPListTemplate(title: "Albums", sections: [
                CPListSection(items: sections)
            ])
            self.interfaceController?.pushTemplate(playlistTemplate, animated: true, completion: nil)
            completion()
        }
        
        let songsSection = CPListItem(text: "Songs", detailText: nil, image: nil, accessoryImage: nil, accessoryType: .disclosureIndicator)
        songsSection.handler = { [weak self] item, completion in
            guard let `self` = self else { completion(); return }
            let sections = self.createSongsSections(treeDepth: 1)
            let playlistTemplate = CPListTemplate(title: "Songs", sections: [
                CPListSection(items: sections)
            ])
            self.interfaceController?.pushTemplate(playlistTemplate, animated: true, completion: nil)
            completion()
        }
        
        let podcastSection = CPListItem(text: "Podcasts", detailText: nil, image: nil, accessoryImage: nil, accessoryType: .disclosureIndicator)
        podcastSection.handler = { [weak self] item, completion in
            guard let `self` = self else { completion(); return }
            let sections = self.createPodcastsSections(treeDepth: 1)
            let playlistTemplate = CPListTemplate(title: "Podcasts", sections: [
                CPListSection(items: sections)
            ])
            self.interfaceController?.pushTemplate(playlistTemplate, animated: true, completion: nil)
            completion()
        }
        
        let sections = [
            playlistSection,
            artistsSection,
            albumsSection,
            songsSection,
            podcastSection
        ]
        return sections
    }
    
    private func createLibraryTab() -> CPListTemplate {
        let libraryTab = CPListTemplate(title: "Library", sections: [CPListSection(items: createLibrarySections() )])
        libraryTab.tabImage = UIImage.musicLibrary
        libraryTab.assistantCellConfiguration = CarPlaySceneDelegate.assistantConfig
        return libraryTab
    }
    
    private func createPlaylistsTab() -> CPListTemplate {
        let sections = createPlaylistsSections(treeDepth: 1)
        let playlistTab = CPListTemplate(title: "Playlists", sections: [CPListSection(items: sections)])
        playlistTab.tabImage = UIImage.playlist
        return playlistTab
    }
    
    private func createPodcastsTab() -> CPListTemplate {
        let sections = createPodcastsSections(treeDepth: 1)
        let podcastsTab = CPListTemplate(title: "Podcasts", sections: [CPListSection(items: sections)])
        podcastsTab.tabImage = UIImage.podcast
        return podcastsTab
    }

    private func createArtistsSections(treeDepth: Int) -> [CPListTemplateItem] {
        let favoritesSection = CPListItem(text: "Favorites", detailText: nil, image: UIImage.createArtwork(with: UIImage.heartFill, iconSizeType: .small, switchColors: true).carPlayImage(carTraitCollection: traits), accessoryImage: nil, accessoryType: .disclosureIndicator)
        favoritesSection.handler = { [weak self] item, completion in
            guard let `self` = self else { completion(); return }
            var favoriteSections = [CPListTemplateItem]()
            
            if let fetchedArtistsFavorites = artistsFavoritesFetchController?.fetchedObjects {
                let sectionCount = min(fetchedArtistsFavorites.count, CPListTemplate.maximumSectionCount)
                if sectionCount > 0 {
                    for artistsFavoritesIndex in 0...(sectionCount-1) {
                        let artistsFavoriteMO = fetchedArtistsFavorites[artistsFavoritesIndex]
                        let artistsFavorite = Artist(managedObject: artistsFavoriteMO)
                        let section = self.createDetailTemplate(for: artistsFavorite, treeDepth: treeDepth+1)
                        favoriteSections.append(section)
                    }
                }
            }
            let favoriteTemplate = CPListTemplate(title: "Favorites", sections: [
                CPListSection(items: favoriteSections)
            ])
            self.interfaceController?.pushTemplate(favoriteTemplate, animated: true, completion: nil)
            completion()
        }
        return [favoritesSection]
    }
    
    private func createAlbumsSections(treeDepth: Int) -> [CPListTemplateItem] {
        let favoritesSection = CPListItem(text: "Favorites", detailText: nil, image: UIImage.createArtwork(with: UIImage.heartFill, iconSizeType: .small, switchColors: true).carPlayImage(carTraitCollection: traits), accessoryImage: nil, accessoryType: .disclosureIndicator)
        favoritesSection.handler = { [weak self] item, completion in
            guard let `self` = self else { completion(); return }
            var favoriteSections = [CPListTemplateItem]()
            
            if let fetchedAlbumsFavorites = albumsFavoritesFetchController?.fetchedObjects {
                let sectionCount = min(fetchedAlbumsFavorites.count, CPListTemplate.maximumSectionCount)
                if sectionCount > 0 {
                    for albumsFavoritesIndex in 0...(sectionCount-1) {
                        let albumFavoriteMO = fetchedAlbumsFavorites[albumsFavoritesIndex]
                        let albumFavorite = Album(managedObject: albumFavoriteMO)
                        let section = self.createDetailTemplate(for: albumFavorite, treeDepth: treeDepth+1)
                        favoriteSections.append(section)
                    }
                }
            }
            let favoriteTemplate = CPListTemplate(title: "Favorites", sections: [
                CPListSection(items: favoriteSections)
            ])
            self.interfaceController?.pushTemplate(favoriteTemplate, animated: true, completion: nil)
            completion()
        }
        
        let recentlyAddedSection = CPListItem(text: "Recently added", detailText: nil, image: UIImage.createArtwork(with: UIImage.clock, iconSizeType: .small, switchColors: true).carPlayImage(carTraitCollection: traits), accessoryImage: nil, accessoryType: .disclosureIndicator)
        recentlyAddedSection.handler = { [weak self] item, completion in
            guard let `self` = self else { completion(); return }
            var recentlyAddedSections = [CPListTemplateItem]()
            
            if let fetchedAlbumsRecentlyAdded = albumsRecentlyAddedFetchController?.fetchedObjects {
                let sectionCount = min(fetchedAlbumsRecentlyAdded.count, CPListTemplate.maximumSectionCount)
                if sectionCount > 0 {
                    for albumsRecentlyAddedIndex in 0...(sectionCount-1) {
                        let albumRecentlyAddedMO = fetchedAlbumsRecentlyAdded[albumsRecentlyAddedIndex]
                        let albumRecentlyAdded = Album(managedObject: albumRecentlyAddedMO)
                        let section = self.createDetailTemplate(for: albumRecentlyAdded, treeDepth: treeDepth+1)
                        recentlyAddedSections.append(section)
                    }
                }
            }
            
            let recentlyAddedTemplate = CPListTemplate(title: "Recently added", sections: [
                CPListSection(items: recentlyAddedSections)
            ])
            self.interfaceController?.pushTemplate(recentlyAddedTemplate, animated: true, completion: nil)
            completion()
        }
        return [favoritesSection, recentlyAddedSection]
    }
    
    private func createSongsSections(treeDepth: Int) -> [CPListTemplateItem] {
        let favoritesSection = CPListItem(text: "Favorites", detailText: nil, image: UIImage.createArtwork(with: UIImage.heartFill, iconSizeType: .small, switchColors: true).carPlayImage(carTraitCollection: traits), accessoryImage: nil, accessoryType: .disclosureIndicator)
        favoritesSection.handler = { [weak self] item, completion in
            guard let `self` = self else { completion(); return }
            var favoriteSections = [CPListTemplateItem]()
            
            if let fetchedSongsFavorites = songsFavoritesFetchController?.fetchedObjects {
                if fetchedSongsFavorites.count > 0 {
                    var favoritePlayables = [Song]()
                    for (index, songFavoriteMO) in fetchedSongsFavorites.enumerated() {
                        favoritePlayables.append(Song(managedObject: songFavoriteMO))
                        if index >= CPListTemplate.maximumItemCount-1 {
                            break
                        }
                    }
                    favoriteSections.append(self.createPlayShuffledListItem(playContext: PlayContext(name: "All favorite songs", playables: favoritePlayables), treeDepth: treeDepth+1))
                    for (index, songFavorite) in favoritePlayables.enumerated() {
                        let section = self.createDetailTemplate(for: songFavorite, playContext: PlayContext(name: "All favorite songs", index: index, playables: favoritePlayables), treeDepth: treeDepth+1)
                        favoriteSections.append(section)
                    }
                }
            }
            let favoriteTemplate = CPListTemplate(title: "Favorites", sections: [
                CPListSection(items: favoriteSections)
            ])
            self.interfaceController?.pushTemplate(favoriteTemplate, animated: true, completion: nil)
            completion()
        }
        
        let recentlyAddedSection = CPListItem(text: "Recently added", detailText: nil, image: UIImage.createArtwork(with: UIImage.clock, iconSizeType: .small, switchColors: true).carPlayImage(carTraitCollection: traits), accessoryImage: nil, accessoryType: .disclosureIndicator)
        recentlyAddedSection.handler = { [weak self] item, completion in
            guard let `self` = self else { completion(); return }
            var recentlyAddedSections = [CPListTemplateItem]()
            
            if let fetchedSongsRecentlyAdded = songsRecentlyAddedFetchController?.fetchedObjects {
                if fetchedSongsRecentlyAdded.count > 0 {
                    var recentlyAddedPlayables = [Song]()
                    for (index, songRecentlyAddedMO) in fetchedSongsRecentlyAdded.enumerated() {
                        recentlyAddedPlayables.append(Song(managedObject: songRecentlyAddedMO))
                        if index >= CPListTemplate.maximumItemCount-1 {
                            break
                        }
                    }
                    recentlyAddedSections.append(self.createPlayShuffledListItem(playContext: PlayContext(name: "All recent songs", playables: recentlyAddedPlayables), treeDepth: treeDepth+1))
                    for (index, songRecentlyAdded) in recentlyAddedPlayables.enumerated() {
                        let section = self.createDetailTemplate(for: songRecentlyAdded, playContext: PlayContext(name: "All recent songs", index: index, playables: recentlyAddedPlayables), treeDepth: treeDepth+1)
                        recentlyAddedSections.append(section)
                    }
                }
            }
            let recentlyAddedTemplate = CPListTemplate(title: "Recently added", sections: [
                CPListSection(items: recentlyAddedSections)
            ])
            self.interfaceController?.pushTemplate(recentlyAddedTemplate, animated: true, completion: nil)
            completion()
        }
        
        let songs = self.appDelegate.storage.main.library.getSongs().filterCached(dependigOn: isOfflineMode)
        let playRandomSongsSection = self.createPlayShuffledListItem(playContext: PlayContext(name: "Song Collection", playables: songs[randomPick: LibraryStorage.carPlayMaxElements]), treeDepth: treeDepth+1, text: "Play random songs")
        
        return [favoritesSection, recentlyAddedSection, playRandomSongsSection]
    }
    
    private func createDetailTemplate(for artist: Artist, treeDepth: Int) -> CPListItem {
        let section = CPListItem(text: artist.name, detailText: artist.subtitle, image: artist.image(setting: artworkDisplayPreference).carPlayImage(carTraitCollection: traits), accessoryImage: nil, accessoryType: .disclosureIndicator)
        section.handler = { [weak self] item, completion in
            guard let `self` = self else { completion(); return }
            var albumItems = [CPListItem]()
            albumItems.append(self.createPlayShuffledListItem(playContext: PlayContext(containable: artist, playables: artist.playables.filterCached(dependigOn: self.isOfflineMode)), treeDepth: treeDepth+1))
            albumItems.append(self.createDetailAllSongsTemplate(for: artist, treeDepth: treeDepth+1))
            let artistAlbums = self.appDelegate.storage.main.library.getAlbums(whichContainsSongsWithArtist: artist, onlyCached: self.isOfflineMode).prefix(LibraryStorage.carPlayMaxElements)
            for album in artistAlbums {
                let listItem = self.createDetailTemplate(for: album, treeDepth: treeDepth+1)
                albumItems.append(listItem)
            }
            let artistTemplate = CPListTemplate(title: artist.name, sections: [
                CPListSection(items: albumItems)
            ])
            self.interfaceController?.pushTemplate(artistTemplate, animated: true, completion: nil)
            completion()
        }
        return section
    }
    
    private func createDetailAllSongsTemplate(for artist: Artist, treeDepth: Int) -> CPListItem {
        let section = CPListItem(text: "All songs", detailText: nil, image: UIImage.createArtwork(with: UIImage.musicalNotes, iconSizeType: .small, switchColors: true).carPlayImage(carTraitCollection: traits), accessoryImage: nil, accessoryType: .disclosureIndicator)
        section.handler = { [weak self] item, completion in
            guard let `self` = self else { completion(); return }
            var songItems = [CPListItem]()
            songItems.append(self.createPlayShuffledListItem(playContext: PlayContext(containable: artist, playables: artist.playables.filterCached(dependigOn: self.isOfflineMode)), treeDepth: treeDepth+1))
            let artistSongs = artist.playables.filterCached(dependigOn: self.isOfflineMode).sortByTitle().prefix(LibraryStorage.carPlayMaxElements)
            for (index, song) in artistSongs.enumerated() {
                let listItem = self.createDetailTemplate(for: song, playContext: PlayContext(containable: artist, index: index, playables: Array(artistSongs)), treeDepth: treeDepth+1)
                songItems.append(listItem)
            }
            let albumTemplate = CPListTemplate(title: artist.name, sections: [
                CPListSection(items: songItems)
            ])
            self.interfaceController?.pushTemplate(albumTemplate, animated: true, completion: nil)
            completion()
        }
        return section
    }
    
    private func createDetailTemplate(for album: Album, treeDepth: Int) -> CPListItem {
        let section = CPListItem(text: album.name, detailText: album.subtitle, image: album.image(setting: artworkDisplayPreference).carPlayImage(carTraitCollection: traits), accessoryImage: nil, accessoryType: .disclosureIndicator)
        section.handler = { [weak self] item, completion in
            guard let `self` = self else { completion(); return }
            var songItems = [CPListItem]()
            songItems.append(self.createPlayShuffledListItem(playContext: PlayContext(containable: album, playables: album.playables.filterCached(dependigOn: self.isOfflineMode)), treeDepth: treeDepth+1))
            let albumSongs = album.playables.filterCached(dependigOn: self.isOfflineMode).prefix(LibraryStorage.carPlayMaxElements)
            for (index, song) in albumSongs.enumerated() {
                let listItem = self.createDetailTemplate(for: song, playContext: PlayContext(containable: album, index: index, playables: Array(albumSongs)), treeDepth: treeDepth+1, isTrackDisplayed: true)
                songItems.append(listItem)
            }
            let albumTemplate = CPListTemplate(title: album.name, sections: [
                CPListSection(items: songItems)
            ])
            self.interfaceController?.pushTemplate(albumTemplate, animated: true, completion: nil)
            completion()
        }
        return section
    }
    
    private func createPlaylistsSections(treeDepth: Int) -> [CPListTemplateItem] {
        var sections = [CPListTemplateItem]()

        guard let fetchedPlaylists = playlistFetchController?.fetchedObjects else { return sections }
        let sectionCount = min(fetchedPlaylists.count, CPListTemplate.maximumSectionCount)
        guard sectionCount > 0 else { return sections }
        for playlistIndex in 0...(sectionCount-1) {
            let playlistMO = fetchedPlaylists[playlistIndex]
            let playlist = Playlist(library: appDelegate.storage.main.library, managedObject: playlistMO)
            
            let section = CPListItem(text: playlist.name, detailText: playlist.subtitle, image: nil, accessoryImage: nil, accessoryType: .disclosureIndicator)
            section.handler = { [weak self] item, completion in
                guard let `self` = self else { completion(); return }
                var songItems = [CPListItem]()
                songItems.append(self.createPlayShuffledListItem(playContext: PlayContext(containable: playlist, playables: playlist.playables.filterCached(dependigOn: self.isOfflineMode)), treeDepth: treeDepth+1))
                let allSongs = playlist.playables.filterCached(dependigOn: self.isOfflineMode)
                for (index, song) in allSongs.enumerated() {
                    let listItem = self.createDetailTemplate(for: song, playContext: PlayContext(containable: playlist, index: index, playables: allSongs), treeDepth: treeDepth+1)
                    songItems.append(listItem)
                    if index >= CPListTemplate.maximumItemCount-1 {
                        break
                    }
                }
                let playlistTemplate = CPListTemplate(title: playlist.name, sections: [
                    CPListSection(items: songItems)
                ])
                self.interfaceController?.pushTemplate(playlistTemplate, animated: true, completion: nil)
                completion()
            }
            sections.append(section)
        }
        return sections
    }
    
    private func createPodcastsSections(treeDepth: Int) -> [CPListTemplateItem] {
        var sections = [CPListTemplateItem]()
        
        guard let fetchedPodcasts = podcastFetchController?.fetchedObjects else { return sections }
        let sectionCount = min(fetchedPodcasts.count, CPListTemplate.maximumSectionCount)
        guard sectionCount > 0 else { return sections }
        for podcastIndex in 0...(sectionCount-1) {
            let podcastMO = fetchedPodcasts[podcastIndex]
            let podcast = Podcast(managedObject: podcastMO)

            let section = CPListItem(text: podcast.title, detailText: podcast.subtitle, image: podcast.image(setting: artworkDisplayPreference).carPlayImage(carTraitCollection: traits), accessoryImage: nil, accessoryType: .disclosureIndicator)
            section.handler = { [weak self] item, completion in
                guard let `self` = self else { completion(); return }
                var episodeItems = [CPListItem]()
                let allEpisodes = podcast.episodes.filterCached(dependigOn: self.isOfflineMode)
                for episode in allEpisodes {
                    let listItem = self.createDetailTemplate(for: episode, treeDepth: treeDepth+1)
                    episodeItems.append(listItem)
                }
                let podcastTemplate = CPListTemplate(title: podcast.title, sections: [
                    CPListSection(items: episodeItems)
                ])
                self.interfaceController?.pushTemplate(podcastTemplate, animated: true, completion: nil)
                completion()
            }
            sections.append(section)
        }
        return sections
    }

    private func createPlayShuffledListItem(playContext: PlayContext, treeDepth: Int, text: String = "Shuffle") -> CPListItem {
        let img = UIImage.createArtwork(with: UIImage.shuffle, iconSizeType: .small, switchColors: true).carPlayImage(carTraitCollection: traits)
        let listItem = CPListItem(text: text, detailText: nil, image: img)
        listItem.handler = { [weak self] item, completion in
            guard let `self` = self else { completion(); return }
            self.appDelegate.player.playShuffled(context: playContext)
            if treeDepth < Self.maxTreeDepth {
                self.interfaceController?.pushTemplate(CPNowPlayingTemplate.shared, animated: true, completion: nil)
            }
            completion()
        }
        return listItem
    }
    
    private func createDetailTemplate(for episode: PodcastEpisode, treeDepth: Int) -> CPListItem {
        let accessoryType: CPListItemAccessoryType = episode.isCached ? .cloud : .none
        let listItem = CPListItem(text: episode.title, detailText: nil, image: nil, accessoryImage: nil, accessoryType: accessoryType)
        listItem.handler = { [weak self] item, completion in
            guard let `self` = self else { completion(); return }
            self.appDelegate.player.play(context: PlayContext(containable: episode))
            if treeDepth < Self.maxTreeDepth {
                self.interfaceController?.pushTemplate(CPNowPlayingTemplate.shared, animated: true, completion: nil)
            }
            completion()
        }
        return listItem
    }
    
    private func createDetailTemplate(for playable: AbstractPlayable, playContext: PlayContext, treeDepth: Int, isTrackDisplayed: Bool = false) -> CPListItem {
        let accessoryType: CPListItemAccessoryType = playable.isCached ? .cloud : .none
        let image = isTrackDisplayed ? UIImage.numberToImage(number: playable.track) : playable.image(setting: artworkDisplayPreference)
        let listItem = CPListItem(text: playable.title, detailText: playable.subtitle, image: image.carPlayImage(carTraitCollection: traits), accessoryImage: nil, accessoryType: accessoryType)
        listItem.handler = { [weak self] item, completion in
            guard let `self` = self else { completion(); return }
            self.appDelegate.player.play(context: playContext)
            if treeDepth < Self.maxTreeDepth {
                self.interfaceController?.pushTemplate(CPNowPlayingTemplate.shared, animated: true, completion: nil)
            }
            completion()
        }
        return listItem
    }
    
}
