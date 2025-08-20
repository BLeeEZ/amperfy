//
//  AppStoryboard.swift
//  Amperfy
//
//  Created by Maximilian Bauer on 09.03.19.
//  Copyright (c) 2019 Maximilian Bauer. All rights reserved.
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
import Foundation
import UIKit

// MARK: - AppStoryboard

@MainActor
enum AppStoryboard: String {
  case Main

  var instance: UIStoryboard {
    UIStoryboard(name: rawValue, bundle: Bundle.main)
  }

  func viewController<T: UIViewController>(viewControllerClass: T.Type) -> T {
    instance.instantiateViewController(withIdentifier: viewControllerClass.storyboardID) as! T
  }

  // MARK: true Storyboard view controller

  func segueToLogin() -> UIViewController { LoginVC.instantiateFromAppStoryboard() }
  func segueToSync() -> UIViewController { SyncVC.instantiateFromAppStoryboard() }
  func segueToUpdate() -> UIViewController { UpdateVC.instantiateFromAppStoryboard() }
  func segueToLibrarySyncPopup() -> LibrarySyncPopupVC { LibrarySyncPopupVC
    .instantiateFromAppStoryboard()
  }

  // MARK: create regualar instances

  func createAlbumsVC(
    style: AlbumsDisplayStyle,
    category: DisplayCategoryFilter
  )
    -> UIViewController {
    switch style {
    case .table:
      let vc = AlbumsVC()
      vc.displayFilter = category
      return vc
    case .grid:
      let vc = AlbumsCollectionVC(collectionViewLayout: .verticalLayout)
      vc.displayFilter = category
      return vc
    }
  }

  func segueToMainWindow() -> UIViewController {
    #if targetEnvironment(macCatalyst) // ok
      SplitVC(style: .doubleColumn)
    #else
      TabBarVC()
    #endif
  }

  func checkForMainWindow(vc: UIViewController) -> MainSceneHostingViewController? {
    #if targetEnvironment(macCatalyst) // ok
      return vc as? SplitVC
    #else
      return vc as? TabBarVC
    #endif
  }

  func segueToPlaylistSelector(itemsToAdd: [Song]) -> UIViewController {
    let playlistSelectorVC = PlaylistSelectorVC()
    playlistSelectorVC.itemsToAdd = itemsToAdd
    return playlistSelectorVC
  }

  func segueToPlaylistEdit(playlist: Playlist) -> PlaylistEditVC {
    let playlistEditVC = PlaylistEditVC()
    playlistEditVC.playlist = playlist
    return playlistEditVC
  }

  func segueToSideBar() -> UIViewController {
    SideBarVC(collectionViewLayout: .verticalLayout)
  }

  func segueToLibrary() -> UIViewController { LibraryVC(collectionViewLayout: .verticalLayout) }
  func segueToSearch() -> SearchVC { SearchVC() }
  func segueToSettings() -> SettingsHostVC { SettingsHostVC(isForOwnWindow: false) }
  func segueToDownloads() -> UIViewController { DownloadsVC() }
  func segueToRadios() -> UIViewController { RadiosVC() }
  func segueToSongs() -> UIViewController { SongsVC() }
  func segueToFavoriteSongs() -> UIViewController { let songsVC = SongsVC()
    songsVC.displayFilter = .favorites
    return songsVC
  }

  func segueToPodcasts() -> UIViewController { PodcastsVC() }
  func segueToPlaylists() -> UIViewController { PlaylistsVC() }
  func segueToArtists() -> UIViewController { ArtistsVC() }
  func segueToFavoriteArtists() -> UIViewController { let artistsVC = ArtistsVC()
    artistsVC.displayFilter = .favorites
    return artistsVC
  }

  func segueToMusicFolders() -> UIViewController {
    MusicFoldersVC()
  }

  func segueToGenres() -> UIViewController {
    GenresVC()
  }

  func segueToGenreDetail(genre: Genre) -> UIViewController {
    let genreDetailVC = GenreDetailVC()
    genreDetailVC.genre = genre
    return genreDetailVC
  }

  func segueToArtistDetail(artist: Artist, albumToScrollTo: Album? = nil) -> UIViewController {
    let artistDetailVC = ArtistDetailVC()
    artistDetailVC.artist = artist
    artistDetailVC.albumToScrollTo = albumToScrollTo
    return artistDetailVC
  }

  func segueToAlbumDetail(album: Album, songToScrollTo: Song? = nil) -> UIViewController {
    let albumDetailVC = AlbumDetailVC()
    albumDetailVC.album = album
    albumDetailVC.songToScrollTo = songToScrollTo
    return albumDetailVC
  }

  func segueToIndexes(musicFolder: MusicFolder) -> UIViewController {
    let indexesVC = IndexesVC()
    indexesVC.musicFolder = musicFolder
    return indexesVC
  }

  func segueToDirectories(directory: Directory) -> UIViewController {
    let directoriesVC = DirectoriesVC()
    directoriesVC.directory = directory
    return directoriesVC
  }

  func segueToPlaylistDetail(playlist: Playlist) -> UIViewController {
    let playlistDetailVC = PlaylistDetailVC()
    playlistDetailVC.playlist = playlist
    return playlistDetailVC
  }

  func segueToPodcastDetail(
    podcast: Podcast,
    episodeToScrollTo: PodcastEpisode? = nil
  )
    -> UIViewController {
    let podcastDetailVC = PodcastDetailVC()
    podcastDetailVC.podcast = podcast
    podcastDetailVC.episodeToScrollTo = episodeToScrollTo
    return podcastDetailVC
  }
}

extension UIViewController {
  class var storyboardID: String {
    "\(self)"
  }

  static func instantiateFromAppStoryboard(appStoryboard: AppStoryboard = .Main) -> Self {
    appStoryboard.viewController(viewControllerClass: self)
  }
}
