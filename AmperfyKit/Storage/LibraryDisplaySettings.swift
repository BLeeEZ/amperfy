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

  public var segueName: String {
    switch self {
    case .artists:
      return "toArtists"
    case .albums:
      return "toAlbums"
    case .songs:
      return "toSongs"
    case .genres:
      return "toGenres"
    case .directories:
      return "toDirectories"
    case .playlists:
      return "toPlaylists"
    case .podcasts:
      return "toPodcasts"
    case .downloads:
      return "toDownloads"
    case .favoriteSongs:
      return "toSongs"
    case .favoriteAlbums:
      return "toAlbums"
    case .favoriteArtists:
      return "toArtists"
    case .newestAlbums:
      return "toAlbums"
    case .recentAlbums:
      return "toAlbums"
    case .radios:
      return "toRadios"
    }
  }
}

// MARK: - LibraryDisplaySettings

public struct LibraryDisplaySettings {
  public var combined: [[LibraryDisplayType]]

  public var inUse: [LibraryDisplayType] {
    combined[0]
  }

  public var notUsed: [LibraryDisplayType] {
    combined[1]
  }

  public func isVisible(libraryType: LibraryDisplayType) -> Bool {
    inUse.contains(where: { $0 == libraryType })
  }

  public init(inUse: [LibraryDisplayType]) {
    let notUsedSet = Set(LibraryDisplayType.allCases).subtracting(Set(inUse))
    self.combined = [inUse, Array(notUsedSet).sorted(by: { $0.rawValue < $1.rawValue })]
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
