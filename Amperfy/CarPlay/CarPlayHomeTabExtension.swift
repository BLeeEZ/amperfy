//
//  CarPlayHomeTabExtension.swift
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

// The home tab shows one image row per home section, like Apple Music: at most
// homeImageRowMaxElements tiles that wrap into several lines. On iOS 27 CarPlayTemplateUIHost lays
// out single-line image rows (which scroll horizontally) endlessly as soon as they are updated,
// until the watchdog kills it and CarPlay ends for the app (#857). Rows that wrap and are created
// anew on every change don't trigger it. The section title opens the whole section as a list.
extension CarPlaySceneDelegate {
  static let homeImageRowMaxElements = 8

  /// The home announces every section on its own (several in a row at start and after a sync):
  /// collect them and rebuild the home tab once
  func updateHomeSections() {
    guard !isHomeUpdateScheduled else { return }
    isHomeUpdateScheduled = true
    Task { @MainActor [weak self] in
      try? await Task.sleep(for: .milliseconds(500))
      guard let self else { return }
      isHomeUpdateScheduled = false
      applyHomeSections()
    }
  }

  private func applyHomeSections() {
    guard let sharedHome else { return }
    let requestedData = sharedHome.data
    guard homeShownData != requestedData else { return }
    homeShownData = requestedData
    homeTab.updateSections([CPListSection(items: createHomeImageRows())])
    // a shown section list follows its section (e.g. after a refresh), but only if its own data
    // changed since it was built: a rebuild decodes all its images again
    if let shownList = homeSectionList, let template = shownList.template,
       shownList.data != requestedData[shownList.section],
       interfaceController?.templates.contains(template) == true {
      homeSectionList?.data = requestedData[shownList.section]
      template.updateSections(createHomeSectionListSections(section: shownList.section))
    }
  }

  /// Rows are created anew on every data change instead of changing their elements
  private func createHomeImageRows() -> [CPListImageRowItem] {
    guard let sharedHome else { return [] }
    homeImageRowArtworkTargets = [:]
    return sharedHome.orderedVisibleSections.map { section in
      let entries = (sharedHome.data[section] ?? []).prefix(Self.homeImageRowMaxElements)
      let containables = entries.map { $0.playableContainable }
      let elements = containables.map { createHomeImageRowElement(for: $0) }
      let row = CPListImageRowItem(
        text: section.title,
        elements: elements,
        allowsMultipleLines: true
      )
      // handler CB is called when user pressed the section title
      row.handler = { [weak self] _, completion in
        guard let self else { completion(); return }
        pushHomeSectionList(section: section, completion: completion)
      }
      // listImageRowHandler CB is called when user pressed on a image inside the row
      row.listImageRowHandler = { [weak self] _, index, completion in
        guard let self, index < containables.count else { completion(); return }
        Task { @MainActor in
          await selectHomeItem(containables[index])
          completion()
        }
      }
      return row
    }
  }

  private func createHomeImageRowElement(for containable: PlayableContainable)
    -> CPListImageRowItemRowElement {
    let element = CPListImageRowItemRowElement(
      image: getHomeImage(for: containable),
      title: containable.name,
      subtitle: containable.subtitle
    )
    if let entity = containable as? AbstractLibraryEntity, let artwork = entity.artwork {
      downloadHomeArtwork(artwork)
      // row elements have no userInfo: refreshHomeImageRowArtwork finds them by artwork
      homeImageRowArtworkTargets[artwork.uniqueID, default: []]
        .append(HomeImageRowArtworkTarget(element: element, containable: containable))
    }
    return element
  }

  /// Sets the image of the home row elements that show the downloaded artwork
  func refreshHomeImageRowArtwork(downloadID: String) {
    guard let targets = homeImageRowArtworkTargets[downloadID] else { return }
    for target in targets {
      target.element.image = getHomeImage(for: target.containable)
    }
  }

  private func getHomeImage(for containable: PlayableContainable) -> UIImage {
    let theme = getPreference(activeAccountInfo).theme
    if let entity = containable as? AbstractLibraryEntity {
      return LibraryEntityImage.getImageToDisplayImmediately(
        libraryEntity: entity,
        themePreference: theme,
        artworkDisplayPreference: getPreference(activeAccountInfo).artworkDisplayPreference,
        useCache: false,
        maxPixelSize: listImagePixelSize
      ).carPlayImage(carTraitCollection: traits)
    }
    return UIImage.getGeneratedArtwork(
      theme: theme,
      artworkType: containable.getArtworkCollection(theme: theme).defaultArtworkType
    )
  }

  /// Requests every artwork only once per CarPlay session: the rows are rebuilt on every change
  private func downloadHomeArtwork(_ artwork: Artwork) {
    guard homeRequestedArtworkIDs.insert(artwork.uniqueID).inserted,
          let accountInfo = artwork.account?.info else { return }
    appDelegate.getMeta(accountInfo).artworkDownloadManager.download(object: artwork)
  }

