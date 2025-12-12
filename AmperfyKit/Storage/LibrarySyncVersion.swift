//
//  LibrarySyncVersion.swift
//  AmperfyKit
//
//  Created by Maximilian Bauer on 08.05.21.
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

import Foundation

public enum LibrarySyncVersion: Int, Comparable, CustomStringConvertible, Sendable, Codable {
  case v6 = 0
  case v7 = 1 // Genres added
  case v8 = 2 // Directories added
  case v9 = 3 // Artwork ids added
  case v10 = 4 // Podcasts added
  case v11 = 5 // isRecentAdded added to AbstractPlayable
  case v12 = 6 // alphabeticSectionInitial added to AbstractPlayable
  case v13 = 7 // duration added to AbstractPlayable (CoreDataMigrationVersion v30)
  case v14 =
    8 // duration/remoteDuration added to Artist,Album,Playlist (CoreDataMigrationVersion v31)
  case v15 = 9 // remoteSongCount added to Playlist (CoreDataMigrationVersion v32)
  case v16 = 10 // artworkItems added to Playlist (CoreDataMigrationVersion v33)
  case v17 =
    11 // extract artwork binary data from core data to FileManager (CoreDataMigrationVersion v37)
  case v18 =
    12 // core date performance improvement: write count valus as attribtes to avoid fetch all releationships (CoreDataMigrationVersion v41)
  case v19 = 13 // Playlist items are as NSOrderedSet
  case v20 = 14 // Streaming transcoding format preference is split in wifi and celluar
  case v21 = 15 // Account support

  public var description: String {
    switch self {
    case .v6: return "v6"
    case .v7: return "v7"
    case .v8: return "v8"
    case .v9: return "v9"
    case .v10: return "v10"
    case .v11: return "v11"
    case .v12: return "v12"
    case .v13: return "v13"
    case .v14: return "v14"
    case .v15: return "v15"
    case .v16: return "v16"
    case .v17: return "v17"
    case .v18: return "v18"
    case .v19: return "v19"
    case .v20: return "v20"
    case .v21: return "v21"
    }
  }

  public var isNewestVersion: Bool {
    self == Self.newestVersion
  }

  public static let newestVersion: LibrarySyncVersion = .v21
  public static let defaultValue: LibrarySyncVersion = .v6

  public static func < (lhs: LibrarySyncVersion, rhs: LibrarySyncVersion) -> Bool {
    lhs.rawValue < rhs.rawValue
  }
}
