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

import AmperfyKit
@preconcurrency import CarPlay
import CoreData
import Foundation
import OSLog
import UIKit

// MARK: - CarPlaySceneDelegate

@MainActor
class CarPlaySceneDelegate: UIResponder, CPTemplateApplicationSceneDelegate {
  static let maxTreeDepth = 4

  private let log = OSLog(subsystem: "Amperfy", category: "CarPlay")
  private static let assistantConfig = CPAssistantCellConfiguration(
    position: .top,
    visibility: .always,
    assistantAction: .playMedia
  )
  var isOfflineMode: Bool {
    appDelegate.storage.settings.isOfflineMode
  }

  var artworkDisplayPreference: ArtworkDisplayPreference {
    appDelegate.storage.settings.artworkDisplayPreference
  }

  var interfaceController: CPInterfaceController?
  var traits: UITraitCollection {
    interfaceController?.carTraitCollection ?? UITraitCollection.maxDisplayScale
  }

  /// CarPlay connected
  nonisolated func templateApplicationScene(
    _ templateApplicationScene: CPTemplateApplicationScene,
    didConnect interfaceController: CPInterfaceController
  ) {
    Task { @MainActor in
      os_log("CarPlay: didConnect", log: self.log, type: .info)
      appDelegate.notificationHandler.register(
        self,
        selector: #selector(refreshSort),
        name: .fetchControllerSortChanged,
        object: nil
      )
      appDelegate.notificationHandler.register(
        self,
        selector: #selector(refreshOfflineMode),
        name: .offlineModeChanged,
        object: nil
      )
      appDelegate.notificationHandler.register(
        self,
        selector: #selector(self.downloadFinishedSuccessful(notification:)),
        name: .downloadFinishedSuccess,
        object: appDelegate.artworkDownloadManager
      )
      appDelegate.notificationHandler.register(
        self,
        selector: #selector(self.downloadFinishedSuccessful(notification:)),
        name: .downloadFinishedSuccess,
        object: appDelegate.playableDownloadManager
      )
      appDelegate.player.addNotifier(notifier: self)
      CPNowPlayingTemplate.shared.add(self)

      self.interfaceController = interfaceController
      self.interfaceController?.delegate = self
      self.configureNowPlayingTemplate()

      self.interfaceController?.setRootTemplate(rootBarTemplate, animated: true, completion: nil)
    }
  }

  /// CarPlay disconnected
  nonisolated func templateApplicationScene(
    _ templateApplicationScene: CPTemplateApplicationScene,
    didDisconnectInterfaceController interfaceController: CPInterfaceController
  ) {
    Task { @MainActor in
      os_log("CarPlay: didDisconnect", log: self.log, type: .info)
      self.interfaceController = nil
      appDelegate.notificationHandler.remove(self, name: .fetchControllerSortChanged, object: nil)
      appDelegate.notificationHandler.remove(self, name: .offlineModeChanged, object: nil)
      appDelegate.notificationHandler.remove(
        self,
        name: .downloadFinishedSuccess,
        object: appDelegate.artworkDownloadManager
      )
      appDelegate.notificationHandler.remove(
        self,
        name: .downloadFinishedSuccess,
        object: appDelegate.playableDownloadManager
      )
      CPNowPlayingTemplate.shared.remove(self)

      playlistFetchController = nil
      podcastFetchController = nil
      artistsFavoritesFetchController = nil
      artistsFavoritesCachedFetchController = nil
      albumsFavoritesFetchController = nil
      albumsFavoritesCachedFetchController = nil
      albumsNewestFetchController = nil
      albumsNewestCachedFetchController = nil
      albumsRecentFetchController = nil
      albumsRecentCachedFetchController = nil
      songsFavoritesFetchController = nil
      songsFavoritesCachedFetchController = nil
      playlistDetailFetchController = nil
      podcastDetailFetchController = nil
    }
  }

  lazy var playerQueueSection = {
    let queueTemplate = CPListTemplate(title: Self.queueButtonText, sections: [CPListSection]())
    return queueTemplate
  }()

