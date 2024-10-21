//
//  Strings.swift
//  Amperfy
//
//  Created by Krupupakku on 21/10/24.
//  Copyright © 2024 Maximilian Bauer. All rights reserved.
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

// for iOS15+ use String(localized: "key")
// otherwise use NSLocalizedString("artists", comment: "artists")
extension String {
    static let artists = String(localized: "artists")
    static let albums = String(localized: "albums")
    
    static let directories = String(localized: "directories")
    static let downloads = String(localized: "downloads")
    
    static let favorite = String(localized: "favorite")
    static let favoriteAlbums = String(localized: "favorite_albums")
    static let favoriteArtists = String(localized: "favorite_artists")
    static let favoriteSongs = String(localized: "favorite_songs")

    static let genres = String(localized: "genres")
    
    static let library = String(localized: "library")
    
    static let newestAlbums = String(localized: "newest_albums")

    static let playlists = String(localized: "playlists")
    static let podcasts = String(localized: "podcasts")

    static let recentlyPlayedAlbums = String(localized: "recently_played_albums")
    
    static let search = String(localized: "search")
    static let searchIn = String(localized: "search_in")
    static let settings = String(localized: "settings")
    static let songs = String(localized: "songs")

    static let queue = String(localized: "queue")
}
