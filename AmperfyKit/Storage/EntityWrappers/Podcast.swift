//
//  Podcast.swift
//  AmperfyKit
//
//  Created by Maximilian Bauer on 25.06.21.
//  Copyright (c) 2021 Maximilian Bauer. All rights reserved.
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

import CoreData
import Foundation
import UIKit

// MARK: - Podcast

public class Podcast: AbstractLibraryEntity {
  public let managedObject: PodcastMO

  public init(managedObject: PodcastMO) {
    self.managedObject = managedObject
    super.init(managedObject: managedObject)
  }

  public var titleRawParsed: String = "" // used by parser a temporary buffer
  public var depictionRawParsed: String = "" // used by parser a temporary buffer

  public var identifier: String {
    title
  }

  public var title: String {
    get { managedObject.title ?? "Unknown Podcast" }
    set {
      if managedObject.title != newValue {
        managedObject.title = newValue
        updateAlphabeticSectionInitial(section: newValue)
      }
    }
  }

  public var depiction: String {
    get { managedObject.depiction ?? "" }
    set { if managedObject.depiction != newValue { managedObject.depiction = newValue } }
  }

  public var isCached: Bool {
    get { managedObject.isCached }
    set {
      if managedObject.isCached != newValue {
        managedObject.isCached = newValue
      }
    }
  }

  public var episodeCount: Int {
    Int(managedObject.episodeCount)
  }

  public var episodes: [PodcastEpisode] {
    guard let episodesSet = managedObject.episodes,
          let episodesMO = episodesSet.array as? [PodcastEpisodeMO]
    else { return [PodcastEpisode]() }
    return episodesMO.compactMap { PodcastEpisode(managedObject: $0) }.sortByPublishDate()
  }

  @MainActor
  override public func getDefaultArtworkType() -> ArtworkType {
    .podcast
  }
}

// MARK: PlayableContainable

extension Podcast: PlayableContainable {
  public var name: String { title }
  public var subtitle: String? { nil }
  public var subsubtitle: String? { nil }
  public func infoDetails(for api: ServerApiType?, details: DetailInfoType) -> [String] {
    var infoContent = [String]()
    if details.type != .noCountInfo {
      if episodeCount == 1 {
        infoContent.append("1 Episode")
      } else if episodeCount > 1 {
        infoContent.append("\(episodeCount) Episodes")
      }
    }
    if details.type == .long || details.type == .noCountInfo {
      if isCached {
        infoContent.append("Cached")
      }
      if details.isShowDetailedInfo {
        infoContent.append("ID: \(!id.isEmpty ? id : "-")")
      }
    }
    return infoContent
  }

  public var playables: [AbstractPlayable] {
    episodes.filter { $0.isAvailableToUser() }
  }

  public var playContextType: PlayerMode { .podcast }
  @MainActor
  public func fetchFromServer(
    storage: PersistentStorage,
    librarySyncer: LibrarySyncer,
    playableDownloadManager: DownloadManageable
  ) async throws {
    try await librarySyncer.sync(podcast: self)
  }

  @MainActor
  public func remoteToggleFavorite(syncer: LibrarySyncer) async throws {
    throw BackendError.notSupported
  }

  @MainActor
  public func getArtworkCollection(theme: ThemePreference) -> ArtworkCollection {
    ArtworkCollection(defaultArtworkType: getDefaultArtworkType(), singleImageEntity: self)
  }

  public var containerIdentifier: PlayableContainerIdentifier { PlayableContainerIdentifier(
    type: .podcast,
    objectID: managedObject.objectID.uriRepresentation().absoluteString
  ) }
}
