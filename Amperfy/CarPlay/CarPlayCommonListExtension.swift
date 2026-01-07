//
//  CarPlayCommonListExtension.swift
//  Amperfy
//
//  Created by Maximilian Bauer on 02.01.26.
//  Copyright (c) 2026 Maximilian Bauer. All rights reserved.
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
  func createArtistItems(
    from fetchedController: ArtistFetchedResultsController?,
    onlyCached: Bool
  )
    -> [CPListSection] {
    var sections = [CPListSection]()
    guard let fetchedController = fetchedController,
          let fetchSections = fetchedController.sections else { return sections }
    let maxSectionCount = CPListTemplate
      .maximumItemCount / (!fetchSections.isEmpty ? fetchSections.count : 1)
    for fetchSection in fetchSections {
      guard let fetchObjects = fetchSection.objects as? [ArtistMO] else { continue }
      var items = [CPListTemplateItem]()

      var indexTitle: String?
      if fetchedController.sortType.asSectionIndexType == .alphabet {
        indexTitle = fetchObjects.first?.name?.prefix(1).uppercased()
        if let _ = Int(indexTitle ?? "-") {
          indexTitle = "#"
        }
      }
      for (index, fetchObject) in fetchObjects.enumerated() {
        let artist = Artist(managedObject: fetchObject)
        let detailTemplate = createDetailTemplate(for: artist, onlyCached: onlyCached)
        items.append(detailTemplate)
        if index >= maxSectionCount { break }
      }
      let section = CPListSection(items: items, header: nil, sectionIndexTitle: indexTitle)
      sections.append(section)
    }
    return sections
  }

  func createAlbumItems(
    from fetchedController: AlbumFetchedResultsController?,
    onlyCached: Bool
  )
    -> [CPListSection] {
    var sections = [CPListSection]()
    guard let fetchedController = fetchedController,
          let fetchSections = fetchedController.sections else { return sections }
    let maxSectionCount = CPListTemplate
      .maximumItemCount / (!fetchSections.isEmpty ? fetchSections.count : 1)
    for fetchSection in fetchSections {
      guard let fetchObjects = fetchSection.objects as? [AlbumMO] else { continue }
      var items = [CPListTemplateItem]()

      var indexTitle: String?
      if fetchedController.sortType.asSectionIndexType == .alphabet {
        indexTitle = fetchObjects.first?.name?.prefix(1).uppercased()
        if let _ = Int(indexTitle ?? "-") {
          indexTitle = "#"
        }
      }
      for (index, fetchObject) in fetchObjects.enumerated() {
        let album = Album(managedObject: fetchObject)
        let detailTemplate = createDetailTemplate(for: album, onlyCached: onlyCached)
        items.append(detailTemplate)
        if index >= maxSectionCount { break }
      }
      let section = CPListSection(items: items, header: nil, sectionIndexTitle: indexTitle)
      sections.append(section)
    }
    return sections
  }

  func createSongItems(from fetchedController: BasicFetchedResultsController<SongMO>?)
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

  func createPlaylistDetailItems(
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

  func createPodcastDetailItems(
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

  func createDetailTemplate(for artist: Artist, onlyCached: Bool) -> CPListItem {
    let section = CPListItem(
      text: artist.name,
      detailText: artist.subtitle,
      image: LibraryEntityImage.getImageToDisplayImmediately(
        libraryEntity: artist,
        themePreference: getPreference(activeAccountInfo).theme,
        artworkDisplayPreference: getPreference(activeAccountInfo).artworkDisplayPreference,
        useCache: false
      ).carPlayImage(carTraitCollection: traits),
      accessoryImage: nil,
      accessoryType: .disclosureIndicator
    )
    if let artwork = artist.artwork, let accountInfo = artwork.account?.info {
      appDelegate.getMeta(accountInfo).artworkDownloadManager.download(object: artwork)
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
        for: activeAccount,
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

  func createDetailAllSongsTemplate(for artist: Artist, onlyCached: Bool) -> CPListItem {
    let section = CPListItem(
      text: "All Songs",
      detailText: nil,
      image: UIImage.createArtwork(
        with: UIImage.musicalNotes,
        iconSizeType: .small,
        theme: getPreference(activeAccountInfo).theme,
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

  func createDetailTemplate(for album: Album, onlyCached: Bool) -> CPListItem {
    let section = CPListItem(
      text: album.name,
      detailText: album.subtitle,
      image: LibraryEntityImage.getImageToDisplayImmediately(
        libraryEntity: album,
        themePreference: getPreference(activeAccountInfo).theme,
        artworkDisplayPreference: getPreference(activeAccountInfo).artworkDisplayPreference,
        useCache: false
      ).carPlayImage(carTraitCollection: traits),
      accessoryImage: nil,
      accessoryType: .disclosureIndicator
    )
    if let artwork = album.artwork, let accountInfo = artwork.account?.info {
      appDelegate.getMeta(accountInfo).artworkDownloadManager.download(object: artwork)
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

  func createPlaylistsSections() -> [CPListSection] {
    var sections = [CPListSection]()
    var itemCount = 0
    guard let fetchedController = playlistFetchController,
          let fetchSections = fetchedController.sections else { return sections }
    for fetchSection in fetchSections {
      guard let fetchObjects = fetchSection.objects as? [PlaylistMO] else { continue }
      var items = [CPListTemplateItem]()

      var indexTitle: String?
      if fetchedController.sortType.asSectionIndexType == .alphabet {
        indexTitle = fetchObjects.first?.name?.prefix(1).uppercased()
        if let _ = Int(indexTitle ?? "-") {
          indexTitle = "#"
        }
      }

      for fetchObject in fetchObjects {
        let playlist = Playlist(
          library: appDelegate.storage.main.library,
          managedObject: fetchObject
        )
        let item = CPListItem(
          text: playlist.name,
          detailText: playlist.subtitle,
          image: nil,
          accessoryImage: nil,
          accessoryType: .disclosureIndicator
        )
        item.handler = { [weak self] item, completion in
          guard let self = self else { completion(); return }
          let playlistDetailTemplate = CPListTemplate(title: playlist.name, sections: [
            CPListSection(items: [CPListTemplateItem]()),
          ])
          playlistDetailSection = playlistDetailTemplate
          createPlaylistDetailFetchController(playlist: playlist)
          interfaceController?.pushTemplate(playlistDetailTemplate, animated: true, completion: nil)
          completion()
        }
        items.append(item)
        itemCount += 1
        if itemCount > CPListTemplate.maximumItemCount { break }
      }
      let section = CPListSection(items: items, header: nil, sectionIndexTitle: indexTitle)
      sections.append(section)
      if itemCount > CPListTemplate.maximumItemCount { break }
    }
    return sections
  }

  func createPodcastsSections(
    from fetchedController: BasicFetchedResultsController<PodcastMO>?,
    onlyCached: Bool
  )
    -> [CPListSection] {
    var sections = [CPListSection]()
    var itemCount = 0
    guard let fetchedController,
          let fetchSections = fetchedController.sections else { return sections }
    for fetchSection in fetchSections {
      guard let fetchObjects = fetchSection.objects as? [PodcastMO] else { continue }
      var items = [CPListTemplateItem]()

      var indexTitle: String?
      indexTitle = fetchObjects.first?.title?.prefix(1).uppercased()
      if let _ = Int(indexTitle ?? "-") {
        indexTitle = "#"
      }

      for fetchObject in fetchObjects {
        let podcast = Podcast(managedObject: fetchObject)

        let item = CPListItem(
          text: podcast.title,
          detailText: podcast.subtitle,
          image: LibraryEntityImage.getImageToDisplayImmediately(
            libraryEntity: podcast,
            themePreference: getPreference(activeAccountInfo).theme,
            artworkDisplayPreference: getPreference(activeAccountInfo).artworkDisplayPreference,
            useCache: false
          ).carPlayImage(carTraitCollection: traits),
          accessoryImage: nil,
          accessoryType: .disclosureIndicator
        )
        if let artwork = podcast.artwork, let accountInfo = artwork.account?.info {
          appDelegate.getMeta(accountInfo).artworkDownloadManager.download(object: artwork)
        }
        item.userInfo = [
          CarPlayListUserInfoKeys.artworkDownloadID.rawValue: podcast.artwork?.uniqueID as Any,
          CarPlayListUserInfoKeys.artworkOwnerObjectID.rawValue: podcast.managedObject
            .objectID as Any,
          CarPlayListUserInfoKeys.artworkOwnerType.rawValue: ArtworkType.podcast as Any,
        ]
        item.handler = { [weak self] item, completion in
          guard let self = self else { completion(); return }
          let podcastDetailTemplate = CPListTemplate(title: podcast.name, sections: [
            CPListSection(items: [CPListTemplateItem]()),
          ])
          podcastDetailSection = podcastDetailTemplate
          createPodcastDetailFetchController(podcast: podcast, onlyCached: onlyCached)
          interfaceController?.pushTemplate(podcastDetailTemplate, animated: true, completion: nil)
          completion()
        }
        items.append(item)
        itemCount += 1
        if itemCount > CPListTemplate.maximumItemCount { break }
      }
      let section = CPListSection(items: items, header: nil, sectionIndexTitle: indexTitle)
      sections.append(section)
      if itemCount > CPListTemplate.maximumItemCount { break }
    }
    return sections
  }

  func createGenreSections(
    from fetchedController: BasicFetchedResultsController<GenreMO>?,
    onlyCached: Bool
  )
    -> [CPListSection] {
    var sections = [CPListSection]()
    var itemCount = 0
    guard let fetchedController = fetchedController,
          let fetchSections = fetchedController.sections,
          !fetchSections.isEmpty else { return sections }

    for fetchSection in fetchSections {
      guard let fetchObjects = fetchSection.objects as? [GenreMO] else { continue }
      var items = [CPListTemplateItem]()

      var indexTitle: String?
      indexTitle = fetchObjects.first?.name?.prefix(1).uppercased()
      if let _ = Int(indexTitle ?? "-") {
        indexTitle = "#"
      }

      for fetchObject in fetchObjects {
        let genre = Genre(managedObject: fetchObject)
        let genreInfo = genre.info(
          for: activeAccount.apiType.asServerApiType,
          details: DetailInfoType(
            type: .short,
            settings: appDelegate.storage.settings
          )
        )
        let listItem = CPListItem(
          text: genre.name,
          detailText: genreInfo,
          image: LibraryEntityImage.getImageToDisplayImmediately(
            libraryEntity: genre,
            themePreference: getPreference(activeAccountInfo).theme,
            artworkDisplayPreference: getPreference(activeAccountInfo).artworkDisplayPreference,
            useCache: false
          ).carPlayImage(carTraitCollection: traits),
          accessoryImage: nil,
          accessoryType: .none
        )
        listItem.handler = { [weak self] item, completion in
          guard let self = self else { completion(); return }
          let songs = genre.playables.filterCached(dependigOn: onlyCached || isOfflineMode)
          let genrePlayContext = PlayContext(name: genre.name, playables: songs)
          appDelegate.player.play(context: genrePlayContext)
          displayNowPlaying {}
          completion()
        }
        items.append(listItem)
        itemCount += 1
        if itemCount > CPListTemplate.maximumItemCount { break }
      }
      let section = CPListSection(items: items, header: nil, sectionIndexTitle: indexTitle)
      sections.append(section)
      if itemCount > CPListTemplate.maximumItemCount { break }
    }
    return sections
  }

  func createRadioSections(from fetchedController: BasicFetchedResultsController<RadioMO>?)
    -> [CPListSection] {
    var sections = [CPListSection]()
    guard let fetchedController = fetchedController,
          let fetchSections = fetchedController.sections,
          !fetchSections.isEmpty else { return sections }

    guard let fetchedRadios = fetchedController.fetchedObjects else { return sections }
    let radios = fetchedRadios.prefix(CPListTemplate.maximumItemCount)
      .compactMap { Radio(managedObject: $0) }

    let playRandomItem = createPlayRandomListItem(playContext: PlayContext(
      name: "Radios",
      playables: radios
    ))
    let randomSection = CPListSection(items: [playRandomItem], header: nil, sectionIndexTitle: nil)
    sections.append(randomSection)
    var itemCount = 1

    for fetchSection in fetchSections {
      guard let fetchObjects = fetchSection.objects as? [RadioMO] else { continue }
      var items = [CPListTemplateItem]()

      var indexTitle: String?
      indexTitle = fetchObjects.first?.title?.prefix(1).uppercased()
      if let _ = Int(indexTitle ?? "-") {
        indexTitle = "#"
      }

      for fetchObject in fetchObjects {
        let radio = Radio(managedObject: fetchObject)
        let listItem = createDetailTemplate(
          for: radio,
          playContext: PlayContext(name: "Radios", index: itemCount - 1, playables: Array(radios)),
          isTrackDisplayed: false
        )
        items.append(listItem)
        itemCount += 1
        if itemCount > CPListTemplate.maximumItemCount { break }
      }
      let section = CPListSection(items: items, header: nil, sectionIndexTitle: indexTitle)
      sections.append(section)
      if itemCount > CPListTemplate.maximumItemCount { break }
    }
    return sections
  }

  func createPlayRandomListItem(
    playContext: PlayContext,
    text: String = "Random"
  )
    -> CPListItem {
    let img = UIImage.createArtwork(
      with: UIImage.shuffle,
      iconSizeType: .small,
      theme: getPreference(activeAccountInfo).theme,
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

  func createPlayShuffledListItem(
    playContext: PlayContext,
    text: String = "Shuffle"
  )
    -> CPListItem {
    let img = UIImage.createArtwork(
      with: UIImage.shuffle,
      iconSizeType: .small,
      theme: getPreference(activeAccountInfo).theme,
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

  func createDetailTemplate(for episode: PodcastEpisode) -> CPListItem {
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

  func createLibraryItem(
    text: String,
    subtitle: String? = nil,
    icon: UIImage,
    sectionToDisplay: CPListTemplate
  )
    -> CPListItem {
    let item = CPListItem(
      text: text,
      detailText: subtitle,
      image: UIImage
        .createArtwork(
          with: icon,
          iconSizeType: .small,
          theme: getPreference(activeAccountInfo).theme,
          lightDarkMode: traits.userInterfaceStyle.asModeType,
          switchColors: true
        )
        .carPlayImage(carTraitCollection: traits),
      accessoryImage: nil,
      accessoryType: .disclosureIndicator
    )
    item.handler = { [weak self] item, completion in
      guard let self = self else { completion(); return }
      Task { @MainActor in
        let _ = try? await interfaceController?
          .pushTemplate(sectionToDisplay, animated: true)
        completion()
      }
    }
    return item
  }

  enum CarPlayListUserInfoKeys: String {
    case playableDownloadID
    case artworkDownloadID
    case artworkOwnerType
    case artworkOwnerObjectID
    case isTrackDisplayed
  }

  func createDetailTemplate(
    for playable: AbstractPlayable,
    playContext: PlayContext,
    isTrackDisplayed: Bool = false
  )
    -> CPListItem {
    let accessoryType: CPListItemAccessoryType = playable.isCached ? .cloud : .none
    let image = getImage(for: playable, isTrackDisplayed: isTrackDisplayed)
    if let artwork = playable.artwork, let accountInfo = artwork.account?.info {
      appDelegate.getMeta(accountInfo).artworkDownloadManager.download(object: artwork)
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

  func getImage(for playable: AbstractPlayable, isTrackDisplayed: Bool) -> UIImage {
    isTrackDisplayed ? UIImage.numberToImage(number: playable.track) :
      LibraryEntityImage.getImageToDisplayImmediately(
        libraryEntity: playable,
        themePreference: getPreference(activeAccountInfo).theme,
        artworkDisplayPreference: getPreference(activeAccountInfo).artworkDisplayPreference,
        useCache: false
      )
  }

  func triggerPlayRandomSongsItem(onlyCached: Bool) {
    let songs = appDelegate.storage.main.library
      .getRandomSongs(for: activeAccount, onlyCached: onlyCached || isOfflineMode)
    let playContext = PlayContext(
      name: "Random\(onlyCached ? " Cached" : "") Songs",
      playables: songs
    )
    appDelegate.player.playShuffled(context: playContext)
    displayNowPlaying {}
  }

  func triggerPlayRandomAlbums(onlyCached: Bool) {
    let randomAlbums = appDelegate.storage.main.library.getRandomAlbums(
      for: activeAccount,
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
    displayNowPlaying {}
  }
}