  lazy var rootBarTemplate = {
    let bar = CPTabBarTemplate(templates: [
      libraryTab,
      cachedTab,
      playlistTab,
      podcastTab,
    ].prefix(upToAsArray: CPTabBarTemplate.maximumTabCount))
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
      appDelegate.storage.settings.libraryDisplaySettings.isVisible(libraryType: .radios) ?
        CPListSection(items: [
          createLibraryItem(text: "Channels", icon: UIImage.radio, sectionToDisplay: radioSection),
        ], header: "Radio", sectionIndexTitle: nil)
        : nil,
      CPListSection(items: [
        createPlayRandomSongsItem(onlyCached: false),
        createLibraryItem(
          text: "Favorites",
          icon: UIImage.heartFill,
          sectionToDisplay: songsFavoriteSection
        ),
      ], header: "Songs", sectionIndexTitle: nil),
      CPListSection(items: [
        createPlayRandomAlbumsItem(onlyCached: false),
        createLibraryItem(
          text: "Favorites",
          icon: UIImage.heartFill,
          sectionToDisplay: albumsFavoriteSection
        ),
        createLibraryItem(
          text: "Newest",
          icon: UIImage.albumNewest,
          sectionToDisplay: albumsNewestSection
        ),
        createLibraryItem(
          text: "Recently Played",
          icon: UIImage.albumRecent,
          sectionToDisplay: albumsRecentSection
        ),
      ], header: "Albums", sectionIndexTitle: nil),
      CPListSection(items: [
        createLibraryItem(
          text: "Favorites",
          icon: UIImage.heartFill,
          sectionToDisplay: artistsFavoriteSection
        ),
      ], header: "Artists", sectionIndexTitle: nil),
    ].compactMap { $0 }
    if !continuePlayingItems.isEmpty {
      let continuePlayingSection = CPListSection(
        items: continuePlayingItems,
        header: "Continue Playing",
        sectionIndexTitle: nil
      )
      librarySections.insert(continuePlayingSection, at: 0)
    }
    return librarySections
  }

  lazy var cachedTab = {
    let libraryTab = CPListTemplate(title: "Cached", sections: createCachedSections())
    libraryTab.tabImage = UIImage.cache
    return libraryTab
  }()

  func createCachedSections() -> [CPListSection] {
    let librarySections = [
      CPListSection(items: [
        createPlayRandomSongsItem(onlyCached: true),
        createLibraryItem(
          text: "Favorites",
          icon: UIImage.heartFill,
          sectionToDisplay: songsFavoriteCachedSection
        ),
      ], header: "Cached Songs", sectionIndexTitle: nil),
      CPListSection(items: [
        createPlayRandomAlbumsItem(onlyCached: true),
        createLibraryItem(
          text: "Favorites",
          icon: UIImage.heartFill,
          sectionToDisplay: albumsFavoriteCachedSection
        ),
        createLibraryItem(
          text: "Newest",
          icon: UIImage.albumNewest,
          sectionToDisplay: albumsNewestCachedSection
        ),
        createLibraryItem(
          text: "Recently Played",
          icon: UIImage.albumRecent,
          sectionToDisplay: albumsRecentCachedSection
        ),
      ], header: "Cached Albums", sectionIndexTitle: nil),
      CPListSection(items: [
        createLibraryItem(
          text: "Favorites",
          icon: UIImage.heartFill,
          sectionToDisplay: artistsFavoriteCachedSection
        ),
      ], header: "Cached Artists", sectionIndexTitle: nil),
    ]
    return librarySections
  }

  lazy var artistsFavoriteSection = {
    let template = CPListTemplate(title: "Favorite Artists", sections: [
      CPListSection(items: [CPListTemplateItem]()),
    ])
    return template
  }()

  lazy var artistsFavoriteCachedSection = {
    let template = CPListTemplate(title: "Favorite Cached Artists", sections: [
      CPListSection(items: [CPListTemplateItem]()),
    ])
    return template
  }()

  lazy var albumsFavoriteSection = {
    let template = CPListTemplate(title: "Favorite Albums", sections: [
      CPListSection(items: [CPListTemplateItem]()),
    ])
    return template
  }()

  lazy var albumsFavoriteCachedSection = {
    let template = CPListTemplate(title: "Favorite Cached Albums", sections: [
      CPListSection(items: [CPListTemplateItem]()),
    ])
    return template
  }()

  lazy var albumsNewestSection = {
    let template = CPListTemplate(title: "Newest Albums", sections: [
      CPListSection(items: [CPListTemplateItem]()),
    ])
    return template
  }()

  lazy var albumsNewestCachedSection = {
    let template = CPListTemplate(title: "Newest Cached Albums", sections: [
      CPListSection(items: [CPListTemplateItem]()),
    ])
    return template
  }()

  lazy var albumsRecentSection = {
    let template = CPListTemplate(title: "Recently Played Albums", sections: [
      CPListSection(items: [CPListTemplateItem]()),
    ])
    return template
  }()

  lazy var albumsRecentCachedSection = {
    let template = CPListTemplate(title: "Recently Played Cached Albums", sections: [
      CPListSection(items: [CPListTemplateItem]()),
    ])
    return template
  }()

  lazy var songsFavoriteSection = {
    let template = CPListTemplate(title: "Favorite Songs", sections: [
      CPListSection(items: [CPListTemplateItem]()),
    ])
    return template
  }()

  lazy var songsFavoriteCachedSection = {
    let template = CPListTemplate(title: "Favorite Cached Songs", sections: [
      CPListSection(items: [CPListTemplateItem]()),
    ])
    return template
  }()

  lazy var radioSection = {
    let template = CPListTemplate(title: "Radios", sections: [
      CPListSection(items: [CPListTemplateItem]()),
    ])
    return template
  }()

  var playlistDetailSection: CPListTemplate?
  var podcastDetailSection: CPListTemplate?

  func createLibraryItem(
    text: String,
    icon: UIImage,
    sectionToDisplay: CPListTemplate
  )
    -> CPListItem {
    let item = CPListItem(
      text: text,
      detailText: nil,
      image: UIImage
        .createArtwork(
          with: icon,
          iconSizeType: .small,
          theme: appDelegate.storage.settings.themePreference,
          lightDarkMode: traits.userInterfaceStyle.asModeType,
          switchColors: true
        )
        .carPlayImage(carTraitCollection: traits),
      accessoryImage: nil,
      accessoryType: .disclosureIndicator
    )
    item.handler = { [weak self] item, completion in
      guard let self = self else { completion(); return }
      interfaceController?.pushTemplate(sectionToDisplay, animated: true) { _, _ in
        completion()
      }
    }
    return item
  }

  func createContinePlayingItems() -> [CPListItem] {
    var continuePlayingItems = [CPListItem]()
    if appDelegate.player.musicItemCount > 0 {
      let item = CPListItem(
        text: "Music",
        detailText: "",
        image: UIImage.createArtwork(
          with: UIImage.musicalNotes,
          iconSizeType: .small,
          theme: appDelegate.storage.settings.themePreference,
          lightDarkMode: traits.userInterfaceStyle.asModeType,
          switchColors: true
        ).carPlayImage(carTraitCollection: traits),
        accessoryImage: nil,
        accessoryType: .none
      )
      item.handler = { [weak self] item, completion in
        guard let self = self else { completion(); return }
        if appDelegate.player.playerMode != .music {
          appDelegate.player.setPlayerMode(.music)
        }
        appDelegate.player.play()
        displayNowPlaying { completion() }
      }
      continuePlayingItems.append(item)
    }
    if appDelegate.player.podcastItemCount > 0 {
      let item = CPListItem(
        text: "Podcasts",
        detailText: "",
        image: UIImage.createArtwork(
          with: UIImage.podcast,
          iconSizeType: .small,
          theme: appDelegate.storage.settings.themePreference,
          lightDarkMode: traits.userInterfaceStyle.asModeType,
          switchColors: true
        ).carPlayImage(carTraitCollection: traits),
        accessoryImage: nil,
        accessoryType: .none
      )
      item.handler = { [weak self] item, completion in
        guard let self = self else { completion(); return }
        if appDelegate.player.playerMode != .podcast {
          appDelegate.player.setPlayerMode(.podcast)
        }
        appDelegate.player.play()
        displayNowPlaying { completion() }
      }
      continuePlayingItems.append(item)
    }
    return continuePlayingItems
  }

  func createPlayRandomSongsItem(onlyCached: Bool) -> CPListItem {
    let img = UIImage.createArtwork(
      with: UIImage.shuffle,
      iconSizeType: .small,
      theme: appDelegate.storage.settings.themePreference,
      lightDarkMode: traits.userInterfaceStyle.asModeType,
      switchColors: true
    ).carPlayImage(carTraitCollection: traits)
    let item = CPListItem(
      text: "Play Random\(onlyCached ? " Cached" : "") Songs",
      detailText: nil,
      image: img,
      accessoryImage: nil,
      accessoryType: .disclosureIndicator
    )
    item.handler = { [weak self] item, completion in
      guard let self = self else { completion(); return }
      let songs = appDelegate.storage.main.library
        .getRandomSongs(onlyCached: onlyCached || isOfflineMode)
      let playContext = PlayContext(
        name: "Random\(onlyCached ? " Cached" : "") Songs",
        playables: songs
      )
      appDelegate.player.playShuffled(context: playContext)
      displayNowPlaying { completion() }
    }
    return item
  }

  func createPlayRandomAlbumsItem(onlyCached: Bool) -> CPListItem {
    let img = UIImage.createArtwork(
      with: UIImage.shuffle,
      iconSizeType: .small,
      theme: appDelegate.storage.settings.themePreference,
      lightDarkMode: traits.userInterfaceStyle.asModeType,
      switchColors: true
    ).carPlayImage(carTraitCollection: traits)
    let item = CPListItem(
      text: "Play Random\(onlyCached ? " Cached" : "") Albums",
      detailText: nil,
      image: img,
      accessoryImage: nil,
      accessoryType: .disclosureIndicator
    )
    item.handler = { [weak self] item, completion in
      guard let self = self else { completion(); return }
      let randomAlbums = appDelegate.storage.main.library.getRandomAlbums(
        count: 5,
        onlyCached: onlyCached || isOfflineMode
      )
      var songs = [AbstractPlayable]()
      randomAlbums
        .forEach {
          songs
            .append(
              contentsOf: $0.playables
                .filterCached(dependigOn: onlyCached || self.isOfflineMode)
            )
        }
      let playContext = PlayContext(
        name: "Random\(onlyCached ? " Cached" : "") Albums",
        playables: songs
      )
      appDelegate.player.play(context: playContext)
      displayNowPlaying { completion() }
    }
    return item
  }

  var playlistFetchController: PlaylistFetchedResultsController?
  var podcastFetchController: PodcastFetchedResultsController?
  var radiosFetchController: RadiosFetchedResultsController?
  //
  var artistsFavoritesFetchController: ArtistFetchedResultsController?
  var artistsFavoritesCachedFetchController: ArtistFetchedResultsController?
  var albumsFavoritesFetchController: AlbumFetchedResultsController?
  var albumsFavoritesCachedFetchController: AlbumFetchedResultsController?
  var albumsNewestFetchController: AlbumFetchedResultsController?
  var albumsNewestCachedFetchController: AlbumFetchedResultsController?
  var albumsRecentFetchController: AlbumFetchedResultsController?
  var albumsRecentCachedFetchController: AlbumFetchedResultsController?
  var songsFavoritesFetchController: SongsFetchedResultsController?
  var songsFavoritesCachedFetchController: SongsFetchedResultsController?
  //
  var playlistDetailFetchController: PlaylistItemsFetchedResultsController?
  var podcastDetailFetchController: PodcastEpisodesFetchedResultsController?

  static let queueButtonText = NSLocalizedString(
    "Queue",
    comment: "Button title on CarPlay player to display queue"
  )

  private func createArtistItems(
    from fetchedController: BasicFetchedResultsController<ArtistMO>?,
    onlyCached: Bool
  )
    -> [CPListTemplateItem] {
    var items = [CPListTemplateItem]()
    guard let fetchedController = fetchedController else { return items }
    for index in 0 ... (CPListTemplate.maximumSectionCount - 1) {
      guard let entity = fetchedController.getWrappedEntity(at: index) else { break }
      let detailTemplate = createDetailTemplate(for: entity, onlyCached: onlyCached)
      items.append(detailTemplate)
    }
    return items
  }

  private func createAlbumItems(
    from fetchedController: BasicFetchedResultsController<AlbumMO>?,
    onlyCached: Bool
  )
    -> [CPListTemplateItem] {
    var items = [CPListTemplateItem]()
    guard let fetchedController = fetchedController else { return items }
    for index in 0 ... (CPListTemplate.maximumSectionCount - 1) {
      guard let entity = fetchedController.getWrappedEntity(at: index) else { break }
      let detailTemplate = createDetailTemplate(for: entity, onlyCached: onlyCached)
      items.append(detailTemplate)
    }
    return items
  }

  private func createSongItems(from fetchedController: BasicFetchedResultsController<SongMO>?)
    -> [CPListTemplateItem] {
    var items = [CPListTemplateItem]()
    var playables = [AbstractPlayable]()
    guard let fetchedController = fetchedController else { return items }
    for index in 0 ... (CPListTemplate.maximumSectionCount - 2) {
      guard let entity = fetchedController.getWrappedEntity(at: index) else { break }
      playables.append(entity)
    }
    if !playables.isEmpty {
      items.append(createPlayShuffledListItem(playContext: PlayContext(
        name: "Favorite Songs",
        playables: playables
      )))
    }
    for (index, playable) in playables.enumerated() {
      let detailTemplate = createDetailTemplate(
        for: playable,
        playContext: PlayContext(name: "Favorite Songs", index: index, playables: playables)
      )
      items.append(detailTemplate)
    }
    return items
  }

  private func createPlaylistDetailItems(
    from fetchedController: PlaylistItemsFetchedResultsController
  )
    -> [CPListTemplateItem] {
    let playlist = fetchedController.playlist
    var items = [CPListItem]()

    guard let playables = fetchedController.getContextSongs(onlyCachedSongs: isOfflineMode)
    else { return items }

    items.append(createPlayShuffledListItem(playContext: PlayContext(
      containable: playlist,
      playables: playlist.playables.filterCached(dependigOn: isOfflineMode)
    )))
    let displayedSongs = playables.prefix(CPListTemplate.maximumSectionCount - 2)
    for (index, song) in displayedSongs.enumerated() {
      let listItem = createDetailTemplate(
        for: song,
        playContext: PlayContext(containable: playlist, index: index, playables: playables)
      )
      items.append(listItem)
      if index >= CPListTemplate.maximumItemCount - 1 {
        break
      }
    }
    return items
  }

  private func createPodcastDetailItems(
    from fetchedController: PodcastEpisodesFetchedResultsController
  )
    -> [CPListTemplateItem] {
    let podcast = fetchedController.podcast
    var items = [CPListItem]()

    var playables = [AbstractPlayable]()
    for index in 0 ... (CPListTemplate.maximumSectionCount - 2) {
      guard let entity = fetchedController.getWrappedEntity(at: index) else { break }
      playables.append(entity)
    }
    for (index, song) in playables.enumerated() {
      let listItem = createDetailTemplate(
        for: song,
        playContext: PlayContext(containable: podcast, index: index, playables: playables)
      )
      items.append(listItem)
    }
    return items
  }

  private func createDetailTemplate(for artist: Artist, onlyCached: Bool) -> CPListItem {
    let section = CPListItem(
      text: artist.name,
      detailText: artist.subtitle,
      image: LibraryEntityImage.getImageToDisplayImmediately(
        libraryEntity: artist,
        themePreference: appDelegate.storage.settings.themePreference,
        artworkDisplayPreference: artworkDisplayPreference,
        useCache: false
      ).carPlayImage(carTraitCollection: traits),
      accessoryImage: nil,
      accessoryType: .disclosureIndicator
    )
    if let artwork = artist.artwork {
      appDelegate.artworkDownloadManager.download(object: artwork)
    }
    section.userInfo = [
      CarPlayListUserInfoKeys.artworkDownloadID.rawValue: artist.artwork?.uniqueID as Any,
      CarPlayListUserInfoKeys.artworkOwnerObjectID.rawValue: artist.managedObject.objectID as Any,
      CarPlayListUserInfoKeys.artworkOwnerType.rawValue: ArtworkType.artist as Any,
    ]
    section.handler = { [weak self] item, completion in
      guard let self = self else { completion(); return }
      var albumItems = [CPListItem]()
      albumItems.append(createPlayShuffledListItem(playContext: PlayContext(
        containable: artist,
        playables: artist.playables.filterCached(dependigOn: onlyCached || isOfflineMode)
      )))
      albumItems.append(createDetailAllSongsTemplate(for: artist, onlyCached: onlyCached))
      let artistAlbums = appDelegate.storage.main.library.getAlbums(
        whichContainsSongsWithArtist: artist,
        onlyCached: onlyCached || isOfflineMode
      ).prefix(LibraryStorage.carPlayMaxElements)
      for album in artistAlbums {
        let listItem = createDetailTemplate(for: album, onlyCached: onlyCached)
        albumItems.append(listItem)
      }
      let artistTemplate = CPListTemplate(title: artist.name, sections: [
        CPListSection(items: albumItems),
      ])
      interfaceController?.pushTemplate(artistTemplate, animated: true, completion: nil)
      completion()
    }
    return section
  }

  private func createDetailAllSongsTemplate(for artist: Artist, onlyCached: Bool) -> CPListItem {
    let section = CPListItem(
      text: "All Songs",
      detailText: nil,
      image: UIImage.createArtwork(
        with: UIImage.musicalNotes,
        iconSizeType: .small,
        theme: appDelegate.storage.settings.themePreference,
        lightDarkMode: traits.userInterfaceStyle.asModeType,
        switchColors: true
      ).carPlayImage(carTraitCollection: traits),
      accessoryImage: nil,
      accessoryType: .disclosureIndicator
    )
    section.handler = { [weak self] item, completion in
      guard let self = self else { completion(); return }
      var songItems = [CPListItem]()
      songItems.append(createPlayShuffledListItem(playContext: PlayContext(
        containable: artist,
        playables: artist.playables.filterCached(dependigOn: onlyCached || isOfflineMode)
      )))
      let artistSongs = artist.playables.filterCached(dependigOn: onlyCached || isOfflineMode)
        .sortByTitle().prefix(LibraryStorage.carPlayMaxElements)
      for (index, song) in artistSongs.enumerated() {
        let listItem = createDetailTemplate(
          for: song,
          playContext: PlayContext(containable: artist, index: index, playables: Array(artistSongs))
        )
        songItems.append(listItem)
      }
      let albumTemplate = CPListTemplate(title: artist.name, sections: [
        CPListSection(items: songItems),
      ])
      interfaceController?.pushTemplate(albumTemplate, animated: true, completion: nil)
      completion()
    }
    return section
  }

  private func createDetailTemplate(for album: Album, onlyCached: Bool) -> CPListItem {
    let section = CPListItem(
      text: album.name,
      detailText: album.subtitle,
      image: LibraryEntityImage.getImageToDisplayImmediately(
        libraryEntity: album,
        themePreference: appDelegate.storage.settings.themePreference,
        artworkDisplayPreference: artworkDisplayPreference,
        useCache: false
      ).carPlayImage(carTraitCollection: traits),
      accessoryImage: nil,
      accessoryType: .disclosureIndicator
    )
    if let artwork = album.artwork {
      appDelegate.artworkDownloadManager.download(object: artwork)
    }
    section.userInfo = [
      CarPlayListUserInfoKeys.artworkDownloadID.rawValue: album.artwork?.uniqueID as Any,
      CarPlayListUserInfoKeys.artworkOwnerObjectID.rawValue: album.managedObject.objectID as Any,
      CarPlayListUserInfoKeys.artworkOwnerType.rawValue: ArtworkType.album as Any,
    ]
    section.handler = { [weak self] item, completion in
      guard let self = self else { completion(); return }
      var songItems = [CPListItem]()
      songItems.append(createPlayShuffledListItem(playContext: PlayContext(
        containable: album,
        playables: album.playables.filterCached(dependigOn: onlyCached || isOfflineMode)
      )))
      let albumSongs = album.playables.filterCached(dependigOn: onlyCached || isOfflineMode)
        .prefix(LibraryStorage.carPlayMaxElements)
      for (index, song) in albumSongs.enumerated() {
        let listItem = createDetailTemplate(
          for: song,
          playContext: PlayContext(containable: album, index: index, playables: Array(albumSongs)),
          isTrackDisplayed: true
        )
        songItems.append(listItem)
      }
      let albumTemplate = CPListTemplate(title: album.name, sections: [
        CPListSection(items: songItems),
      ])
      interfaceController?.pushTemplate(albumTemplate, animated: true, completion: nil)
      completion()
    }
    return section
  }

  private func createPlaylistsSections() -> [CPListTemplateItem] {
    var sections = [CPListTemplateItem]()

    guard let fetchedPlaylists = playlistFetchController?.fetchedObjects else { return sections }
    let sectionCount = min(fetchedPlaylists.count, CPListTemplate.maximumSectionCount)
    guard sectionCount > 0 else { return sections }
    for playlistIndex in 0 ... (sectionCount - 1) {
      let playlistMO = fetchedPlaylists[playlistIndex]
      let playlist = Playlist(library: appDelegate.storage.main.library, managedObject: playlistMO)

      let section = CPListItem(
        text: playlist.name,
        detailText: playlist.subtitle,
        image: nil,
        accessoryImage: nil,
        accessoryType: .disclosureIndicator
      )
      section.handler = { [weak self] item, completion in
        guard let self = self else { completion(); return }
        let playlistDetailTemplate = CPListTemplate(title: playlist.name, sections: [
          CPListSection(items: [CPListTemplateItem]()),
        ])
        playlistDetailSection = playlistDetailTemplate
        createPlaylistDetailFetchController(playlist: playlist)
        interfaceController?.pushTemplate(playlistDetailTemplate, animated: true, completion: nil)
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
    for podcastIndex in 0 ... (sectionCount - 1) {
      let podcastMO = fetchedPodcasts[podcastIndex]
      let podcast = Podcast(managedObject: podcastMO)

      let section = CPListItem(
        text: podcast.title,
        detailText: podcast.subtitle,
        image: LibraryEntityImage.getImageToDisplayImmediately(
          libraryEntity: podcast,
          themePreference: appDelegate.storage.settings.themePreference,
          artworkDisplayPreference: artworkDisplayPreference,
          useCache: false
        ).carPlayImage(carTraitCollection: traits),
        accessoryImage: nil,
        accessoryType: .disclosureIndicator
      )
      if let artwork = podcast.artwork {
        appDelegate.artworkDownloadManager.download(object: artwork)
      }
      section.userInfo = [
        CarPlayListUserInfoKeys.artworkDownloadID.rawValue: podcast.artwork?.uniqueID as Any,
        CarPlayListUserInfoKeys.artworkOwnerObjectID.rawValue: podcast.managedObject
          .objectID as Any,
        CarPlayListUserInfoKeys.artworkOwnerType.rawValue: ArtworkType.podcast as Any,
      ]
      section.handler = { [weak self] item, completion in
        guard let self = self else { completion(); return }
        let podcastDetailTemplate = CPListTemplate(title: podcast.name, sections: [
          CPListSection(items: [CPListTemplateItem]()),
        ])
        podcastDetailSection = podcastDetailTemplate
        createPodcastDetailFetchController(podcast: podcast)
        interfaceController?.pushTemplate(podcastDetailTemplate, animated: true, completion: nil)
        completion()
      }
      sections.append(section)
    }
    return sections
  }

  private func createRadioItems(from fetchedController: BasicFetchedResultsController<RadioMO>?)
    -> [CPListTemplateItem] {
    var items = [CPListTemplateItem]()
    guard let fetchedController = fetchedController else { return items }
    guard let fetchedRadios = fetchedController.fetchedObjects else { return items }
    let itemCount = min(fetchedRadios.count, CPListTemplate.maximumSectionCount - 2)
    guard itemCount > 0 else { return items }
    let radios = fetchedRadios.prefix(itemCount).compactMap { Radio(managedObject: $0) }

    items.append(createPlayRandomListItem(playContext: PlayContext(
      name: "Radios",
      playables: radios
    )))
    for (index, radio) in radios.enumerated() {
      let listItem = createDetailTemplate(
        for: radio,
        playContext: PlayContext(name: "Radios", index: index, playables: Array(radios)),
        isTrackDisplayed: false
      )
      items.append(listItem)
    }
    return items
  }

  private func createPlayRandomListItem(
    playContext: PlayContext,
    text: String = "Random"
  )
    -> CPListItem {
    let img = UIImage.createArtwork(
      with: UIImage.shuffle,
      iconSizeType: .small,
      theme: appDelegate.storage.settings.themePreference,
      lightDarkMode: traits.userInterfaceStyle.asModeType,
      switchColors: true
    ).carPlayImage(carTraitCollection: traits)
    let listItem = CPListItem(text: text, detailText: nil, image: img)
    listItem.handler = { [weak self] item, completion in
      guard let self = self else { completion(); return }
      appDelegate.player.play(context: playContext.getWithShuffledIndex())
      displayNowPlaying {
        completion()
      }
    }
    return listItem
  }

  private func createPlayShuffledListItem(
    playContext: PlayContext,
    text: String = "Shuffle"
  )
    -> CPListItem {
    let img = UIImage.createArtwork(
      with: UIImage.shuffle,
      iconSizeType: .small,
      theme: appDelegate.storage.settings.themePreference,
      lightDarkMode: traits.userInterfaceStyle.asModeType,
      switchColors: true
    ).carPlayImage(carTraitCollection: traits)
    let listItem = CPListItem(text: text, detailText: nil, image: img)
    listItem.handler = { [weak self] item, completion in
      guard let self = self else { completion(); return }
      appDelegate.player.playShuffled(context: playContext)
      displayNowPlaying {
        completion()
      }
    }
    return listItem
  }

  private func createDetailTemplate(for episode: PodcastEpisode) -> CPListItem {
    let accessoryType: CPListItemAccessoryType = episode.isCached ? .cloud : .none
    let listItem = CPListItem(
      text: episode.title,
      detailText: nil,
      image: nil,
      accessoryImage: nil,
      accessoryType: accessoryType
    )
    listItem.handler = { [weak self] item, completion in
      guard let self = self else { completion(); return }
      appDelegate.player.play(context: PlayContext(containable: episode))
      displayNowPlaying {
        completion()
      }
    }
    return listItem
  }

  enum CarPlayListUserInfoKeys: String {
    case playableDownloadID
    case artworkDownloadID
    case artworkOwnerType
    case artworkOwnerObjectID
    case isTrackDisplayed
  }

  private func createDetailTemplate(
    for playable: AbstractPlayable,
    playContext: PlayContext,
    isTrackDisplayed: Bool = false
  )
    -> CPListItem {
    let accessoryType: CPListItemAccessoryType = playable.isCached ? .cloud : .none
    let image = getImage(for: playable, isTrackDisplayed: isTrackDisplayed)
    if let artwork = playable.artwork {
      appDelegate.artworkDownloadManager.download(object: artwork)
    }
    let listItem = CPListItem(
      text: playable.title,
      detailText: playable.subtitle,
      image: image.carPlayImage(carTraitCollection: traits),
      accessoryImage: nil,
      accessoryType: accessoryType
    )
    listItem.userInfo = [
      CarPlayListUserInfoKeys.playableDownloadID.rawValue: playable.uniqueID,
      CarPlayListUserInfoKeys.artworkDownloadID.rawValue: playable.artwork?.uniqueID as Any,
      CarPlayListUserInfoKeys.artworkOwnerObjectID.rawValue: playable.objectID,
      CarPlayListUserInfoKeys.artworkOwnerType.rawValue: playable.isSong ? ArtworkType
        .song : ArtworkType.podcastEpisode,
      CarPlayListUserInfoKeys.isTrackDisplayed.rawValue: isTrackDisplayed,
    ]
    listItem.handler = { [weak self] item, completion in
      guard let self = self else { completion(); return }
      appDelegate.player.play(context: playContext)
      displayNowPlaying {
        completion()
      }
    }
    return listItem
  }

  private func getImage(for playable: AbstractPlayable, isTrackDisplayed: Bool) -> UIImage {
    isTrackDisplayed ? UIImage.numberToImage(number: playable.track) :
      LibraryEntityImage.getImageToDisplayImmediately(
        libraryEntity: playable,
        themePreference: appDelegate.storage.settings.themePreference,
        artworkDisplayPreference: artworkDisplayPreference,
        useCache: false
      )
  }

  @objc
  private func downloadFinishedSuccessful(notification: Notification) {
    guard let downloadNotification = DownloadNotification.fromNotification(notification)
    else { return }
    guard let templates = interfaceController?.templates else { return }

    for template in templates {
      var sections: [CPListSection]?

      if let listTemplate = template as? CPListTemplate {
        sections = listTemplate.sections
      } else if let tabBarTemplate = template as? CPTabBarTemplate,
                let selectedTemplate = tabBarTemplate.selectedTemplate as? CPListTemplate {
        sections = selectedTemplate.sections
      }

      guard let sections = sections else { continue }
      for section in sections {
        for listTemplateItem in section.items {
          guard let item = listTemplateItem as? CPListItem,
                let userInfo = item.userInfo as? [String: Any]
          else { continue }

          var isThisRelatedToTheDownload = false
          var isTrackDisplayed = false
          var playable: AbstractPlayable?
          var entity: AbstractLibraryEntity?

          for info in userInfo {
            if info.key == CarPlayListUserInfoKeys.playableDownloadID.rawValue ||
              info.key == CarPlayListUserInfoKeys.artworkDownloadID.rawValue,
              let uniqueID = info.value as? String,
              uniqueID == downloadNotification.id {
              isThisRelatedToTheDownload = true
            } else if info.key == CarPlayListUserInfoKeys.artworkOwnerType.rawValue,
                      let ownerType = info.value as? ArtworkType,
                      let objectIdInfo = userInfo
                      .first(where: {
                        $0.key == CarPlayListUserInfoKeys.artworkOwnerObjectID.rawValue
                      }),
                      let managedObjectID = objectIdInfo.value as? NSManagedObjectID {
              switch ownerType {
              case .song:
                let mo = appDelegate.storage.main.context.object(with: managedObjectID) as? SongMO
                if let mo = mo {
                  playable = Song(managedObject: mo)
                }
              case .album:
                let mo = appDelegate.storage.main.context.object(with: managedObjectID) as? AlbumMO
                if let mo = mo {
                  entity = Album(managedObject: mo)
                }
              case .artist:
                let mo = appDelegate.storage.main.context.object(with: managedObjectID) as? ArtistMO
                if let mo = mo {
                  entity = Artist(managedObject: mo)
                }
              case .podcast:
                let mo = appDelegate.storage.main.context
                  .object(with: managedObjectID) as? PodcastMO
                if let mo = mo {
                  entity = Podcast(managedObject: mo)
                }
              case .podcastEpisode:
                let mo = appDelegate.storage.main.context
                  .object(with: managedObjectID) as? PodcastEpisodeMO
                if let mo = mo {
                  playable = PodcastEpisode(managedObject: mo)
                }
              case .radio:
                let mo = appDelegate.storage.main.context.object(with: managedObjectID) as? RadioMO
                if let mo = mo {
                  playable = Radio(managedObject: mo)
                }
              default: break
              }
            } else if info.key == CarPlayListUserInfoKeys.isTrackDisplayed.rawValue {
              isTrackDisplayed = (info.value as? Bool) ?? false
            }
          }

          if isThisRelatedToTheDownload {
            if let playable = playable {
              item.setImage(getImage(for: playable, isTrackDisplayed: isTrackDisplayed))
            } else if let entity = entity {
              item.setImage(
                LibraryEntityImage.getImageToDisplayImmediately(
                  libraryEntity: entity,
                  themePreference: appDelegate.storage.settings.themePreference,
                  artworkDisplayPreference: artworkDisplayPreference,
                  useCache: false
                ).carPlayImage(carTraitCollection: traits)
              )
            }
          }
        }
      }
    }
  }

  @objc
  private func refreshSort() {
    guard let templates = interfaceController?.templates else { return }
    if let root = interfaceController?.rootTemplate as? CPTabBarTemplate,
       root.selectedTemplate == playlistTab,
       playlistFetchController?.sortType != appDelegate.storage.settings.playlistsSortSetting {
      os_log("CarPlay: RefreshSort: PlaylistFetchController", log: self.log, type: .info)
      createPlaylistFetchController()
      playlistTab.updateSections([CPListSection(items: createPlaylistsSections())])
    }
    if artistsFavoritesFetchController?.sortType != appDelegate.storage.settings
      .artistsSortSetting {
      os_log("CarPlay: RefreshSort: ArtistsFavoritesFetchController", log: self.log, type: .info)
      createArtistsFavoritesFetchController()
      artistsFavoriteSection.updateSections([CPListSection(items: createArtistItems(
        from: artistsFavoritesFetchController,
        onlyCached: isOfflineMode
      ))])
    }
    if artistsFavoritesCachedFetchController?.sortType != appDelegate.storage.settings
      .artistsSortSetting {
      os_log(
        "CarPlay: RefreshSort: ArtistsFavoritesCachedFetchController",
        log: self.log,
        type: .info
      )
      createArtistsFavoritesCachedFetchController()
      artistsFavoriteCachedSection.updateSections([CPListSection(items: createArtistItems(
        from: artistsFavoritesCachedFetchController,
        onlyCached: true
      ))])
    }
    if templates.contains(albumsFavoriteSection),
       albumsFavoritesFetchController?.sortType != appDelegate.storage.settings.albumsSortSetting {
      os_log("CarPlay: RefreshSort: AlbumsFavoritesFetchController", log: self.log, type: .info)
      createAlbumsFavoritesFetchController()
      albumsFavoriteSection.updateSections([CPListSection(items: createAlbumItems(
        from: albumsFavoritesFetchController,
        onlyCached: isOfflineMode
      ))])
    }
    if templates.contains(albumsFavoriteCachedSection),
       albumsFavoritesCachedFetchController?.sortType != appDelegate.storage.settings
       .albumsSortSetting {
      os_log(
        "CarPlay: RefreshSort: AlbumsFavoritesCachedFetchController",
        log: self.log,
        type: .info
      )
      createAlbumsFavoritesCachedFetchController()
      albumsFavoriteCachedSection.updateSections([CPListSection(items: createAlbumItems(
        from: albumsFavoritesCachedFetchController,
        onlyCached: true
      ))])
    }
    if templates.contains(songsFavoriteSection),
       (appDelegate.backendApi.selectedApi != .ampache) ?
       (
         songsFavoritesFetchController?.sortType != appDelegate.storage.settings
           .favoriteSongSortSetting
       ) :
       (songsFavoritesFetchController?.sortType != appDelegate.storage.settings.songsSortSetting) {
      os_log("CarPlay: RefreshSort: SongsFavoritesFetchController", log: self.log, type: .info)
      createSongsFavoritesFetchController()
      songsFavoriteSection
        .updateSections(
          [CPListSection(items: createSongItems(from: songsFavoritesFetchController))]
        )
    }
    if templates.contains(songsFavoriteCachedSection),
       (appDelegate.backendApi.selectedApi != .ampache) ?
       (
         songsFavoritesCachedFetchController?.sortType != appDelegate.storage.settings
           .favoriteSongSortSetting
       ) :
       (
         songsFavoritesCachedFetchController?.sortType != appDelegate.storage.settings
           .songsSortSetting
       ) {
      os_log(
        "CarPlay: RefreshSort: SongsFavoritesCachedFetchController",
        log: self.log,
        type: .info
      )
      createSongsFavoritesCachedFetchController()
      songsFavoriteCachedSection
        .updateSections(
          [CPListSection(items: createSongItems(from: songsFavoritesCachedFetchController))]
        )
    }
  }

  @objc
  private func refreshOfflineMode() {
    os_log("CarPlay: OfflineModeChanged", log: self.log, type: .info)
    guard let templates = interfaceController?.templates else { return }

    if let root = interfaceController?.rootTemplate as? CPTabBarTemplate,
       root.selectedTemplate == playlistTab {
      os_log("CarPlay: OfflineModeChanged: playlistFetchController", log: self.log, type: .info)
      createPlaylistFetchController()
      playlistTab.updateSections([CPListSection(items: createPlaylistsSections())])
    }
    if let root = interfaceController?.rootTemplate as? CPTabBarTemplate,
       root.selectedTemplate == podcastTab {
      os_log("CarPlay: OfflineModeChanged: podcastFetchController", log: self.log, type: .info)
      createPodcastFetchController()
      podcastTab.updateSections([CPListSection(items: createPodcastsSections())])
    }
    if templates.contains(artistsFavoriteSection) {
      os_log(
        "CarPlay: OfflineModeChanged: artistsFavoritesFetchController",
        log: self.log,
        type: .info
      )
      createArtistsFavoritesFetchController()
      artistsFavoriteSection.updateSections([CPListSection(items: createArtistItems(
        from: artistsFavoritesFetchController,
        onlyCached: isOfflineMode
      ))])
    }
    if templates.contains(albumsFavoriteSection) {
      os_log(
        "CarPlay: OfflineModeChanged: albumsFavoritesFetchController",
        log: self.log,
        type: .info
      )
      createAlbumsFavoritesFetchController()
      albumsFavoriteSection.updateSections([CPListSection(items: createAlbumItems(
        from: albumsFavoritesFetchController,
        onlyCached: isOfflineMode
      ))])
    }
    if templates.contains(albumsNewestSection) {
      os_log("CarPlay: OfflineModeChanged: albumsNewestFetchController", log: self.log, type: .info)
      createAlbumsNewestFetchController()
      albumsNewestSection.updateSections([CPListSection(items: createAlbumItems(
        from: albumsNewestFetchController,
        onlyCached: isOfflineMode
      ))])
    }
    if templates.contains(albumsRecentSection) {
      os_log("CarPlay: OfflineModeChanged: albumsRecentFetchController", log: self.log, type: .info)
      createAlbumsRecentFetchController()
      albumsRecentSection.updateSections([CPListSection(items: createAlbumItems(
        from: albumsRecentFetchController,
        onlyCached: isOfflineMode
      ))])
    }
    if templates.contains(songsFavoriteSection) {
      os_log(
        "CarPlay: OfflineModeChanged: songsFavoritesFetchController",
        log: self.log,
        type: .info
      )
      createSongsFavoritesFetchController()
      songsFavoriteSection
        .updateSections(
          [CPListSection(items: createSongItems(from: songsFavoritesFetchController))]
        )
    }
    if let playlistDetailSection = playlistDetailSection, templates.contains(playlistDetailSection),
       let playlistDetailFetchController = playlistDetailFetchController {
      os_log("CarPlay: OfflineModeChanged: playlistDetailSection", log: self.log, type: .info)
      playlistDetailFetchController.search(onlyCachedSongs: isOfflineMode)
      playlistDetailSection
        .updateSections(
          [CPListSection(items: createPlaylistDetailItems(from: playlistDetailFetchController))]
        )
    }
    if let podcastDetailSection = podcastDetailSection, templates.contains(podcastDetailSection),
       let podcastDetailFetchController = podcastDetailFetchController {
      os_log("CarPlay: OfflineModeChanged: podcastDetailSection", log: self.log, type: .info)
      podcastDetailFetchController.search(searchText: "", onlyCachedSongs: isOfflineMode)
      podcastDetailSection
        .updateSections(
          [CPListSection(items: createPodcastDetailItems(from: podcastDetailFetchController))]
        )
    }
  }
}

extension CarPlaySceneDelegate: @preconcurrency NSFetchedResultsControllerDelegate {
  func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
    // fetch controller is created on Main thread -> Runtime Error if this function call is not on Main thread
    MainActor.assumeIsolated {
      guard let templates = self.interfaceController?.templates else { return }
      if let root = self.interfaceController?.rootTemplate as? CPTabBarTemplate,
         root.selectedTemplate == playlistTab,
         let playlistFetchController = playlistFetchController,
         controller == playlistFetchController.fetchResultsController {
        os_log("CarPlay: FetchedResults: playlistFetchController", log: self.log, type: .info)
        playlistTab.updateSections([CPListSection(items: createPlaylistsSections())])
      }
      if let root = self.interfaceController?.rootTemplate as? CPTabBarTemplate,
         root.selectedTemplate == podcastTab,
         let podcastFetchController = podcastFetchController,
         controller == podcastFetchController.fetchResultsController {
        os_log("CarPlay: FetchedResults: podcastFetchController", log: self.log, type: .info)
        podcastTab.updateSections([CPListSection(items: createPodcastsSections())])
      }

      if templates.contains(radioSection), let radiosFetchController = radiosFetchController,
         controller == radiosFetchController.fetchResultsController {
        os_log("CarPlay: FetchedResults: radiosFetchController", log: self.log, type: .info)
        radioSection
          .updateSections([CPListSection(items: createRadioItems(from: radiosFetchController))])
      }
      if templates.contains(artistsFavoriteSection),
         let artistsFavoritesFetchController = artistsFavoritesFetchController,
         controller == artistsFavoritesFetchController.fetchResultsController {
        os_log(
          "CarPlay: FetchedResults: artistsFavoritesFetchController",
          log: self.log,
          type: .info
        )
        artistsFavoriteSection.updateSections([CPListSection(items: createArtistItems(
          from: artistsFavoritesFetchController,
          onlyCached: isOfflineMode
        ))])
      }
      if templates.contains(artistsFavoriteCachedSection),
         let artistsFavoritesCachedFetchController = artistsFavoritesCachedFetchController,
         controller == artistsFavoritesCachedFetchController.fetchResultsController {
        os_log(
          "CarPlay: FetchedResults: artistsFavoritesCachedFetchController",
          log: self.log,
          type: .info
        )
        artistsFavoriteCachedSection.updateSections([CPListSection(items: createArtistItems(
          from: artistsFavoritesCachedFetchController,
          onlyCached: true
        ))])
      }
      if templates.contains(albumsFavoriteSection),
         let albumsFavoritesFetchController = albumsFavoritesFetchController,
         controller == albumsFavoritesFetchController.fetchResultsController {
        os_log(
          "CarPlay: FetchedResults: albumsFavoritesFetchController",
          log: self.log,
          type: .info
        )
        albumsFavoriteSection.updateSections([CPListSection(items: createAlbumItems(
          from: albumsFavoritesFetchController,
          onlyCached: isOfflineMode
        ))])
      }
      if templates.contains(albumsFavoriteCachedSection),
         let albumsFavoritesCachedFetchController = albumsFavoritesCachedFetchController,
         controller == albumsFavoritesCachedFetchController.fetchResultsController {
        os_log(
          "CarPlay: FetchedResults: albumsFavoritesCachedFetchController",
          log: self.log,
          type: .info
        )
        albumsFavoriteCachedSection.updateSections([CPListSection(items: createAlbumItems(
          from: albumsFavoritesCachedFetchController,
          onlyCached: true
        ))])
      }
      if templates.contains(albumsNewestSection),
         let albumsNewestFetchController = albumsNewestFetchController,
         controller == albumsNewestFetchController.fetchResultsController {
        os_log("CarPlay: FetchedResults: albumsNewestFetchController", log: self.log, type: .info)
        albumsNewestSection.updateSections([CPListSection(items: createAlbumItems(
          from: albumsNewestFetchController,
          onlyCached: isOfflineMode
        ))])
      }
      if templates.contains(albumsNewestCachedSection),
         let albumsNewestCachedFetchController = albumsNewestCachedFetchController,
         controller == albumsNewestCachedFetchController.fetchResultsController {
        os_log(
          "CarPlay: FetchedResults: albumsNewestCachedFetchController",
          log: self.log,
          type: .info
        )
        albumsNewestCachedSection.updateSections([CPListSection(items: createAlbumItems(
          from: albumsNewestCachedFetchController,
          onlyCached: true
        ))])
      }
      if templates.contains(albumsRecentSection),
         let albumsRecentFetchController = albumsRecentFetchController,
         controller == albumsRecentFetchController.fetchResultsController {
        os_log("CarPlay: FetchedResults: albumsRecentFetchController", log: self.log, type: .info)
        albumsRecentSection.updateSections([CPListSection(items: createAlbumItems(
          from: albumsRecentFetchController,
          onlyCached: isOfflineMode
        ))])
      }
      if templates.contains(albumsRecentCachedSection),
         let albumsRecentCachedFetchController = albumsRecentCachedFetchController,
         controller == albumsRecentCachedFetchController.fetchResultsController {
        os_log(
          "CarPlay: FetchedResults: albumsRecentCachedFetchController",
          log: self.log,
          type: .info
        )
        albumsRecentCachedSection.updateSections([CPListSection(items: createAlbumItems(
          from: albumsRecentCachedFetchController,
          onlyCached: true
        ))])
      }
      if templates.contains(songsFavoriteSection),
         let songsFavoritesFetchController = songsFavoritesFetchController,
         controller == songsFavoritesFetchController.fetchResultsController {
        os_log("CarPlay: FetchedResults: songsFavoritesFetchController", log: self.log, type: .info)
        songsFavoriteSection
          .updateSections(
            [CPListSection(items: createSongItems(from: songsFavoritesFetchController))]
          )
      }
      if templates.contains(songsFavoriteCachedSection),
         let songsFavoritesCachedFetchController = songsFavoritesCachedFetchController,
         controller == songsFavoritesCachedFetchController.fetchResultsController {
        os_log(
          "CarPlay: FetchedResults: songsFavoritesCachedFetchController",
          log: self.log,
          type: .info
        )
        songsFavoriteCachedSection
          .updateSections(
            [CPListSection(items: createSongItems(from: songsFavoritesCachedFetchController))]
          )
      }
      if let playlistDetailSection = playlistDetailSection,
         templates.contains(playlistDetailSection),
         let playlistDetailFetchController = playlistDetailFetchController,
         controller == playlistDetailFetchController.fetchResultsController {
        os_log("CarPlay: FetchedResults: playlistDetailSection", log: self.log, type: .info)
        playlistDetailSection
          .updateSections(
            [CPListSection(items: createPlaylistDetailItems(from: playlistDetailFetchController))]
          )
      }
      if let podcastDetailSection = podcastDetailSection, templates.contains(podcastDetailSection),
         let podcastDetailFetchController = podcastDetailFetchController,
         controller == podcastDetailFetchController.fetchResultsController {
        os_log("CarPlay: FetchedResults: podcastDetailSection", log: self.log, type: .info)
        podcastDetailSection
          .updateSections(
            [CPListSection(items: createPodcastDetailItems(from: podcastDetailFetchController))]
          )
      }
    }
  }
}

