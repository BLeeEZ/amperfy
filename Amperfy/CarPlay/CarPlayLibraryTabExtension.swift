//
//  CarPlayLibraryTabExtension.swift
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
  fileprivate var isVisibleInCarPlay: Bool {
    switch self {
    case .albums, .artists, .favoriteAlbums, .favoriteArtists, .favoriteSongs, .genres,
         .newestAlbums,
         .podcasts,
         .radios, .recentAlbums:
      return true
    case .directories, .downloads, .songs:
      return false
    case .playlists:
      return false // playlists have their own tab
    }
  }
}

extension CarPlaySceneDelegate {
  static let switchAccountTitle = "Switch Account"
  static let continuePlaybackMusicTitle = "Continue Music"
  static let continuePlaybackPodcastTitle = "Continue Podcasts"
  static let playRandomAlbumsTitle = "Albums"
  static let playRandomSongsTitle = "Songs"

  func createLibrarySections() -> [CPListSection] {
    let librarySections = [
      createQuickActionsSection(),
      createPlayRandomSection(),
      createLibraryNavigationTypeSection(),
    ].compactMap { $0 }

    return librarySections
  }

  func createLibraryTypeImageRowElement(type: LibraryDisplayType) -> CPListImageRowItemRowElement {
    let baseImage = type.image
    let element = CPListImageRowItemRowElement(
      image: UIImage.createArtwork(
        with: baseImage,
        iconSizeType: .small,
        theme: getPreference(activeAccountInfo).theme,
        lightDarkMode: traits.userInterfaceStyle.asModeType,
        switchColors: true
      ).carPlayImage(carTraitCollection: traits),
      title: type.displayName, subtitle: nil
    )
    return element
  }

  func createLibraryNavigationTypeSection() -> CPListSection {
    var libDisplayItems = [CPListImageRowItemRowElement]()
    for libDisplayType in appDelegate.storage.settings.accounts.getSetting(activeAccountInfo).read
      .libraryDisplaySettings.inUse {
      guard libDisplayType.isVisibleInCarPlay else { continue }
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
        sectionToDisplay = genresSection
      case .artists:
        sectionToDisplay = artistsSection
      case .albums:
        sectionToDisplay = albumsSection
      case .podcasts:
        sectionToDisplay = podcastSection
      case .favoriteSongs:
        sectionToDisplay = songsFavoriteSection
      case .favoriteAlbums:
        sectionToDisplay = albumsFavoriteSection
      case .favoriteArtists:
        sectionToDisplay = artistsFavoriteSection
      case .newestAlbums:
        sectionToDisplay = albumsNewestSection
      case .recentAlbums:
        sectionToDisplay = albumsRecentSection
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
      header: "Library",
      sectionIndexTitle: nil
    )
    return libDisplaySection
  }

