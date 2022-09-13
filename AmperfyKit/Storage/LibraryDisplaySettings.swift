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
                .songs,
                .genres,
                .directories,
                .playlists,
                .podcasts
            ])
    }
}
