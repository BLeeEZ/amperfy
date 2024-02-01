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
import PromiseKit
import AmperfyKit

class CarPlaySceneDelegate: UIResponder, CPTemplateApplicationSceneDelegate {
    
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
        os_log("CarPlay: didConnect", log: self.log, type: .info)
        appDelegate.notificationHandler.register(self, selector: #selector(refreshSort), name: .fetchControllerSortChanged, object: nil)
        appDelegate.notificationHandler.register(self, selector: #selector(refreshOfflineMode),name: .offlineModeChanged, object: nil)
        appDelegate.player.addNotifier(notifier: self)
        CPNowPlayingTemplate.shared.add(self)
        
        self.interfaceController = interfaceController
        self.interfaceController?.delegate = self
        self.configureNowPlayingTemplate()
        
        self.interfaceController?.setRootTemplate(rootBarTemplate, animated: true, completion: nil)
    }
    
    /// CarPlay disconnected
    func templateApplicationScene( _ templateApplicationScene: CPTemplateApplicationScene, didDisconnectInterfaceController interfaceController: CPInterfaceController) {
        os_log("CarPlay: didDisconnect", log: self.log, type: .info)
        self.interfaceController = nil
        appDelegate.notificationHandler.remove(self, name: .fetchControllerSortChanged, object: nil)
        appDelegate.notificationHandler.remove(self, name: .offlineModeChanged, object: nil)
        CPNowPlayingTemplate.shared.remove(self)
        
        playlistFetchController = nil
        podcastFetchController = nil
        artistsFavoritesFetchController = nil
        albumsFavoritesFetchController = nil
        albumsRecentlyAddedFetchController = nil
        songsFavoritesFetchController = nil
        songsRecentlyAddedFetchController = nil
        playlistDetailFetchController = nil
        podcastDetailFetchController = nil
    }

    lazy var playerQueueSection = {
        let queueTemplate = CPListTemplate(title: Self.queueButtonText, sections: [CPListSection]())
        return queueTemplate
    }()

    lazy var rootBarTemplate = {
        let bar = CPTabBarTemplate(templates: [
            libraryTab,
            playlistTab,
            podcastTab
        ])
        return bar
    }()
    lazy var playlistTab = {
        let playlistTab = CPListTemplate(title: "Playlists", sections: [CPListSection]())
        playlistTab.tabImage = UIImage.playlist
        return playlistTab
    }()
    lazy var podcastTab = {
        let podcastsTab = CPListTemplate(title: "Podcasts", sections: [CPListSection]())
        podcastsTab.tabImage = UIImage.podcast
        return podcastsTab
    }()
    lazy var libraryTab = {
        let libraryTab = CPListTemplate(title: "Library", sections: createLibrarySections())
        libraryTab.tabImage = UIImage.musicLibrary
        libraryTab.assistantCellConfiguration = CarPlaySceneDelegate.assistantConfig
        return libraryTab
    }()
    func createLibrarySections() -> [CPListSection] {
        let continuePlayingItems = createContinePlayingItems()
        var librarySections = [
            CPListSection(items: [
                createPlayRandomSongsItem(),
                createLibraryItem(text: "Favorites", icon: UIImage.heartFill, sectionToDisplay: songsFavoriteSection),
                createLibraryItem(text: "Recently Added", icon: UIImage.clock, sectionToDisplay: songsRecentlyAddedSection)
            ], header: "Songs", sectionIndexTitle: nil),
            CPListSection(items: [
                createLibraryItem(text: "Favorites", icon: UIImage.heartFill, sectionToDisplay: albumsFavoriteSection),
                createLibraryItem(text: "Recently Added", icon: UIImage.clock, sectionToDisplay: albumsRecentlyAddedSection)
            ], header: "Albums", sectionIndexTitle: nil),
            CPListSection(items: [
                createLibraryItem(text: "Favorites", icon: UIImage.heartFill, sectionToDisplay: artistsFavoriteSection)
            ], header: "Artists", sectionIndexTitle: nil)
        ]
        if continuePlayingItems.count > 0 {
            let continuePlayingSection = CPListSection(items: continuePlayingItems, header: "Continue Playing", sectionIndexTitle: nil)
            librarySections.insert(continuePlayingSection, at: 0)
        }
        return librarySections
    }
    lazy var artistsFavoriteSection = {
        let template = CPListTemplate(title: "Favorite Artists", sections: [
            CPListSection(items: [CPListTemplateItem]())
        ])
        return template
    }()
    lazy var albumsFavoriteSection = {
        let template = CPListTemplate(title: "Favorite Albums", sections: [
            CPListSection(items: [CPListTemplateItem]())
        ])
        return template
    }()
    lazy var albumsRecentlyAddedSection = {
        let template = CPListTemplate(title: "Recent Albums", sections: [
            CPListSection(items: [CPListTemplateItem]())
        ])
        return template
    }()
    lazy var songsFavoriteSection = {
        let template = CPListTemplate(title: "Favorite Songs", sections: [
            CPListSection(items: [CPListTemplateItem]())
        ])
        return template
    }()
    lazy var songsRecentlyAddedSection = {
        let template = CPListTemplate(title: "Recent Songs", sections: [
            CPListSection(items: [CPListTemplateItem]())
        ])
        return template
    }()
    var playlistDetailSection: CPListTemplate?
    var podcastDetailSection: CPListTemplate?
    
    
    func createLibraryItem(text: String, icon: UIImage, sectionToDisplay: CPListTemplate) -> CPListItem {
        let item =  CPListItem(text: text, detailText: nil, image: UIImage.createArtwork(with: icon, iconSizeType: .small, switchColors: true).carPlayImage(carTraitCollection: traits), accessoryImage: nil, accessoryType: .disclosureIndicator)
        item.handler = { [weak self] item, completion in
            guard let `self` = self else { completion(); return }
            self.interfaceController?.pushTemplate(sectionToDisplay, animated: true) { _,_ in
                completion()
            }
        }
        return item
    }
    
    func createContinePlayingItems() -> [CPListItem] {
        var continuePlayingItems = [CPListItem]()
        if appDelegate.player.musicItemCount > 0 {
            let item = CPListItem(text: "Music", detailText: "", image: UIImage.createArtwork(with: UIImage.musicalNotes, iconSizeType: .small, switchColors: true).carPlayImage(carTraitCollection: traits), accessoryImage: nil, accessoryType: .none)
            item.handler = { [weak self] item, completion in
                guard let `self` = self else { completion(); return }
                appDelegate.player.setPlayerMode(.music)
                appDelegate.player.play()
                self.displayNowPlaying { completion() }
            }
            continuePlayingItems.append(item)
        }
        if appDelegate.player.podcastItemCount > 0 {
            let item = CPListItem(text: "Podcasts", detailText: "", image: UIImage.createArtwork(with: UIImage.podcast, iconSizeType: .small, switchColors: true).carPlayImage(carTraitCollection: traits), accessoryImage: nil, accessoryType: .none)
            item.handler = { [weak self] item, completion in
                guard let `self` = self else { completion(); return }
                appDelegate.player.setPlayerMode(.podcast)
                appDelegate.player.play()
                self.displayNowPlaying { completion() }
            }
            continuePlayingItems.append(item)
        }
        return continuePlayingItems
    }
    
    func createPlayRandomSongsItem() -> CPListItem {
        let img = UIImage.createArtwork(with: UIImage.shuffle, iconSizeType: .small, switchColors: true).carPlayImage(carTraitCollection: traits)
        let item =  CPListItem(text: "Play Random Songs", detailText: nil, image: img, accessoryImage: nil, accessoryType: .disclosureIndicator)
        item.handler = { [weak self] item, completion in
            guard let `self` = self else { completion(); return }
            let songs = self.appDelegate.storage.main.library.getSongs().filterCached(dependigOn: isOfflineMode)
            let playContext = PlayContext(name: "Song Collection", playables: songs[randomPick: LibraryStorage.carPlayMaxElements])
            self.appDelegate.player.playShuffled(context: playContext)
            self.displayNowPlaying { completion() }
        }
        return item
    }
    
    
    var playlistFetchController: PlaylistFetchedResultsController?
    var podcastFetchController: PodcastFetchedResultsController?
    //
    var artistsFavoritesFetchController: ArtistFetchedResultsController?
    var albumsFavoritesFetchController: AlbumFetchedResultsController?
    var albumsRecentlyAddedFetchController: AlbumFetchedResultsController?
    var songsFavoritesFetchController: SongsFetchedResultsController?
    var songsRecentlyAddedFetchController: SongsFetchedResultsController?
    //
    var playlistDetailFetchController: PlaylistItemsFetchedResultsController?
    var podcastDetailFetchController: PodcastEpisodesFetchedResultsController?
    
    static let queueButtonText = NSLocalizedString("Queue", comment: "Button title on CarPlay player to display queue")
    

    private func createArtistItems(from fetchedController: BasicFetchedResultsController<ArtistMO>?) -> [CPListTemplateItem] {
        var items = [CPListTemplateItem]()
        guard let fetchedController = fetchedController else { return items }
        for index in 0...(CPListTemplate.maximumSectionCount-1) {
            guard let entity = fetchedController.getWrappedEntity(at: index) else { break }
            let detailTemplate = self.createDetailTemplate(for: entity)
            items.append(detailTemplate)
        }
        return items
    }
    private func createAlbumItems(from fetchedController: BasicFetchedResultsController<AlbumMO>?) -> [CPListTemplateItem] {
        var items = [CPListTemplateItem]()
        guard let fetchedController = fetchedController else { return items }
        for index in 0...(CPListTemplate.maximumSectionCount-1) {
            guard let entity = fetchedController.getWrappedEntity(at: index) else { break }
            let detailTemplate = self.createDetailTemplate(for: entity)
            items.append(detailTemplate)
        }
        return items
    }
    private func createSongItems(from fetchedController: BasicFetchedResultsController<SongMO>?) -> [CPListTemplateItem] {
        var items = [CPListTemplateItem]()
        var playables = [AbstractPlayable]()
        guard let fetchedController = fetchedController else { return items }
        for index in 0...(CPListTemplate.maximumSectionCount-2) {
            guard let entity = fetchedController.getWrappedEntity(at: index) else { break }
            playables.append(entity)

        }
        if playables.count > 0 {
            items.append(self.createPlayShuffledListItem(playContext: PlayContext(name: "Favorite Songs", playables: playables)))
        }
        for (index, playable) in playables.enumerated() {
            let detailTemplate = self.createDetailTemplate(for: playable, playContext: PlayContext(name: "Favorite Songs", index: index, playables: playables))
            items.append(detailTemplate)
        }
        return items
    }
    private func createPlaylistDetailItems(from fetchedController: PlaylistItemsFetchedResultsController) -> [CPListTemplateItem] {
        let playlist = fetchedController.playlist
        var items = [CPListItem]()
        
        guard let playables = fetchedController.getContextSongs(onlyCachedSongs: isOfflineMode)
        else { return items }
        
        items.append(self.createPlayShuffledListItem(playContext: PlayContext(containable: playlist, playables: playlist.playables.filterCached(dependigOn: self.isOfflineMode))))
        let displayedSongs = playables.prefix(CPListTemplate.maximumSectionCount-2)
        for (index, song) in displayedSongs.enumerated() {
            let listItem = self.createDetailTemplate(for: song, playContext: PlayContext(containable: playlist, index: index, playables: playables))
            items.append(listItem)
            if index >= CPListTemplate.maximumItemCount-1 {
                break
            }
        }
        return items
    }
    private func createPodcastDetailItems(from fetchedController: PodcastEpisodesFetchedResultsController) -> [CPListTemplateItem] {
        let podcast = fetchedController.podcast
        var items = [CPListItem]()
        
        var playables = [AbstractPlayable]()
        for index in 0...(CPListTemplate.maximumSectionCount-2) {
            guard let entity = fetchedController.getWrappedEntity(at: index) else { break }
            playables.append(entity)
        }
        for (index, song) in playables.enumerated() {
            let listItem = self.createDetailTemplate(for: song, playContext: PlayContext(containable: podcast, index: index, playables: playables))
            items.append(listItem)
        }
        return items
    }
    
    
    private func createDetailTemplate(for artist: Artist) -> CPListItem {
        let section = CPListItem(text: artist.name, detailText: artist.subtitle, image: artist.image(setting: artworkDisplayPreference).carPlayImage(carTraitCollection: traits), accessoryImage: nil, accessoryType: .disclosureIndicator)
        section.handler = { [weak self] item, completion in
            guard let `self` = self else { completion(); return }
            var albumItems = [CPListItem]()
            albumItems.append(self.createPlayShuffledListItem(playContext: PlayContext(containable: artist, playables: artist.playables.filterCached(dependigOn: self.isOfflineMode))))
            albumItems.append(self.createDetailAllSongsTemplate(for: artist))
            let artistAlbums = self.appDelegate.storage.main.library.getAlbums(whichContainsSongsWithArtist: artist, onlyCached: self.isOfflineMode).prefix(LibraryStorage.carPlayMaxElements)
            for album in artistAlbums {
                let listItem = self.createDetailTemplate(for: album)
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
    
    private func createDetailAllSongsTemplate(for artist: Artist) -> CPListItem {
        let section = CPListItem(text: "All Songs", detailText: nil, image: UIImage.createArtwork(with: UIImage.musicalNotes, iconSizeType: .small, switchColors: true).carPlayImage(carTraitCollection: traits), accessoryImage: nil, accessoryType: .disclosureIndicator)
        section.handler = { [weak self] item, completion in
            guard let `self` = self else { completion(); return }
            var songItems = [CPListItem]()
            songItems.append(self.createPlayShuffledListItem(playContext: PlayContext(containable: artist, playables: artist.playables.filterCached(dependigOn: self.isOfflineMode))))
            let artistSongs = artist.playables.filterCached(dependigOn: self.isOfflineMode).sortByTitle().prefix(LibraryStorage.carPlayMaxElements)
            for (index, song) in artistSongs.enumerated() {
                let listItem = self.createDetailTemplate(for: song, playContext: PlayContext(containable: artist, index: index, playables: Array(artistSongs)))
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
    
    private func createDetailTemplate(for album: Album) -> CPListItem {
        let section = CPListItem(text: album.name, detailText: album.subtitle, image: album.image(setting: artworkDisplayPreference).carPlayImage(carTraitCollection: traits), accessoryImage: nil, accessoryType: .disclosureIndicator)
        section.handler = { [weak self] item, completion in
            guard let `self` = self else { completion(); return }
            var songItems = [CPListItem]()
            songItems.append(self.createPlayShuffledListItem(playContext: PlayContext(containable: album, playables: album.playables.filterCached(dependigOn: self.isOfflineMode))))
            let albumSongs = album.playables.filterCached(dependigOn: self.isOfflineMode).prefix(LibraryStorage.carPlayMaxElements)
            for (index, song) in albumSongs.enumerated() {
                let listItem = self.createDetailTemplate(for: song, playContext: PlayContext(containable: album, index: index, playables: Array(albumSongs)), isTrackDisplayed: true)
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
    
    private func createPlaylistsSections() -> [CPListTemplateItem] {
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
                let playlistDetailTemplate = CPListTemplate(title: playlist.name, sections: [
                    CPListSection(items: [CPListTemplateItem]())
                ])
                self.playlistDetailSection = playlistDetailTemplate
                createPlaylistDetailFetchController(playlist: playlist)
                self.interfaceController?.pushTemplate(playlistDetailTemplate, animated: true, completion: nil)
                completion()
            }
            sections.append(section)
        }
        return sections
    }
    
    private func createPodcastsSections() -> [CPListTemplateItem] {
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
                let podcastDetailTemplate = CPListTemplate(title: podcast.name, sections: [
                    CPListSection(items: [CPListTemplateItem]())
                ])
                self.podcastDetailSection = podcastDetailTemplate
                createPodcastDetailFetchController(podcast: podcast)
                self.interfaceController?.pushTemplate(podcastDetailTemplate, animated: true, completion: nil)
                completion()
            }
            sections.append(section)
        }
        return sections
    }

    private func createPlayShuffledListItem(playContext: PlayContext, text: String = "Shuffle") -> CPListItem {
        let img = UIImage.createArtwork(with: UIImage.shuffle, iconSizeType: .small, switchColors: true).carPlayImage(carTraitCollection: traits)
        let listItem = CPListItem(text: text, detailText: nil, image: img)
        listItem.handler = { [weak self] item, completion in
            guard let `self` = self else { completion(); return }
            self.appDelegate.player.playShuffled(context: playContext)
            self.displayNowPlaying() {
                completion()
            }
        }
        return listItem
    }
    
    private func createDetailTemplate(for episode: PodcastEpisode) -> CPListItem {
        let accessoryType: CPListItemAccessoryType = episode.isCached ? .cloud : .none
        let listItem = CPListItem(text: episode.title, detailText: nil, image: nil, accessoryImage: nil, accessoryType: accessoryType)
        listItem.handler = { [weak self] item, completion in
            guard let `self` = self else { completion(); return }
            self.appDelegate.player.play(context: PlayContext(containable: episode))
            self.displayNowPlaying() {
                completion()
            }
        }
        return listItem
    }
    
    private func createDetailTemplate(for playable: AbstractPlayable, playContext: PlayContext, isTrackDisplayed: Bool = false) -> CPListItem {
        let accessoryType: CPListItemAccessoryType = playable.isCached ? .cloud : .none
        let image = isTrackDisplayed ? UIImage.numberToImage(number: playable.track) : playable.image(setting: artworkDisplayPreference)
        let listItem = CPListItem(text: playable.title, detailText: playable.subtitle, image: image.carPlayImage(carTraitCollection: traits), accessoryImage: nil, accessoryType: accessoryType)
        listItem.handler = { [weak self] item, completion in
            guard let `self` = self else { completion(); return }
            self.appDelegate.player.play(context: playContext)
            self.displayNowPlaying() {
                completion()
            }
        }
        return listItem
    }

    @objc private func refreshSort() {
        guard let templates = self.interfaceController?.templates else { return }
        if let root = self.interfaceController?.rootTemplate as? CPTabBarTemplate,
           root.selectedTemplate == playlistTab,
           playlistFetchController?.sortType != appDelegate.storage.settings.playlistsSortSetting {
            os_log("CarPlay: RefreshSort: PlaylistFetchController", log: self.log, type: .info)
            createPlaylistFetchController()
            playlistTab.updateSections([CPListSection(items: createPlaylistsSections())])
        }
        if artistsFavoritesFetchController?.sortType != appDelegate.storage.settings.artistsSortSetting {
            os_log("CarPlay: RefreshSort: ArtistsFavoritesFetchController", log: self.log, type: .info)
            createArtistsFavoritesFetchController()
            artistsFavoriteSection.updateSections([CPListSection(items: createArtistItems(from: artistsFavoritesFetchController))])
        }
        if templates.contains(albumsFavoriteSection), albumsFavoritesFetchController?.sortType != appDelegate.storage.settings.albumsSortSetting {
            os_log("CarPlay: RefreshSort: AlbumsFavoritesFetchController", log: self.log, type: .info)
            createAlbumsFavoritesFetchController()
            albumsFavoriteSection.updateSections([CPListSection(items: createAlbumItems(from: albumsFavoritesFetchController))])
        }
        if templates.contains(songsFavoriteSection), songsFavoritesFetchController?.sortType != appDelegate.storage.settings.songsSortSetting {
            os_log("CarPlay: RefreshSort: SongsFavoritesFetchController", log: self.log, type: .info)
            createSongsFavoritesFetchController()
            songsFavoriteSection.updateSections([CPListSection(items: createSongItems(from: songsFavoritesFetchController))])
        }
    }
    
    @objc private func refreshOfflineMode() {
        os_log("CarPlay: OfflineModeChanged", log: self.log, type: .info)
        guard let templates = self.interfaceController?.templates else { return }
        
        if let root = self.interfaceController?.rootTemplate as? CPTabBarTemplate,
           root.selectedTemplate == playlistTab  {
            os_log("CarPlay: OfflineModeChanged: playlistFetchController", log: self.log, type: .info)
            createPlaylistFetchController()
            playlistTab.updateSections([CPListSection(items: createPlaylistsSections())])
        }
        if let root = self.interfaceController?.rootTemplate as? CPTabBarTemplate,
           root.selectedTemplate == podcastTab {
            os_log("CarPlay: OfflineModeChanged: podcastFetchController", log: self.log, type: .info)
            createPodcastFetchController()
            podcastTab.updateSections([CPListSection(items: createPodcastsSections())])
        }
        if templates.contains(artistsFavoriteSection) {
            os_log("CarPlay: OfflineModeChanged: artistsFavoritesFetchController", log: self.log, type: .info)
            createArtistsFavoritesFetchController()
            artistsFavoriteSection.updateSections([CPListSection(items: createArtistItems(from: artistsFavoritesFetchController))])
        }
        if templates.contains(albumsFavoriteSection) {
            os_log("CarPlay: OfflineModeChanged: albumsFavoritesFetchController", log: self.log, type: .info)
            createAlbumsFavoritesFetchController()
            albumsFavoriteSection.updateSections([CPListSection(items: createAlbumItems(from: albumsFavoritesFetchController))])
        }
        if templates.contains(albumsRecentlyAddedSection) {
            os_log("CarPlay: OfflineModeChanged: albumsRecentlyAddedFetchController", log: self.log, type: .info)
            createAlbumsRecentlyAddedFetchController()
            albumsRecentlyAddedSection.updateSections([CPListSection(items: createAlbumItems(from: albumsRecentlyAddedFetchController))])
        }
        if templates.contains(songsFavoriteSection) {
            os_log("CarPlay: OfflineModeChanged: songsFavoritesFetchController", log: self.log, type: .info)
            createSongsFavoritesFetchController()
            songsFavoriteSection.updateSections([CPListSection(items: createSongItems(from: songsFavoritesFetchController))])
        }
        if templates.contains(songsRecentlyAddedSection) {
            os_log("CarPlay: OfflineModeChanged: songsRecentlyAddedFetchController", log: self.log, type: .info)
            createSongsRecentlyAddedFetchController()
            songsRecentlyAddedSection.updateSections([CPListSection(items: createSongItems(from: songsRecentlyAddedFetchController))])
        }
        if let playlistDetailSection = playlistDetailSection, templates.contains(playlistDetailSection), let playlistDetailFetchController = playlistDetailFetchController {
            os_log("CarPlay: OfflineModeChanged: playlistDetailSection", log: self.log, type: .info)
            playlistDetailFetchController.search(onlyCachedSongs: isOfflineMode)
            playlistDetailSection.updateSections([CPListSection(items: createPlaylistDetailItems(from: playlistDetailFetchController))])
        }
        if let podcastDetailSection = podcastDetailSection, templates.contains(podcastDetailSection), let podcastDetailFetchController = podcastDetailFetchController {
            os_log("CarPlay: OfflineModeChanged: podcastDetailSection", log: self.log, type: .info)
            podcastDetailFetchController.search(searchText: "", onlyCachedSongs: isOfflineMode)
            podcastDetailSection.updateSections([CPListSection(items: createPodcastDetailItems(from: podcastDetailFetchController))])
        }
    }
    
}

extension CarPlaySceneDelegate: NSFetchedResultsControllerDelegate {
    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        guard let templates = self.interfaceController?.templates else { return }
        if let root = self.interfaceController?.rootTemplate as? CPTabBarTemplate,
           root.selectedTemplate == playlistTab,
           let playlistFetchController = playlistFetchController, controller == playlistFetchController.fetchResultsController {
            os_log("CarPlay: FetchedResults: playlistFetchController", log: self.log, type: .info)
            playlistTab.updateSections([CPListSection(items: createPlaylistsSections())])
        }
        if let root = self.interfaceController?.rootTemplate as? CPTabBarTemplate,
           root.selectedTemplate == podcastTab,
           let podcastFetchController = podcastFetchController, controller == podcastFetchController.fetchResultsController {
            os_log("CarPlay: FetchedResults: podcastFetchController", log: self.log, type: .info)
            podcastTab.updateSections([CPListSection(items: createPodcastsSections())])
        }
        
        if templates.contains(artistsFavoriteSection), let artistsFavoritesFetchController = artistsFavoritesFetchController, controller == artistsFavoritesFetchController.fetchResultsController {
            os_log("CarPlay: FetchedResults: artistsFavoritesFetchController", log: self.log, type: .info)
            artistsFavoriteSection.updateSections([CPListSection(items: createArtistItems(from: artistsFavoritesFetchController))])
        }
        if templates.contains(albumsFavoriteSection), let albumsFavoritesFetchController = albumsFavoritesFetchController, controller == albumsFavoritesFetchController.fetchResultsController {
            os_log("CarPlay: FetchedResults: albumsFavoritesFetchController", log: self.log, type: .info)
            albumsFavoriteSection.updateSections([CPListSection(items: createAlbumItems(from: albumsFavoritesFetchController))])
        }
        if templates.contains(albumsRecentlyAddedSection), let albumsRecentlyAddedFetchController = albumsRecentlyAddedFetchController, controller == albumsRecentlyAddedFetchController.fetchResultsController {
            os_log("CarPlay: FetchedResults: albumsRecentlyAddedFetchController", log: self.log, type: .info)
            albumsRecentlyAddedSection.updateSections([CPListSection(items: createAlbumItems(from: albumsRecentlyAddedFetchController))])
        }
        if templates.contains(songsFavoriteSection), let songsFavoritesFetchController = songsFavoritesFetchController, controller == songsFavoritesFetchController.fetchResultsController {
            os_log("CarPlay: FetchedResults: songsFavoritesFetchController", log: self.log, type: .info)
            songsFavoriteSection.updateSections([CPListSection(items: createSongItems(from: songsFavoritesFetchController))])
        }
        if templates.contains(songsRecentlyAddedSection), let songsRecentlyAddedFetchController = songsRecentlyAddedFetchController, controller == songsRecentlyAddedFetchController.fetchResultsController {
            os_log("CarPlay: FetchedResults: songsRecentlyAddedFetchController", log: self.log, type: .info)
            songsRecentlyAddedSection.updateSections([CPListSection(items: createSongItems(from: songsRecentlyAddedFetchController))])
        }
        if let playlistDetailSection = playlistDetailSection, templates.contains(playlistDetailSection), let playlistDetailFetchController = playlistDetailFetchController, controller == playlistDetailFetchController.fetchResultsController {
            os_log("CarPlay: FetchedResults: playlistDetailSection", log: self.log, type: .info)
            playlistDetailSection.updateSections([CPListSection(items: createPlaylistDetailItems(from: playlistDetailFetchController))])
        }
        if let podcastDetailSection = podcastDetailSection, templates.contains(podcastDetailSection), let podcastDetailFetchController = podcastDetailFetchController, controller == podcastDetailFetchController.fetchResultsController {
            os_log("CarPlay: FetchedResults: podcastDetailSection", log: self.log, type: .info)
            podcastDetailSection.updateSections([CPListSection(items: createPodcastDetailItems(from: podcastDetailFetchController))])
        }
    }
}


extension CarPlaySceneDelegate: CPInterfaceControllerDelegate {
    func templateWillAppear(_ aTemplate: CPTemplate, animated: Bool) {
        if aTemplate == playerQueueSection {
            os_log("CarPlay: templateWillAppear playerQueueSection", log: self.log, type: .info)
            playerQueueSection.updateSections(createPlayerQueueSections())
        } else if aTemplate == libraryTab {
            os_log("CarPlay: templateWillAppear libraryTab", log: self.log, type: .info)
            libraryTab.updateSections(createLibrarySections())
        } else if aTemplate == playlistTab {
            os_log("CarPlay: templateWillAppear playlistTab", log: self.log, type: .info)
            if playlistFetchController == nil { createPlaylistFetchController() }
            playlistTab.updateSections([CPListSection(items: createPlaylistsSections())])
        } else if aTemplate == podcastTab {
            os_log("CarPlay: templateWillAppear podcastTab", log: self.log, type: .info)
            if podcastFetchController == nil { createPodcastFetchController() }
            podcastTab.updateSections([CPListSection(items: createPodcastsSections())])
        } else if aTemplate == artistsFavoriteSection {
            os_log("CarPlay: templateWillAppear artistsFavoriteSection", log: self.log, type: .info)
            if artistsFavoritesFetchController == nil { createArtistsFavoritesFetchController() }
            artistsFavoriteSection.updateSections([CPListSection(items: createArtistItems(from: artistsFavoritesFetchController))])
        } else if aTemplate == albumsFavoriteSection {
            os_log("CarPlay: templateWillAppear albumsFavoriteSection", log: self.log, type: .info)
            if albumsFavoritesFetchController == nil { createAlbumsFavoritesFetchController() }
            albumsFavoriteSection.updateSections([CPListSection(items: createAlbumItems(from: albumsFavoritesFetchController))])
        } else if aTemplate == albumsRecentlyAddedSection {
            os_log("CarPlay: templateWillAppear albumsRecentlyAddedSection", log: self.log, type: .info)
            if albumsRecentlyAddedFetchController == nil { createAlbumsRecentlyAddedFetchController() }
            albumsRecentlyAddedSection.updateSections([CPListSection(items: createAlbumItems(from: albumsRecentlyAddedFetchController))])
        } else if aTemplate == songsFavoriteSection {
            os_log("CarPlay: templateWillAppear songsFavoriteSection", log: self.log, type: .info)
            if songsFavoritesFetchController == nil { createSongsFavoritesFetchController() }
            songsFavoriteSection.updateSections([CPListSection(items: createSongItems(from: songsFavoritesFetchController))])
        } else if aTemplate == songsRecentlyAddedSection {
            os_log("CarPlay: templateWillAppear songsRecentlyAddedSection", log: self.log, type: .info)
            if songsRecentlyAddedFetchController == nil { createSongsRecentlyAddedFetchController() }
            songsRecentlyAddedSection.updateSections([CPListSection(items: createSongItems(from: songsRecentlyAddedFetchController))])
        } else if aTemplate == playlistDetailSection, let playlistDetailFetchController = playlistDetailFetchController {
            os_log("CarPlay: templateWillAppear playlistDetailSection", log: self.log, type: .info)
            firstly {
                playlistDetailFetchController.playlist.fetch(storage: self.appDelegate.storage, librarySyncer: self.appDelegate.librarySyncer, playableDownloadManager: self.appDelegate.playableDownloadManager)
            }.catch { error in
                self.appDelegate.eventLogger.report(topic: "Playlist Sync", error: error)
            }
            playlistDetailSection?.updateSections([CPListSection(items: createPlaylistDetailItems(from: playlistDetailFetchController))])
        } else if aTemplate == podcastDetailSection, let podcastDetailFetchController = podcastDetailFetchController {
            os_log("CarPlay: templateWillAppear podcastDetailSection", log: self.log, type: .info)
            firstly {
                podcastDetailFetchController.podcast.fetch(storage: self.appDelegate.storage, librarySyncer: self.appDelegate.librarySyncer, playableDownloadManager: self.appDelegate.playableDownloadManager)
            }.catch { error in
                self.appDelegate.eventLogger.report(topic: "Podcast Sync", error: error)
            }
            podcastDetailSection?.updateSections([CPListSection(items: createPodcastDetailItems(from: podcastDetailFetchController))])
        }
    }
    
    func templateDidAppear(_ aTemplate: CPTemplate, animated: Bool) {
    }
    
    func templateWillDisappear(_ aTemplate: CPTemplate, animated: Bool) {
    }
    
    func templateDidDisappear(_ aTemplate: CPTemplate, animated: Bool) {
        if aTemplate == playlistDetailSection {
            os_log("CarPlay: templateDidDisappear playlistDetailSection", log: self.log, type: .info)
            playlistDetailFetchController = nil
            playlistDetailSection = nil
        } else if aTemplate == podcastDetailSection {
            os_log("CarPlay: templateDidDisappear podcastDetailSection", log: self.log, type: .info)
            podcastDetailFetchController = nil
            podcastDetailSection = nil
        }
    }
}
