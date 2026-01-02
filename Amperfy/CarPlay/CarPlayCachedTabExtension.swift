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

extension CarPlaySceneDelegate {
  
  func createCachedSections() -> [CPListSection] {
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

    let librarySections = [
      playRandomSection,
      CPListSection(items: [
        createLibraryItem(
          text: "Favorites",
          icon: UIImage.heartFill,
          sectionToDisplay: songsFavoriteCachedSection
        ),
      ], header: "Cached Songs", sectionIndexTitle: nil),
      CPListSection(items: [
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
}
