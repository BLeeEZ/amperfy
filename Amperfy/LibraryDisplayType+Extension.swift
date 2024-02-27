//
//  LibraryDisplayType+Extension.swift
//  Amperfy
//
//  Created by Maximilian Bauer on 28.02.24.
//  Copyright (c) 2024 Maximilian Bauer. All rights reserved.
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

import UIKit
import AmperfyKit

extension LibraryDisplayType {
    public var controller: UIViewController {
        switch self {
        case .artists:
            return ArtistsVC.instantiateFromAppStoryboard()
        case .albums:
            let vc = AlbumsVC.instantiateFromAppStoryboard()
            return vc
        case .songs:
            let vc = SongsVC.instantiateFromAppStoryboard()
            return vc
        case .genres:
            let vc = GenresVC.instantiateFromAppStoryboard()
            return vc
        case .directories:
            let vc = MusicFoldersVC.instantiateFromAppStoryboard()
            return vc
        case .playlists:
            let vc = PlaylistsVC.instantiateFromAppStoryboard()
            return vc
        case .podcasts:
            let vc = PodcastsVC.instantiateFromAppStoryboard()
            return vc
        case .downloads:
            let vc = DownloadsVC.instantiateFromAppStoryboard()
            return vc
        case .favoriteSongs:
            let vc = SongsVC.instantiateFromAppStoryboard()
            vc.displayFilter = .favorites
            return vc
        case .favoriteAlbums:
            let vc = AlbumsVC.instantiateFromAppStoryboard()
            vc.displayFilter = .favorites
            return vc
        case .favoriteArtists:
            let vc = ArtistsVC.instantiateFromAppStoryboard()
            vc.displayFilter = .favorites
            return vc
        case .newestAlbums:
            let vc = AlbumsVC.instantiateFromAppStoryboard()
            vc.displayFilter = .newest
            return vc
        case .recentAlbums:
            let vc = AlbumsVC.instantiateFromAppStoryboard()
            vc.displayFilter = .recent
            return vc
        }
    }
}
