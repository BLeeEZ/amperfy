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

public enum LibraryDisplayType: Int, CaseIterable {
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
    //case recentSongs = 11 not used anymore
    case newestAlbums = 12

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
            return UIImage.clock
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
            return "toFavoriteSongs"
        case .favoriteAlbums:
            return "toFavoriteAlbums"
        case .favoriteArtists:
            return "toFavoriteArtists"
        case .newestAlbums:
            return "toNewestAlbums"
        }
    }
    
}

public struct LibraryDisplaySettings {
    public var combined: [[LibraryDisplayType]]

    public var inUse: [LibraryDisplayType] {
        return combined[0]
    }
    public var notUsed: [LibraryDisplayType] {
        return combined[1]
    }
    
    public init(inUse: [LibraryDisplayType]) {
        let notUsedSet = Set(LibraryDisplayType.allCases).subtracting(Set(inUse))
        combined = [ inUse, Array(notUsedSet) ]
    }
    
    public static var defaultSettings: LibraryDisplaySettings {
        return LibraryDisplaySettings(
            inUse: [
                .artists,
                .albums,
                .newestAlbums,
                .songs,
                .favoriteSongs,
                .directories,
                .playlists,
                .podcasts
            ])
    }
}