  private func pushHomeSectionList(section: HomeSection, completion: @escaping () -> ()) {
    let template = CPListTemplate(
      title: section.title,
      sections: createHomeSectionListSections(section: section)
    )
    homeSectionList = HomeSectionList(
      template: template,
      section: section,
      data: sharedHome?.data[section]
    )
    Task { @MainActor in
      let _ = try? await interfaceController?.pushTemplate(template, animated: true)
      completion()
    }
  }

  private func createHomeSectionListSections(section: HomeSection) -> [CPListSection] {
    guard let sharedHome else { return [] }
    var items = [CPListItem]()
    if section.isRandomSection {
      items.append(createHomeRefreshItem(section: section))
    }
    let homeItems = (sharedHome.data[section] ?? [])
      .prefix(CPListTemplate.maximumItemCount - items.count)
    items.append(contentsOf: homeItems.map { createHomeListItem(for: $0.playableContainable) })
    return [CPListSection(items: items)]
  }

  private func createHomeRefreshItem(section: HomeSection) -> CPListItem {
    let image = UIImage.createArtwork(
      with: UIImage.shuffle,
      iconSizeType: .small,
      theme: getPreference(activeAccountInfo).theme,
      lightDarkMode: traits.userInterfaceStyle.asModeType,
      switchColors: true
    ).carPlayImage(carTraitCollection: traits)
    let item = CPListItem(text: "Refresh", detailText: nil, image: image)
    item.handler = { [weak self] _, completion in
      guard let self, let sharedHome else { completion(); return }
      Task { @MainActor in
        switch section {
        case .randomAlbums:
          await sharedHome.updateRandomAlbums(isOfflineMode: isOfflineMode)
        case .randomArtists:
          await sharedHome.updateRandomArtists(isOfflineMode: isOfflineMode)
        case .randomGenres:
          await sharedHome.updateRandomGenres()
        case .randomSongs:
          await sharedHome.updateRandomSongs(isOfflineMode: isOfflineMode)
        case .lastTimePlayedPlaylists, .newestAlbums, .newestPodcastEpisodes, .podcasts, .radios,
             .recentlyPlayedAlbums:
          // only random sections have a refresh
          break
        }
        // the new content arrives via updateHomeSections
        completion()
      }
    }
    return item
  }

  private func createHomeListItem(for containable: PlayableContainable) -> CPListItem {
    let item = CPListItem(
      text: containable.name,
      detailText: containable.subtitle,
      image: getHomeImage(for: containable),
      accessoryImage: nil,
      accessoryType: containable is Album || containable is Playlist ? .disclosureIndicator : .none
    )
    if let entity = containable as? AbstractLibraryEntity, let artwork = entity.artwork {
      downloadHomeArtwork(artwork)
    }
    // lets downloadFinishedSuccessful refresh the image once the artwork is downloaded
    if let entity = containable as? AbstractLibraryEntity, let artwork = entity.artwork,
       let ownerType = homeArtworkOwnerType(of: entity) {
      item.userInfo = [
        CarPlayListUserInfoKeys.artworkDownloadID.rawValue: artwork.uniqueID,
        CarPlayListUserInfoKeys.artworkOwnerObjectID.rawValue: entity.objectID,
        CarPlayListUserInfoKeys.artworkOwnerType.rawValue: ownerType,
      ]
    }
    item.handler = { [weak self] _, completion in
      guard let self else { completion(); return }
      Task { @MainActor in
        await selectHomeItem(containable)
        completion()
      }
    }
    return item
  }

  /// The owner types downloadFinishedSuccessful can refresh
  private func homeArtworkOwnerType(of entity: AbstractLibraryEntity) -> ArtworkType? {
    switch entity {
    case is Song: return .song
    case is Album: return .album
    case is Artist: return .artist
    case is Podcast: return .podcast
    case is PodcastEpisode: return .podcastEpisode
    case is Radio: return .radio
    case is Genre: return .genre
    default: return nil
    }
  }

  private func selectHomeItem(_ containable: PlayableContainable) async {
    if !isOfflineMode {
      do {
        try await containable.fetch(
          storage: appDelegate.storage,
          librarySyncer: appDelegate.getMeta(activeAccountInfo).librarySyncer,
          playableDownloadManager: appDelegate.getMeta(activeAccountInfo)
            .playableDownloadManager
        )
      } catch {
        // ignore online fetch in CarPlay
      }
    }
    if let album = containable as? Album {
      let albumTemplate = createAlbumSongListTemplate(for: album, onlyCached: isOfflineMode)
      let _ = try? await interfaceController?.pushTemplate(albumTemplate, animated: true)
    } else if let playlist = containable as? Playlist {
      let playlistDetailTemplate = CPListTemplate(title: playlist.name, sections: [
        CPListSection(items: [CPListTemplateItem]()),
      ])
      playlistDetailSection = playlistDetailTemplate
      createPlaylistDetailFetchController(playlist: playlist)
      let _ = try? await interfaceController?.pushTemplate(playlistDetailTemplate, animated: true)
    } else {
      appDelegate.player.play(context: PlayContext(containable: containable))
      await withCheckedContinuation { continuation in
        displayNowPlaying {
          continuation.resume()
        }
      }
    }
  }
}