  func createPlayRandomSection() -> CPListSection {
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
          triggerPlayRandomAlbums(onlyCached: false)
        }
        if playRandomItems[index].title == Self.playRandomSongsTitle {
          triggerPlayRandomSongsItem(onlyCached: false)
        }
      }
      completion()
    }
    let playRandomSection = CPListSection(
      items: [playRandomRow],
      header: "Play Random",
      sectionIndexTitle: nil
    )
    return playRandomSection
  }

  func createQuickActionsSection() -> CPListSection? {
    var quickActionItems = [CPListImageRowItemRowElement]()
    if appDelegate.player.musicItemCount > 0 {
      let item = CPListImageRowItemRowElement(
        image: UIImage.createArtwork(
          with: UIImage.musicalNotes,
          iconSizeType: .small,
          theme: getPreference(activeAccountInfo).theme,
          lightDarkMode: traits.userInterfaceStyle.asModeType,
          switchColors: true
        ).carPlayImage(carTraitCollection: traits),
        title: Self.continuePlaybackMusicTitle, subtitle: nil
      )
      quickActionItems.append(item)
    }
    if appDelegate.player.podcastItemCount > 0 {
      let item = CPListImageRowItemRowElement(
        image: UIImage.createArtwork(
          with: UIImage.podcast,
          iconSizeType: .small,
          theme: getPreference(activeAccountInfo).theme,
          lightDarkMode: traits.userInterfaceStyle.asModeType,
          switchColors: true
        ).carPlayImage(carTraitCollection: traits),
        title: Self.continuePlaybackPodcastTitle, subtitle: nil
      )
      quickActionItems.append(item)
    }
    if appDelegate.storage.settings.accounts.allAccounts.count > 1 {
      let switchAccountItem = CPListImageRowItemRowElement(
        image: UIImage.createArtwork(
          with: UIImage.userPerson,
          iconSizeType: .small,
          theme: getPreference(activeAccountInfo).theme,
          lightDarkMode: traits.userInterfaceStyle.asModeType,
          switchColors: true
        ).carPlayImage(carTraitCollection: traits),
        title: Self.switchAccountTitle, subtitle: nil
      )
      quickActionItems.append(switchAccountItem)
    }

    guard !quickActionItems.isEmpty else { return nil }

    let quickActionsRow = CPListImageRowItem(
      text: nil,
      elements: quickActionItems,
      allowsMultipleLines: false
    )
    quickActionsRow.handler = { selectedRow, completion in completion() }
    quickActionsRow.listImageRowHandler = { [weak self] item, index, completion in
      guard let self else { completion(); return }

      Task { @MainActor in
        if quickActionItems[index].title == Self.switchAccountTitle {
          let _ = try? await interfaceController?
            .pushTemplate(accountSection, animated: true)
        }
        if quickActionItems[index].title == Self.continuePlaybackMusicTitle ||
          quickActionItems[index].title == Self.continuePlaybackPodcastTitle {
          if quickActionItems[index].title == Self.continuePlaybackMusicTitle,
             appDelegate.player.playerMode != .music {
            appDelegate.player.setPlayerMode(.music)
          } else if quickActionItems[index].title == Self.continuePlaybackPodcastTitle,
                    appDelegate.player.playerMode != .podcast {
            appDelegate.player.setPlayerMode(.podcast)
          }
          appDelegate.player.play()
          displayNowPlaying {}
        }
      }

      completion()
    }
    let quickActionsSection = CPListSection(
      items: [quickActionsRow],
      header: "Quick Actions",
      sectionIndexTitle: nil
    )
    return quickActionsSection
  }

  func createAccountsSections() -> [CPListSection] {
    let accountInfos = appDelegate.storage.settings.accounts.allAccounts
    var items: [CPListItem] = []
    for accountInfo in accountInfos {
      let name = appDelegate.storage.settings.accounts.getSetting(accountInfo).read
        .loginCredentials?.username ?? ""
      let displayServerUrl = appDelegate.storage.settings.accounts.getSetting(accountInfo).read
        .loginCredentials?.displayServerUrl ?? ""
      let isActive = (accountInfo == activeAccountInfo)
      let item = CPListItem(
        text: name,
        detailText: displayServerUrl,
        image: UIImage.createArtwork(
          with: isActive ? UIImage.userCircleCheckmark : UIImage.userCircle(),
          iconSizeType: .big,
          theme: getPreference(accountInfo).theme,
          lightDarkMode: traits.userInterfaceStyle.asModeType,
          switchColors: true
        ).carPlayImage(carTraitCollection: traits),
        accessoryImage: nil,
        accessoryType: isActive ? .none : .disclosureIndicator
      )
      item.handler = { [weak self] _, completion in
        guard let self = self,
              appDelegate.storage.settings.accounts.active != accountInfo
        else { completion(); return }
        appDelegate.switchAccount(accountInfo: accountInfo)
        accountSection.updateSections(createAccountsSections())
        completion()
      }
      items.append(item)
    }
    return [CPListSection(items: items)]
  }
}
