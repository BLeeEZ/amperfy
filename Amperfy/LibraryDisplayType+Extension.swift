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

import AmperfyKit
import UIKit

extension LibraryDisplayType {
  public func controller(settings: PersistentStorage.Settings) -> UIViewController {
    switch self {
    case .artists:
      return AppStoryboard.Main.segueToArtists()
    case .albums:
      return AppStoryboard.Main.createAlbumsVC(style: settings.albumsStyleSetting, category: .all)
    case .songs:
      return AppStoryboard.Main.segueToSongs()
    case .genres:
      return AppStoryboard.Main.segueToGenres()
    case .directories:
      return AppStoryboard.Main.segueToMusicFolders()
    case .playlists:
      return AppStoryboard.Main.segueToPlaylists()
    case .podcasts:
      return AppStoryboard.Main.segueToPodcasts()
    case .downloads:
      return AppStoryboard.Main.segueToDownloads()
    case .favoriteSongs:
      return AppStoryboard.Main.segueToFavoriteSongs()
    case .favoriteAlbums:
      return AppStoryboard.Main.createAlbumsVC(
        style: settings.albumsStyleSetting,
        category: .favorites
      )
    case .favoriteArtists:
      return AppStoryboard.Main.segueToFavoriteArtists()
    case .newestAlbums:
      return AppStoryboard.Main.createAlbumsVC(
        style: settings.albumsStyleSetting,
        category: .newest
      )
    case .recentAlbums:
      return AppStoryboard.Main.createAlbumsVC(
        style: settings.albumsStyleSetting,
        category: .recent
      )
    case .radios:
      return AppStoryboard.Main.segueToRadios()
    }
  }
}
