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
      return ArtistsVC.instantiateFromAppStoryboard()
    case .albums:
      let vc = AppStoryboard.Main.createAlbumsVC(style: settings.albumsStyleSetting, category: .all)
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
      let vc = AppStoryboard.Main.createAlbumsVC(
        style: settings.albumsStyleSetting,
        category: .favorites
      )
      return vc
    case .favoriteArtists:
      let vc = ArtistsVC.instantiateFromAppStoryboard()
      vc.displayFilter = .favorites
      return vc
    case .newestAlbums:
      let vc = AppStoryboard.Main.createAlbumsVC(
        style: settings.albumsStyleSetting,
        category: .newest
      )
      return vc
    case .recentAlbums:
      let vc = AppStoryboard.Main.createAlbumsVC(
        style: settings.albumsStyleSetting,
        category: .recent
      )
      return vc
    case .radios:
      let vc = RadiosVC()
      return vc
    }
  }
}
