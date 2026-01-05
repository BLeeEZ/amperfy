//
//  PlayableContainable.swift
//  AmperfyKit
//
//  Created by Maximilian Bauer on 29.06.21.
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

// MARK: - DetailType

public enum DetailType {
  case short
  case long
  case noCountInfo
}

// MARK: - DetailInfoType

public struct DetailInfoType {
  public var type: DetailType
  public var isShowDetailedInfo: Bool
  public var isShowAlbumDuration: Bool
  public var isShowArtistDuration: Bool
  public var artistFilterSetting: ArtistCategoryFilter

  public init(type: DetailType, settings: AmperfySettings) {
    self.type = type
    self.isShowDetailedInfo = settings.user.isShowDetailedInfo
    self.isShowAlbumDuration = settings.user.isShowAlbumDuration
    self.isShowArtistDuration = settings.user.isShowArtistDuration
    self.artistFilterSetting = settings.user.artistsFilterSetting
  }
}

// MARK: - PlayableContainerBaseType

public enum PlayableContainerBaseType: Int, Codable {
  case song = 0
  case podcastEpisode
  case album
  case artist
  case genre
  case playlist
  case podcast
  case directory
  case radio

  public var displayString: String {
    switch self {
    case .song: return "Song"
    case .podcastEpisode: return "Podcast Episode"
    case .album: return "Album"
    case .artist: return "Artist"
    case .genre: return "Genre"
    case .playlist: return "Playlist"
    case .podcast: return "Podcast"
    case .directory: return "Directory"
    case .radio: return "Radio"
    }
  }

  public var image: AmperfyImage {
    switch self {
    case .song: return .musicalNotes
    case .podcastEpisode: return .podcastEpisode
    case .album: return .album
    case .artist: return .artist
    case .genre: return .genre
    case .playlist: return .playlist
    case .podcast: return .podcast
    case .directory: return .folder
    case .radio: return .radio
    }
  }
}

// MARK: - PlayableContainerIdentifier

public struct PlayableContainerIdentifier: Codable {
  public var type: PlayableContainerBaseType?
  public var objectID: String?
}

// MARK: - PlayableContainable

public protocol PlayableContainable {
  var id: String { get }
  var name: String { get }
  var subtitle: String? { get }
  var subsubtitle: String? { get }
  func infoDetails(for api: ServerApiType?, details: DetailInfoType) -> [String]
  func info(for api: ServerApiType?, details: DetailInfoType) -> String
  var playables: [AbstractPlayable] { get }
  var playContextType: PlayerMode { get }
  var account: Account? { get }
  var isRateable: Bool { get }
  var isDownloadAvailable: Bool { get }
  @MainActor
  func getArtworkCollection(theme: ThemePreference) -> ArtworkCollection
  @MainActor
  func cachePlayables(downloadManager: DownloadManageable)
  @MainActor
  func fetchFromServer(
    storage: PersistentStorage,
    librarySyncer: LibrarySyncer,
    playableDownloadManager: DownloadManageable
  ) async throws
  var isFavoritable: Bool { get }
  var isFavorite: Bool { get }
  @MainActor
  func remoteToggleFavorite(syncer: LibrarySyncer) async throws
  func playedViaContext()
  var containerIdentifier: PlayableContainerIdentifier { get }
}

extension PlayableContainable {
  @MainActor
  public func cachePlayables(downloadManager: DownloadManageable) {
    for playable in playables {
      if !playable.isCached {
        downloadManager.download(object: playable)
      }
    }
  }

  public func info(for api: ServerApiType?, details: DetailInfoType) -> String {
    infoDetails(for: api, details: details).joined(separator: " \(CommonString.oneMiddleDot) ")
  }

  @MainActor
  public func fetch(
    storage: PersistentStorage,
    librarySyncer: LibrarySyncer,
    playableDownloadManager: DownloadManageable
  ) async throws {
    guard storage.settings.user.isOnlineMode else { return }
    try await fetchFromServer(
      storage: storage,
      librarySyncer: librarySyncer,
      playableDownloadManager: playableDownloadManager
    )
  }

  public var isRateable: Bool { false }
  public var isFavoritable: Bool { false }
  public var isFavorite: Bool { false }
  public var isDownloadAvailable: Bool { true }
}