// MARK: CPInterfaceControllerDelegate

extension CarPlaySceneDelegate: CPInterfaceControllerDelegate {
  nonisolated func templateWillAppear(_ aTemplate: CPTemplate, animated: Bool) {
    Task { @MainActor in
      if aTemplate == playerQueueSection {
        os_log("CarPlay: templateWillAppear playerQueueSection", log: self.log, type: .info)
        playerQueueSection.updateSections(createPlayerQueueSections())
      } else if aTemplate == libraryTab {
        os_log("CarPlay: templateWillAppear libraryTab", log: self.log, type: .info)
        libraryTab.updateSections(createLibrarySections())
      } else if aTemplate == cachedTab {
        os_log("CarPlay: templateWillAppear cachedTab", log: self.log, type: .info)
        libraryTab.updateSections(createCachedSections())
      } else if aTemplate == playlistTab {
        os_log("CarPlay: templateWillAppear playlistTab", log: self.log, type: .info)
        Task { @MainActor in do {
          try await self.appDelegate.librarySyncer.syncDownPlaylistsWithoutSongs()
        } catch {
          self.appDelegate.eventLogger.report(topic: "CarPlay: Playlists Sync", error: error)
        }}
        if playlistFetchController == nil { createPlaylistFetchController() }
        playlistTab.updateSections([CPListSection(items: createPlaylistsSections())])
      } else if aTemplate == podcastTab {
        os_log("CarPlay: templateWillAppear podcastTab", log: self.log, type: .info)
        if podcastFetchController == nil { createPodcastFetchController() }
        podcastTab.updateSections([CPListSection(items: createPodcastsSections())])
      } else if aTemplate == radioSection {
        os_log("CarPlay: templateWillAppear radioSection", log: self.log, type: .info)
        if radiosFetchController == nil { createRadiosFetchController() }
        radioSection
          .updateSections([CPListSection(items: createRadioItems(from: radiosFetchController))])
      } else if aTemplate == artistsFavoriteSection {
        os_log("CarPlay: templateWillAppear artistsFavoriteSection", log: self.log, type: .info)
        if artistsFavoritesFetchController == nil { createArtistsFavoritesFetchController() }
        artistsFavoriteSection.updateSections([CPListSection(items: createArtistItems(
          from: artistsFavoritesFetchController,
          onlyCached: isOfflineMode
        ))])
      } else if aTemplate == artistsFavoriteCachedSection {
        os_log(
          "CarPlay: templateWillAppear artistsFavoriteCachedSection",
          log: self.log,
          type: .info
        )
        if artistsFavoritesCachedFetchController ==
          nil { createArtistsFavoritesCachedFetchController() }
        artistsFavoriteCachedSection.updateSections([CPListSection(items: createArtistItems(
          from: artistsFavoritesCachedFetchController,
          onlyCached: true
        ))])
      } else if aTemplate == albumsFavoriteSection {
        os_log("CarPlay: templateWillAppear albumsFavoriteSection", log: self.log, type: .info)
        if albumsFavoritesFetchController == nil { createAlbumsFavoritesFetchController() }
        albumsFavoriteSection.updateSections([CPListSection(items: createAlbumItems(
          from: albumsFavoritesFetchController,
          onlyCached: isOfflineMode
        ))])
      } else if aTemplate == albumsFavoriteCachedSection {
        os_log(
          "CarPlay: templateWillAppear albumsFavoriteCachedSection",
          log: self.log,
          type: .info
        )
        if albumsFavoritesCachedFetchController ==
          nil { createAlbumsFavoritesCachedFetchController() }
        albumsFavoriteCachedSection.updateSections([CPListSection(items: createAlbumItems(
          from: albumsFavoritesCachedFetchController,
          onlyCached: true
        ))])
      } else if aTemplate == albumsNewestSection {
        os_log("CarPlay: templateWillAppear albumsNewestSection", log: self.log, type: .info)
        if albumsNewestFetchController == nil { createAlbumsNewestFetchController() }
        albumsNewestSection.updateSections([CPListSection(items: createAlbumItems(
          from: albumsNewestFetchController,
          onlyCached: isOfflineMode
        ))])
      } else if aTemplate == albumsNewestCachedSection {
        os_log("CarPlay: templateWillAppear albumsNewestCachedSection", log: self.log, type: .info)
        if albumsNewestCachedFetchController == nil { createAlbumsNewestCachedFetchController() }
        albumsNewestCachedSection.updateSections([CPListSection(items: createAlbumItems(
          from: albumsNewestCachedFetchController,
          onlyCached: true
        ))])
      } else if aTemplate == albumsRecentSection {
        os_log("CarPlay: templateWillAppear albumsRecentSection", log: self.log, type: .info)
        Task { @MainActor in do {
          try await self.appDelegate.librarySyncer.syncRecentAlbums(
            offset: 0,
            count: AmperKit.newestElementsFetchCount
          )
        } catch {
          self.appDelegate.eventLogger.report(topic: "Recent Albums Sync", error: error)
        }}
        if albumsRecentFetchController == nil { createAlbumsRecentFetchController() }
        albumsRecentSection.updateSections([CPListSection(items: createAlbumItems(
          from: albumsRecentFetchController,
          onlyCached: isOfflineMode
        ))])
      } else if aTemplate == albumsRecentCachedSection {
        os_log("CarPlay: templateWillAppear albumsRecentCachedSection", log: self.log, type: .info)
        if albumsRecentCachedFetchController == nil { createAlbumsRecentCachedFetchController() }
        albumsRecentCachedSection.updateSections([CPListSection(items: createAlbumItems(
          from: albumsRecentCachedFetchController,
          onlyCached: true
        ))])
      } else if aTemplate == songsFavoriteSection {
        os_log("CarPlay: templateWillAppear songsFavoriteSection", log: self.log, type: .info)
        if songsFavoritesFetchController == nil { createSongsFavoritesFetchController() }
        songsFavoriteSection
          .updateSections(
            [CPListSection(items: createSongItems(from: songsFavoritesFetchController))]
          )
      } else if aTemplate == songsFavoriteCachedSection {
        os_log("CarPlay: templateWillAppear songsFavoriteCachedSection", log: self.log, type: .info)
        if songsFavoritesCachedFetchController ==
          nil { createSongsFavoritesCachedFetchController() }
        songsFavoriteCachedSection
          .updateSections(
            [CPListSection(items: createSongItems(from: songsFavoritesCachedFetchController))]
          )
      } else if aTemplate == playlistDetailSection,
                let playlistDetailFetchController = playlistDetailFetchController {
        os_log("CarPlay: templateWillAppear playlistDetailSection", log: self.log, type: .info)
        Task { @MainActor in do {
          try await playlistDetailFetchController.playlist.fetch(
            storage: self.appDelegate.storage,
            librarySyncer: self.appDelegate.librarySyncer,
            playableDownloadManager: self.appDelegate.playableDownloadManager
          )
        } catch {
          self.appDelegate.eventLogger.report(topic: "Playlist Sync", error: error)
        }}
        playlistDetailSection?
          .updateSections(
            [CPListSection(items: createPlaylistDetailItems(from: playlistDetailFetchController))]
          )
      } else if aTemplate == podcastDetailSection,
                let podcastDetailFetchController = podcastDetailFetchController {
        os_log("CarPlay: templateWillAppear podcastDetailSection", log: self.log, type: .info)
        Task { @MainActor in do {
          try await podcastDetailFetchController.podcast.fetch(
            storage: self.appDelegate.storage,
            librarySyncer: self.appDelegate.librarySyncer,
            playableDownloadManager: self.appDelegate.playableDownloadManager
          )
        } catch {
          self.appDelegate.eventLogger.report(topic: "Podcast Sync", error: error)
        }}
        podcastDetailSection?
          .updateSections(
            [CPListSection(items: createPodcastDetailItems(from: podcastDetailFetchController))]
          )
      }
    }
  }

  nonisolated func templateDidAppear(_ aTemplate: CPTemplate, animated: Bool) {}
  nonisolated func templateWillDisappear(_ aTemplate: CPTemplate, animated: Bool) {}

  nonisolated func templateDidDisappear(_ aTemplate: CPTemplate, animated: Bool) {
    Task { @MainActor in
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
}
