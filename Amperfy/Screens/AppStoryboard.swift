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

  func segueToLogin() -> UIViewController { LoginVC() }
  func segueToSync(account: Account) -> UIViewController {
    let syncVC = SyncVC.instantiateFromAppStoryboard()
    syncVC.account = account
    return syncVC
  }

  func segueToUpdate() -> UIViewController { UpdateVC.instantiateFromAppStoryboard() }
  func segueToLibrarySyncPopup() -> LibrarySyncPopupVC { LibrarySyncPopupVC
    .instantiateFromAppStoryboard()
  }

  // MARK: create regualar instances

  func createAlbumsVC(
    account: Account,
    style: AlbumsDisplayStyle,
    category: DisplayCategoryFilter
  )
    -> UIViewController {
    switch style {
    case .table:
      let vc = AlbumsVC(account: account)
      vc.displayFilter = category
      return vc
    case .grid:
      let vc = AlbumsCollectionVC(collectionViewLayout: .verticalLayout, account: account)
      vc.displayFilter = category
      return vc
    }
  }

  func segueToMainWindow(account: Account) -> UIViewController {
    #if targetEnvironment(macCatalyst) // ok
      SplitVC(style: .doubleColumn, account: account)
    #else
      TabBarVC(account: account)
    #endif
  }

  func checkForMainWindow(vc: UIViewController) -> MainSceneHostingViewController? {
    #if targetEnvironment(macCatalyst) // ok
      return vc as? SplitVC
    #else
      return vc as? TabBarVC
    #endif
  }

  func segueToPlaylistSelector(account: Account, itemsToAdd: [Song]) -> UIViewController {
    let playlistSelectorVC = PlaylistSelectorVC(account: account, itemsToAdd: itemsToAdd)
    return playlistSelectorVC
  }

  func segueToPlaylistEdit(account: Account, playlist: Playlist) -> PlaylistEditVC {
    let playlistEditVC = PlaylistEditVC(account: account, playlist: playlist)
    return playlistEditVC
  }

  func segueToSideBar(account: Account) -> UIViewController {
    SideBarVC(collectionViewLayout: .verticalLayout, account: account)
  }

  func segueToHome(account: Account) -> HomeVC { HomeVC(account: account) }
  func segueToLibrary(account: Account) -> UIViewController { LibraryVC(
    collectionViewLayout: .verticalLayout,
    account: account
  ) }
  func segueToSearch(account: Account) -> SearchVC { SearchVC(account: account) }
  func segueToSettings() -> SettingsHostVC { SettingsHostVC(isForOwnWindow: false) }
  func segueToDownloads(account: Account) -> UIViewController { DownloadsVC(account: account) }
  func segueToRadios(account: Account) -> UIViewController { RadiosVC(account: account) }
  func segueToSongs(account: Account) -> UIViewController { SongsVC(account: account) }
  func segueToFavoriteSongs(account: Account)
    -> UIViewController { let songsVC = SongsVC(account: account)
    songsVC.displayFilter = .favorites
    return songsVC
  }

  func segueToPodcasts(account: Account) -> UIViewController { PodcastsVC(account: account) }
  func segueToPlaylists(account: Account) -> UIViewController { PlaylistsVC(account: account) }
  func segueToArtists(account: Account) -> UIViewController { ArtistsVC(account: account) }
  func segueToFavoriteArtists(account: Account)
    -> UIViewController { let artistsVC = ArtistsVC(account: account)
    artistsVC.displayFilter = .favorites
    return artistsVC
  }

  func segueToMusicFolders(account: Account) -> UIViewController {
    MusicFoldersVC(account: account)
  }

  func segueToGenres(account: Account) -> UIViewController {
    GenresVC(account: account)
  }

  func segueToGenreDetail(account: Account, genre: Genre) -> UIViewController {
    let genreDetailVC = GenreDetailVC(account: account, genre: genre)
    return genreDetailVC
  }

  func segueToArtistDetail(
    account: Account,
    artist: Artist,
    albumToScrollTo: Album? = nil
  )
    -> UIViewController {
    let artistDetailVC = ArtistDetailVC(account: account, artist: artist)
    artistDetailVC.albumToScrollTo = albumToScrollTo
    return artistDetailVC
  }

  func segueToAlbumDetail(
    account: Account,
    album: Album,
    songToScrollTo: Song? = nil
  )
    -> UIViewController {
    let albumDetailVC = AlbumDetailVC(account: account, album: album)
    albumDetailVC.songToScrollTo = songToScrollTo
    return albumDetailVC
  }

  func segueToIndexes(account: Account, musicFolder: MusicFolder) -> UIViewController {
    let indexesVC = IndexesVC(account: account, musicFolder: musicFolder)
    return indexesVC
  }

  func segueToDirectories(account: Account, directory: Directory) -> UIViewController {
    let directoriesVC = DirectoriesVC(account: account, directory: directory)
    return directoriesVC
  }

  func segueToPlaylistDetail(account: Account, playlist: Playlist) -> UIViewController {
    let playlistDetailVC = PlaylistDetailVC(account: account, playlist: playlist)
    return playlistDetailVC
  }

  func segueToPodcastDetail(
    account: Account,
    podcast: Podcast,
    episodeToScrollTo: PodcastEpisode? = nil
  )
    -> UIViewController {
    let podcastDetailVC = PodcastDetailVC(account: account, podcast: podcast)
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
