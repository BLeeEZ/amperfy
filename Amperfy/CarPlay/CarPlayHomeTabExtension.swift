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

extension CarPlaySceneDelegate {
  func updateHomeSections() {
    guard let sharedHome else { return }
    let alreadyCreatedData = homeRowData
    let requestedData = sharedHome.data
    guard alreadyCreatedData !=
      requestedData else {
      return
    }
    let homeRows = createHomeImageRows()
    let homeSection = CPListSection(items: homeRows, header: nil, sectionIndexTitle: nil)
    homeTab.updateSections([homeSection])
  }

  func createHomeImageRows() -> [CPListImageRowItem] {
    guard let sharedHome else { return [] }
    var imageRows = [CPListImageRowItem]()
    for section in sharedHome.orderedVisibleSections {
      if let row = homeImageRows[section] {
        let alreadyCreatedData = homeRowData[section]
        let requestedData = sharedHome.data[section]
        if alreadyCreatedData !=
          requestedData {
          let imageRowElements = createHomeRowImageElements(section: section, isDetail: false)
          row.elements = imageRowElements
        }
        imageRows.append(row)
      } else if let row = createHomeRow(section: section, isDetailTemplate: false) {
        homeImageRows[section] = row
        imageRows.append(row)
      }
    }
    return imageRows
  }

  func createHomeRow(section: HomeSection, isDetailTemplate: Bool) -> CPListImageRowItem? {
    guard let sharedHome else { return nil }
    let alreadyCreatedData = homeRowData[section]
    let requestedData = sharedHome.data[section]
    if !isDetailTemplate,
       alreadyCreatedData ==
       requestedData {
      return homeImageRows[section]
    }

    let imageRowElements = createHomeRowImageElements(section: section, isDetail: isDetailTemplate)
    let isRandomSection = section.isRandomSection

    var title: String?
    if !isDetailTemplate {
      title = section.title
    } else if isRandomSection {
      title = "Refresh"
    }

    let row = CPListImageRowItem(
      text: title,
      elements: imageRowElements,
      allowsMultipleLines: isDetailTemplate
    )
    // handler CB is called when user pressed the section title
    row.handler = { [weak self] selectedRow, completion in
      guard let self else { completion(); return }
      if !isDetailTemplate {
        Task { @MainActor in
          let detailSectionRow = createHomeRow(section: section, isDetailTemplate: true)
          let detailListTemplate = CPListTemplate(title: section.title, sections: [
            CPListSection(items: detailSectionRow != nil ? [detailSectionRow!] : []),
          ])
          let _ = try? await interfaceController?
            .pushTemplate(detailListTemplate, animated: true)
          completion()
        }
      } else if isRandomSection {
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
            // do nothing
            break
          }
          if section.isRandomSection {
            row.elements = createHomeRowImageElements(section: section, isDetail: true)
          }
          completion()
        }
      } else {
        completion()
      }
    }
    // listImageRowHandler CB is called when user pressed on a image inside the row
    row.listImageRowHandler = { [weak self] item, index, completion in
      guard let self,
            let selectedPlayable = sharedHome.data[section]?[index].playableContainable
      else { completion(); return }
      Task { @MainActor in
        if !isOfflineMode {
          do {
            try await selectedPlayable.fetch(
              storage: self.appDelegate.storage,
              librarySyncer: self.appDelegate.getMeta(activeAccountInfo).librarySyncer,
              playableDownloadManager: self.appDelegate.getMeta(activeAccountInfo)
                .playableDownloadManager
            )
          } catch {
            // ignore online fetch in CarPlay
          }
        }
        self.appDelegate.player.play(context: PlayContext(containable: selectedPlayable))
        displayNowPlaying {
          completion()
        }
      }
    }
    return row
  }

  func createHomeRowImageElements(
    section: HomeSection,
    isDetail: Bool
  )
    -> [CPListImageRowItemRowElement] {
    guard let sharedHome else { return [] }

    let alreadyCreatedData = homeRowData[section]
    let requestedData = sharedHome.data[section]
    if !isDetail,
       alreadyCreatedData ==
       requestedData {
      return homeImageRows[section]?.elements as? [CPListImageRowItemRowElement] ?? []
    }
    if !isDetail {
      homeRowData[section] = requestedData
    } else {
      for var container in homeArtworkUpdate {
        container.value.detailRow.removeAll()
      }
    }

    var imageRowElements = [CPListImageRowItemRowElement]()
    let items = requestedData ?? []
    for item in items {
      var image: UIImage?
      var artwork: Artwork?
      var entity: AbstractLibraryEntity?
      if let libEntity = item.playableContainable as? AbstractLibraryEntity {
        image = LibraryEntityImage.getImageToDisplayImmediately(
          libraryEntity: libEntity,
          themePreference: getPreference(activeAccountInfo).theme,
          artworkDisplayPreference: getPreference(activeAccountInfo).artworkDisplayPreference,
          useCache: false
        )
        if let entityArtwork = libEntity.artwork, let accountInfo = entityArtwork.account?.info {
          artwork = entityArtwork
          entity = libEntity
          // trigger download only once
          if homeArtworkUpdate[entityArtwork.uniqueID] == nil {
            appDelegate.getMeta(accountInfo).artworkDownloadManager.download(object: entityArtwork)
          }
        }
      }
      let displayImage = image?.carPlayImage(carTraitCollection: traits) ?? UIImage
        .getGeneratedArtwork(
          theme: getPreference(activeAccountInfo).theme,
          artworkType: item.playableContainable
            .getArtworkCollection(theme: getPreference(activeAccountInfo).theme).defaultArtworkType
        )

      let element = CPListImageRowItemRowElement(
        image: displayImage,
        title: item.playableContainable.name,
        subtitle: item.playableContainable.subtitle
      )
      if let artwork, let entity {
        if homeArtworkUpdate[artwork.uniqueID] == nil {
          homeArtworkUpdate[artwork.uniqueID] = EntityImageRowContainer(
            entity: entity,
            item: item,
            homeRow: isDetail ? [] : [element],
            detailRow: isDetail ? [element] : []
          )
        } else if isDetail {
          homeArtworkUpdate[artwork.uniqueID]?.detailRow.append(element)
        } else {
          homeArtworkUpdate[artwork.uniqueID]?.homeRow.append(element)
        }
      }
      imageRowElements.append(element)
    }
    return imageRowElements
  }
}
