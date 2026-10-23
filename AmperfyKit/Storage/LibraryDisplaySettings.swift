//
//  LibraryDisplaySettings.swift
//  Amperfy
//
//  Created by Maximilian Bauer on 14.09.22.
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

import Foundation
import UIKit

// MARK: - LibraryDisplayType

@MainActor
public enum LibraryDisplayType: Int, CaseIterable, Sendable {
  case artists = 0
  case albums = 1
  case songs = 2
  case genres = 3
  case directories = 4
  case playlists = 5
  case podcasts = 6
  case downloads = 7
  case favoriteSongs = 8
  case favoriteAlbums = 9
  case favoriteArtists = 10
  // case recentSongs = 11 not used anymore
  case newestAlbums = 12
  case recentAlbums = 13
  case radios = 14

  public static func createByDisplayName(name: String) -> LibraryDisplayType? {
    .allCases.first {
      $0.displayName == name
    }
  }

  public var displayName: String {
    switch self {
    case .artists:
      return "Artists"
    case .albums:
      return "Albums"
    case .songs:
      return "Songs"
    case .genres:
      return "Genres"
    case .directories:
      return "Directories"
    case .playlists:
      return "Playlists"
    case .podcasts:
      return "Podcasts"
    case .downloads:
      return "Downloads"
    case .favoriteSongs:
      return "Favorite Songs"
    case .favoriteAlbums:
      return "Favorite Albums"
    case .favoriteArtists:
      return "Favorite Artists"
    case .newestAlbums:
      return "Newest Albums"
    case .recentAlbums:
      return "Recently Played Albums"
    case .radios:
      return "Radios"
    }
  }

  public var image: UIImage {
    switch self {
    case .artists:
      return UIImage.artist
    case .albums:
      return UIImage.album
    case .songs:
      return UIImage.musicalNotes
    case .genres:
      return UIImage.genre
    case .directories:
      return UIImage.folder
    case .playlists:
      return UIImage.playlist
    case .podcasts:
      return UIImage.podcast
    case .downloads:
      return UIImage.download
    case .favoriteSongs:
      return UIImage.heartFill
    case .favoriteAlbums:
      return UIImage.heartFill
    case .favoriteArtists:
      return UIImage.heartFill
    case .newestAlbums:
      return UIImage.albumNewest
    case .recentAlbums:
      return UIImage.albumRecent
    case .radios:
      return UIImage.radio
    }
  }
}

// MARK: - LibraryDisplaySettings

public struct LibraryDisplaySettings: Sendable, Codable {
  /// all library types (in use and not used) in the order arranged by the user
  public private(set) var order: [LibraryDisplayType]
  private var inUseTypes: Set<LibraryDisplayType>

  public var inUse: [LibraryDisplayType] {
    order.filter { inUseTypes.contains($0) }
  }

  public var notUsed: [LibraryDisplayType] {
    order.filter { !inUseTypes.contains($0) }
  }

  private enum CodingKeys: String, CodingKey {
    case combined
    case order
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    // combined: [inUse, notUsed], the stored format before the order was persisted
    let encodedCombined = [inUse, notUsed].map { $0.map { $0.rawValue } }
    try container.encode(encodedCombined, forKey: .combined)
    try container.encode(order.map { $0.rawValue }, forKey: .order)
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    let decodedCombined = try container.decode([[Int]].self, forKey: .combined)
    // not present in settings stored before the order was persisted
    let decodedOrder = try container.decodeIfPresent([Int].self, forKey: .order)

    let mapped: [[LibraryDisplayType]] = decodedCombined.map { group in
      group.compactMap { LibraryDisplayType(rawValue: $0) }
    }

    if mapped.count == 2 {
      let order = decodedOrder?.compactMap { LibraryDisplayType(rawValue: $0) } ?? mapped[0] +
        mapped[1]
      self = LibraryDisplaySettings(order: order, inUse: Set(mapped[0]))
    } else if let first = mapped.first {
      // If only one group present, treat it as inUse and compute notUsed
      self = LibraryDisplaySettings(inUse: first)
    } else {
      // Fallback to defaults if decoding produced no valid entries
      self = LibraryDisplaySettings(inUse: [])
    }
  }

  public func isVisible(libraryType: LibraryDisplayType) -> Bool {
    inUseTypes.contains(libraryType)
  }

  /// The types not in use follow the ones in use, sorted by their raw value.
  public init(inUse: [LibraryDisplayType]) {
    let notUsed = Set(LibraryDisplayType.allCases).subtracting(Set(inUse))
      .sorted(by: { $0.rawValue < $1.rawValue })
    self.init(order: inUse + notUsed, inUse: Set(inUse))
  }

  /// Keeps the order arranged by the user; types missing in `order` (e.g. new ones) are appended.
  public init(order: [LibraryDisplayType], inUse: Set<LibraryDisplayType>) {
    self.order = order.completingOrder(with: LibraryDisplayType.allCases)
    self.inUseTypes = inUse
  }

  public static var defaultSettings: LibraryDisplaySettings {
    LibraryDisplaySettings(
      inUse: [
        .artists,
        .albums,
        .newestAlbums,
        .recentAlbums,
        .songs,
        .favoriteSongs,
        .directories,
        .playlists,
        .podcasts,
        .radios,
      ]
    )
  }

  public static var addToPlaylistSettings: LibraryDisplaySettings {
    LibraryDisplaySettings(
      inUse: [
        .genres,
        .artists,
        .favoriteArtists,
        .albums,
        .favoriteAlbums,
        .newestAlbums,
        .recentAlbums,
        .songs,
        .favoriteSongs,
        .directories,
        .playlists,
      ]
    )
  }
}
