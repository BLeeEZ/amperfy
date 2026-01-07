//
//  CarPlayCachedTabExtension.swift
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

extension LibraryDisplayType {
  fileprivate var isVisibleInCachedCarPlay: Bool {
    switch self {
    case .albums, .artists, .favoriteAlbums, .favoriteArtists, .favoriteSongs, .genres,
         .newestAlbums, .podcasts, .recentAlbums:
      return true
    case .directories, .downloads, .radios, .songs:
      return false
    case .playlists:
      return false // playlists have their own tab
    }
  }
}

extension CarPlaySceneDelegate {
  func createCachedSections() -> [CPListSection] {
    let librarySections = [
      createPlayRandomCachedSection(),
      createCachedLibraryNavigationTypeSection(),
    ]
    return librarySections
  }

  func createCachedLibraryNavigationTypeSection() -> CPListSection {
    var libDisplayItems = [CPListImageRowItemRowElement]()
    for libDisplayType in appDelegate.storage.settings.accounts.getSetting(activeAccountInfo).read
      .libraryDisplaySettings.inUse {
      guard libDisplayType.isVisibleInCachedCarPlay else { continue }
      let element = createLibraryTypeImageRowElement(type: libDisplayType)
      libDisplayItems.append(element)
    }
    let libDisplayRow = CPListImageRowItem(
      text: nil,
      elements: libDisplayItems,
      allowsMultipleLines: true
    )
    libDisplayRow.handler = { selectedRow, completion in completion() }
    libDisplayRow.listImageRowHandler = { [weak self] item, index, completion in
      guard let self,
            let selectedTitle = libDisplayItems[index].title,
            let displayType = LibraryDisplayType.createByDisplayName(name: selectedTitle)
      else { completion(); return }

      var sectionToDisplay: CPListTemplate?
      switch displayType {
      case .genres:
        sectionToDisplay = genresCachedSection
      case .podcasts:
        sectionToDisplay = podcastCachedSection
      case .artists:
        sectionToDisplay = artistsCachedSection
      case .albums:
        sectionToDisplay = albumsCachedSection
      case .favoriteSongs:
        sectionToDisplay = songsFavoriteCachedSection
      case .favoriteAlbums:
        sectionToDisplay = albumsFavoriteCachedSection
      case .favoriteArtists:
        sectionToDisplay = artistsFavoriteCachedSection
      case .newestAlbums:
        sectionToDisplay = albumsNewestCachedSection
      case .recentAlbums:
        sectionToDisplay = albumsRecentCachedSection
      case .radios:
        sectionToDisplay = radioSection
      case .directories, .downloads, .playlists, .songs:
        break // do nothing
      }
      guard let sectionToDisplay else { completion(); return }

      Task { @MainActor in
        let _ = try? await interfaceController?
          .pushTemplate(sectionToDisplay, animated: true)
      }
      completion()
    }
    let libDisplaySection = CPListSection(
      items: [libDisplayRow],
      header: "Cached Library",
      sectionIndexTitle: nil
    )
    return libDisplaySection
  }

  func createPlayRandomCachedSection() -> CPListSection {
    var playRandomItems = [CPListImageRowItemRowElement]()
    let playRandomAlbumsItem = CPListImageRowItemRowElement(
      image: UIImage.createArtwork(
        with: UIImage.album,
        iconSizeType: .small,
        theme: getPreference(activeAccountInfo).theme,
        lightDarkMode: traits.userInterfaceStyle.asModeType,
        switchColors: true
      ).carPlayImage(carTraitCollection: traits),
      title: Self.playRandomAlbumsTitle, subtitle: nil
    )
    playRandomItems.append(playRandomAlbumsItem)
    let playRandomSongsItem = CPListImageRowItemRowElement(
      image: UIImage.createArtwork(
        with: UIImage.musicalNotes,
        iconSizeType: .small,
        theme: getPreference(activeAccountInfo).theme,
        lightDarkMode: traits.userInterfaceStyle.asModeType,
        switchColors: true
      ).carPlayImage(carTraitCollection: traits),
      title: Self.playRandomSongsTitle, subtitle: nil
    )
    playRandomItems.append(playRandomSongsItem)

    let playRandomRow = CPListImageRowItem(
      text: nil,
      elements: playRandomItems,
      allowsMultipleLines: false
    )
    playRandomRow.handler = { selectedRow, completion in completion() }
    playRandomRow.listImageRowHandler = { [weak self] item, index, completion in
      guard let self else { completion(); return }
      Task { @MainActor in
        if playRandomItems[index].title == Self.playRandomAlbumsTitle {
          triggerPlayRandomAlbums(onlyCached: true)
        }
        if playRandomItems[index].title == Self.playRandomSongsTitle {
          triggerPlayRandomSongsItem(onlyCached: true)
        }
      }
      completion()
    }
    let playRandomSection = CPListSection(
      items: [playRandomRow],
      header: "Play Random Cached",
      sectionIndexTitle: nil
    )
    return playRandomSection
  }
}
