//
//  SearchVC.swift
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
import CoreData
import UIKit

// MARK: - SearchSection

public enum SearchSection: Int, CaseIterable {
  case History
  case Artist
  case Album
  case Playlist
  case Song
}

// MARK: - SearchDiffableDataSource

class SearchDiffableDataSource: BasicUITableViewDiffableDataSource {
  public var searchVC: SearchVC!

  override func tableView(
    _ tableView: UITableView,
    titleForHeaderInSection section: Int
  )
    -> String? {
    switch SearchSection(rawValue: section) {
    case .History:
      if searchVC.searchHistory.isEmpty {
        return "No Recent Searches"
      } else {
        return "Recently Searched"
      }
    case .Playlist:
      return "Playlists"
    case .Artist:
      return "Artists"
    case .Album:
      return "Albums"
    case .Song:
      return "Songs"
    case .none:
      return ""
    }
  }
}

// MARK: - SearchVC

class SearchVC: BasicTableViewController {
  override var sceneTitle: String { "Search" }

  nonisolated private static let categoryItemLimit = 10

  private var diffableDataSource: SearchDiffableDataSource?
  fileprivate var searchHistory: [SearchHistoryItem] = []
  fileprivate var artists: [Artist] = []
  fileprivate var albums: [Album] = []
  fileprivate var playlists: [Playlist] = []
  fileprivate var songs: [Song] = []

  private var optionsButton: UIBarButtonItem = OptionsBarButton()
  private var isSearchActive = false

  func createDiffableDataSource() -> SearchDiffableDataSource {
    let source =
      SearchDiffableDataSource(tableView: tableView) { tableView, indexPath, objectID -> UITableViewCell? in
        return self.tableView(self.tableView, cellForRowAt: indexPath)
      }
    source.searchVC = self
    return source
  }

  func updateDataSource(animated: Bool) {
    guard let dataSource = tableView?.dataSource as? UITableViewDiffableDataSource<
      Int,
      NSManagedObjectID
    > else {
      assertionFailure("The data source has not implemented snapshot support while it should")
      return
    }
    var snapshot = dataSource.snapshot() as NSDiffableDataSourceSnapshot<Int, NSManagedObjectID>
    snapshot.deleteAllItems()
    snapshot.appendSections(SearchSection.allCases.compactMap { $0.rawValue })
    snapshot.appendItems(
      searchHistory.compactMap { $0.managedObject.objectID },
      toSection: SearchSection.History.rawValue
    )
    snapshot.appendItems(
      artists.compactMap { $0.managedObject.objectID },
      toSection: SearchSection.Artist.rawValue
    )
    snapshot.appendItems(
      albums.compactMap { $0.managedObject.objectID },
      toSection: SearchSection.Album.rawValue
    )
    snapshot.appendItems(
      playlists.compactMap { $0.managedObject.objectID },
      toSection: SearchSection.Playlist.rawValue
    )
    snapshot.appendItems(
      songs.compactMap { $0.managedObject.objectID },
      toSection: SearchSection.Song.rawValue
    )
    dataSource.apply(snapshot, animatingDifferences: animated)
  }

  override func viewDidLoad() {
    super.viewDidLoad()
    /// Store the data source in an instance property to make sure it's retained.
    diffableDataSource = createDiffableDataSource()
    /// Assign the data source to your collection view.
    tableView.dataSource = diffableDataSource

    searchHistory = appDelegate.storage.main.library.getSearchHistory()
    updateDataSource(animated: false)

    tableView.register(nibName: PlaylistTableCell.typeName)
    tableView.register(nibName: GenericTableCell.typeName)
    tableView.register(nibName: GenericTableCell.typeName)
    tableView.register(nibName: PlayableTableCell.typeName)
    tableView.separatorStyle = .none
    tableView.sectionHeaderTopPadding = 0

    containableAtIndexPathCallback = { indexPath in
      switch SearchSection(rawValue: indexPath.section) {
      case .History:
        return self.searchHistory[indexPath.row].searchedPlayableContainable
      case .Playlist:
        return self.playlists[indexPath.row]
      case .Artist:
        return self.artists[indexPath.row]
      case .Album:
        return self.albums[indexPath.row]
      case .Song:
        return self.songs[indexPath.row]
      case .none:
        return nil
      }
    }
    playContextAtIndexPathCallback = { indexPath in
      switch SearchSection(rawValue: indexPath.section) {
      case .History:
        let history = self.searchHistory[indexPath.row]
        guard let container = history.searchedPlayableContainable else { return nil }
        return PlayContext(containable: container)
      case .Playlist:
        let entity = self.playlists[indexPath.row]
        return PlayContext(containable: entity)
      case .Artist:
        let entity = self.artists[indexPath.row]
        return PlayContext(containable: entity)
      case .Album:
        let entity = self.albums[indexPath.row]
        return PlayContext(containable: entity)
      case .Song:
        let entity = self.songs[indexPath.row]
        return PlayContext(containable: entity)
      case .none:
        return nil
      }
    }
    swipeCallback = { indexPath, completionHandler in
      self.determSwipeActionContext(at: indexPath) { actionContext in
        completionHandler(actionContext)
      }
    }
  }

  override func viewIsAppearing(_ animated: Bool) {
    #if targetEnvironment(macCatalyst)
      // Request a search update (in case we navigated back to the search)
      NotificationCenter.default.post(name: .RequestSearchUpdate, object: view.window)
    #endif
    super.viewIsAppearing(animated)
    appDelegate.userStatistics.visited(.search)
    configureSearchController(
      placeholder: "Playlists, Songs and more",
      scopeButtonTitles: ["All", "Cached"],
      showSearchBarAtEnter: true
    )
  }

  public func activateSearchBar() {
    if isViewLoaded {
      // activate searchBar
      searchController.searchBar.becomeFirstResponder()
    }
  }

  override func configureSearchController(
    placeholder: String?,
    scopeButtonTitles: [String]? = nil,
    showSearchBarAtEnter: Bool = false
  ) {
    super.configureSearchController(
      placeholder: placeholder,
      scopeButtonTitles: scopeButtonTitles,
      showSearchBarAtEnter: showSearchBarAtEnter
    )

    // Install the options button
    optionsButton.menu = UIMenu(children: [
      UIAction(title: "Clear Search History", image: .clear, handler: { _ in
        self.appDelegate.storage.main.library.deleteSearchHistory()
        self.appDelegate.storage.main.library.saveContext()
        self.searchHistory = []
        self.updateDataSource(animated: true)
      }),
    ])

    #if targetEnvironment(macCatalyst)
      let scopeButtonSegmentedControl = UISegmentedControl(
        items:
        (scopeButtonTitles ?? [])?.enumerated().map { i, title in
          UIAction(title: title, handler: { [weak self] action in
            self?.searchController.searchBar.selectedScopeButtonIndex = i
          })
        }
      )
      scopeButtonSegmentedControl.selectedSegmentIndex = searchController.searchBar
        .selectedScopeButtonIndex

      // Remove the search bar from the navigationbar on macOS
      navigationItem.searchController = nil
      navigationItem.rightBarButtonItems = [
        optionsButton,
        UIBarButtonItem(customView: scopeButtonSegmentedControl),
      ]

      // Listen for search changes from the sidebar
      NotificationCenter.default.addObserver(
        self,
        selector: #selector(handleSearchUpdate(notification:)),
        name: .SearchChanged,
        object: nil
      )
    #else
      navigationItem.rightBarButtonItem = optionsButton
    #endif
  }

  #if targetEnvironment(macCatalyst)
    @objc
    func handleSearchUpdate(notification: Notification) {
      // only update the search in this tab
      guard notification.object as? UIWindow == view.window else { return }
      searchController.searchBar.text = notification.userInfo?["searchText"] as? String
    }
  #endif

  func determSwipeActionContext(
    at indexPath: IndexPath,
    completionHandler: @escaping (_ actionContext: SwipeActionContext?) -> ()
  ) {
    switch SearchSection(rawValue: indexPath.section) {
    case .History:
      let history = searchHistory[indexPath.row]
      guard let container = history.searchedPlayableContainable
      else { completionHandler(nil); return }
      Task { @MainActor in
        do {
          try await container.fetch(
            storage: self.appDelegate.storage,
            librarySyncer: self.appDelegate.librarySyncer,
            playableDownloadManager: self.appDelegate.playableDownloadManager
          )
        } catch {
          self.appDelegate.eventLogger.report(topic: "History Sync", error: error)
        }
        completionHandler(SwipeActionContext(containable: container))
      }
    case .Playlist:
      let playlist = playlists[indexPath.row]
      Task { @MainActor in
        do {
          try await playlist.fetch(
            storage: self.appDelegate.storage,
            librarySyncer: self.appDelegate.librarySyncer,
            playableDownloadManager: self.appDelegate.playableDownloadManager
          )
        } catch {
          self.appDelegate.eventLogger.report(topic: "Playlist Sync", error: error)
        }
        completionHandler(SwipeActionContext(containable: playlist))
      }
    case .Artist:
      let artist = artists[indexPath.row]
      Task { @MainActor in
        do {
          try await artist.fetch(
            storage: self.appDelegate.storage,
            librarySyncer: self.appDelegate.librarySyncer,
            playableDownloadManager: self.appDelegate.playableDownloadManager
          )
        } catch {
          self.appDelegate.eventLogger.report(topic: "Artist Sync", error: error)
        }
        completionHandler(SwipeActionContext(containable: artist))
      }
    case .Album:
      let album = albums[indexPath.row]
      Task { @MainActor in
        do {
          try await album.fetch(
            storage: self.appDelegate.storage,
            librarySyncer: self.appDelegate.librarySyncer,
            playableDownloadManager: self.appDelegate.playableDownloadManager
          )
        } catch {
          self.appDelegate.eventLogger.report(topic: "Album Sync", error: error)
        }
        completionHandler(SwipeActionContext(containable: album))
      }
    case .Song:
      let song = songs[indexPath.row]
      completionHandler(SwipeActionContext(containable: song))
    case .none:
      completionHandler(nil)
    }
  }

  func convertCellViewToPlayContext(cell: UITableViewCell) -> PlayContext? {
    guard let indexPath = tableView.indexPath(for: cell) else { return nil }
    if SearchSection(rawValue: indexPath.section) == .Song {
      let song = songs[indexPath.row]
      return PlayContext(containable: song)
    } else if SearchSection(rawValue: indexPath.section) == .History {
      let history = searchHistory[indexPath.row]
      guard let song = history.searchedPlayableContainable as? Song else { return nil }
      return PlayContext(containable: song)
    }
    return nil
  }

  // MARK: - Table view data source

  override func tableView(
    _ tableView: UITableView,
    cellForRowAt indexPath: IndexPath
  )
    -> UITableViewCell {
    switch SearchSection(rawValue: indexPath.section) {
    case .History:
      let history = searchHistory[indexPath.row]
      guard let container = history.searchedPlayableContainable else { return UITableViewCell() }
      if let playlist = container as? Playlist {
        let cell: PlaylistTableCell = dequeueCell(for: tableView, at: indexPath)
        cell.display(playlist: playlist, rootView: self)
        return cell
      } else if let song = container as? Song {
        let cell: PlayableTableCell = dequeueCell(for: tableView, at: indexPath)
        cell.display(playable: song, playContextCb: convertCellViewToPlayContext, rootView: self)
        return cell
      } else {
        let cell: GenericTableCell = dequeueCell(for: tableView, at: indexPath)
        cell.display(container: container, rootView: self)
        return cell
      }
    case .Playlist:
      let cell: PlaylistTableCell = dequeueCell(for: tableView, at: indexPath)
      let playlist = playlists[indexPath.row]
      cell.display(playlist: playlist, rootView: self)
      return cell
    case .Artist:
      let cell: GenericTableCell = dequeueCell(for: tableView, at: indexPath)
      let artist = artists[indexPath.row]
      cell.display(container: artist, rootView: self)
      return cell
    case .Album:
      let cell: GenericTableCell = dequeueCell(for: tableView, at: indexPath)
      let album = albums[indexPath.row]
      cell.display(container: album, rootView: self)
      return cell
    case .Song:
      let cell: PlayableTableCell = dequeueCell(for: tableView, at: indexPath)
      let song = songs[indexPath.row]
      cell.display(playable: song, playContextCb: convertCellViewToPlayContext, rootView: self)
      return cell
    case .none:
      return UITableViewCell()
    }
  }

  override func tableView(
    _ tableView: UITableView,
    heightForHeaderInSection section: Int
  )
    -> CGFloat {
    switch SearchSection(rawValue: section) {
    case .History:
      return !isSearchActive ? CommonScreenOperations.tableSectionHeightLarge : 0
    case .Playlist:
      return (isSearchActive && !playlists.isEmpty) ? CommonScreenOperations
        .tableSectionHeightLarge : 0
    case .Artist:
      return (isSearchActive && !artists.isEmpty) ? CommonScreenOperations
        .tableSectionHeightLarge : 0
    case .Album:
      return (isSearchActive && !albums.isEmpty) ? CommonScreenOperations
        .tableSectionHeightLarge : 0
    case .Song:
      return (isSearchActive && !songs.isEmpty) ? CommonScreenOperations.tableSectionHeightLarge : 0
    case .none:
      return 0.0
    }
  }

  override func tableView(
    _ tableView: UITableView,
    heightForRowAt indexPath: IndexPath
  )
    -> CGFloat {
    switch SearchSection(rawValue: indexPath.section) {
    case .History:
      let history = searchHistory[indexPath.row]
      guard let container = history.searchedPlayableContainable else { return 0.0 }
      if container is Playlist {
        return PlaylistTableCell.rowHeight
      } else if container is Song {
        return PlayableTableCell.rowHeight
      } else {
        return GenericTableCell.rowHeight
      }
    case .Playlist:
      return PlaylistTableCell.rowHeight
    case .Artist:
      return GenericTableCell.rowHeight
    case .Album:
      return GenericTableCell.rowHeight
    case .Song:
      return PlayableTableCell.rowHeight
    case .none:
      return 0.0
    }
  }

  override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    switch SearchSection(rawValue: indexPath.section) {
    case .History:
      let history = searchHistory[indexPath.row]
      guard let container = history.searchedPlayableContainable else { break }
      let _ = appDelegate.storage.main.library.createOrUpdateSearchHistory(container: container)
      if !(container is Song) {
        EntityPreviewActionBuilder(container: container, on: self).performPreviewTransition()
      }
    case .Playlist:
      let playlist = playlists[indexPath.row]
      let _ = appDelegate.storage.main.library.createOrUpdateSearchHistory(container: playlist)
      performSegue(withIdentifier: Segues.toPlaylistDetail.rawValue, sender: playlist)
    case .Artist:
      let artist = artists[indexPath.row]
      let _ = appDelegate.storage.main.library.createOrUpdateSearchHistory(container: artist)
      performSegue(withIdentifier: Segues.toArtistDetail.rawValue, sender: artist)
    case .Album:
      let album = albums[indexPath.row]
      let _ = appDelegate.storage.main.library.createOrUpdateSearchHistory(container: album)
      performSegue(withIdentifier: Segues.toAlbumDetail.rawValue, sender: album)
    case .Song:
      let song = songs[indexPath.row]
      let _ = appDelegate.storage.main.library.createOrUpdateSearchHistory(container: song)
    case .none: break
    }
    appDelegate.storage.main.library.saveContext()
  }

  override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
    switch segue.identifier {
    case Segues.toPlaylistDetail.rawValue:
      let vc = segue.destination as! PlaylistDetailVC
      let playlist = sender as? Playlist
      vc.playlist = playlist
    case Segues.toArtistDetail.rawValue:
      let vc = segue.destination as! ArtistDetailVC
      let artist = sender as? Artist
      vc.artist = artist
    case Segues.toAlbumDetail.rawValue:
      let vc = segue.destination as! AlbumDetailVC
      let album = sender as? Album
      vc.album = album
    default: break
    }
  }

  struct SearchResultObjectContainer: Sendable {
    var artistsIDs = [NSManagedObjectID]()
    var albumsIDs = [NSManagedObjectID]()
    var playlistsIDs = [NSManagedObjectID]()
    var songsIDs = [NSManagedObjectID]()
  }

  override func updateSearchResults(for searchController: UISearchController) {
    guard let searchText = searchController.searchBar.text else { return }
    if !searchText.isEmpty, searchController.searchBar.selectedScopeButtonIndex == 0 {
      Task { @MainActor in do {
        try await self.appDelegate.librarySyncer.searchArtists(searchText: searchText)
      } catch {
        self.appDelegate.eventLogger.report(topic: "Artists Search", error: error)
      }}

      Task { @MainActor in do {
        try await self.appDelegate.librarySyncer.searchAlbums(searchText: searchText)
      } catch {
        self.appDelegate.eventLogger.report(topic: "Albums Search", error: error)
      }}

      Task { @MainActor in do {
        try await self.appDelegate.librarySyncer.searchSongs(searchText: searchText)
      } catch {
        self.appDelegate.eventLogger.report(topic: "Songs Search", error: error)
      }}

      Task { @MainActor in do {
        let searchResult = try await appDelegate.storage.async.performAndGet { asyncCompanion in
          let artists = asyncCompanion.library.searchArtists(
            searchText: searchText,
            onlyCached: false,
            displayFilter: .all
          )
          let albums = asyncCompanion.library.searchAlbums(
            searchText: searchText,
            onlyCached: false,
            displayFilter: .all
          )
          let playlists = asyncCompanion.library.searchPlaylists(
            searchText: searchText,
            playlistSearchCategory: .all
          )
          let songs = asyncCompanion.library.searchSongs(
            searchText: searchText,
            onlyCached: false,
            displayFilter: .all
          )

          var result = SearchResultObjectContainer()
          result.artistsIDs = FuzzySearcher.findBestMatch(in: artists, search: searchText)
            .prefix(upToAsArray: Self.categoryItemLimit)
            .compactMap { $0 as? Artist }
            .compactMap { $0.managedObject.objectID }
          result.albumsIDs = FuzzySearcher.findBestMatch(in: albums, search: searchText)
            .prefix(upToAsArray: Self.categoryItemLimit)
            .compactMap { $0 as? Album }
            .compactMap { $0.managedObject.objectID }
          result.playlistsIDs = FuzzySearcher.findBestMatch(in: playlists, search: searchText)
            .prefix(upToAsArray: Self.categoryItemLimit)
            .compactMap { $0 as? Playlist }
            .compactMap { $0.managedObject.objectID }
          result.songsIDs = FuzzySearcher.findBestMatch(in: songs, search: searchText)
            .prefix(upToAsArray: Self.categoryItemLimit)
            .compactMap { $0 as? Song }
            .compactMap { $0.managedObject.objectID }
          return result
        }

        guard searchText == self.searchController.searchBar.text else { return }
        self.isSearchActive = true
        self.searchHistory = []
        self.artists = searchResult.artistsIDs
          .compactMap { self.appDelegate.storage.main.context.object(with: $0) as? ArtistMO }
          .compactMap { Artist(managedObject: $0) }
        self.albums = searchResult.albumsIDs
          .compactMap { self.appDelegate.storage.main.context.object(with: $0) as? AlbumMO }
          .compactMap { Album(managedObject: $0) }
        self.playlists = searchResult.playlistsIDs
          .compactMap { self.appDelegate.storage.main.context.object(with: $0) as? PlaylistMO }
          .compactMap { Playlist(library: self.appDelegate.storage.main.library, managedObject: $0)
          }
        self.songs = searchResult.songsIDs
          .compactMap { self.appDelegate.storage.main.context.object(with: $0) as? SongMO }
          .compactMap { Song(managedObject: $0) }
        self.tableView.separatorStyle = .singleLine
        self.updateDataSource(animated: false)
      } catch {
        // do nothing
      }}
    } else if !searchText.isEmpty, searchController.searchBar.selectedScopeButtonIndex == 1 {
      Task { @MainActor in do {
        let searchResult = try await appDelegate.storage.async.performAndGet { asyncCompanion in
          let artists = asyncCompanion.library.searchArtists(
            searchText: searchText,
            onlyCached: true,
            displayFilter: .all
          )
          let albums = asyncCompanion.library.searchAlbums(
            searchText: searchText,
            onlyCached: true,
            displayFilter: .all
          )
          let playlists = asyncCompanion.library.searchPlaylists(
            searchText: searchText,
            playlistSearchCategory: .cached
          )
          let songs = asyncCompanion.library.searchSongs(
            searchText: searchText,
            onlyCached: true,
            displayFilter: .all
          )

          var result = SearchResultObjectContainer()
          result.artistsIDs = FuzzySearcher.findBestMatch(in: artists, search: searchText)
            .prefix(upToAsArray: Self.categoryItemLimit)
            .compactMap { $0 as? Artist }
            .compactMap { $0.managedObject.objectID }
          result.albumsIDs = FuzzySearcher.findBestMatch(in: albums, search: searchText)
            .prefix(upToAsArray: Self.categoryItemLimit)
            .compactMap { $0 as? Album }
            .compactMap { $0.managedObject.objectID }
          result.playlistsIDs = FuzzySearcher.findBestMatch(in: playlists, search: searchText)
            .prefix(upToAsArray: Self.categoryItemLimit)
            .compactMap { $0 as? Playlist }
            .compactMap { $0.managedObject.objectID }
          result.songsIDs = FuzzySearcher.findBestMatch(in: songs, search: searchText)
            .prefix(upToAsArray: Self.categoryItemLimit)
            .compactMap { $0 as? Song }
            .compactMap { $0.managedObject.objectID }
          return result
        }

        guard searchText == self.searchController.searchBar.text else { return }
        self.isSearchActive = true
        self.searchHistory = []
        self.artists = searchResult.artistsIDs
          .compactMap { self.appDelegate.storage.main.context.object(with: $0) as? ArtistMO }
          .compactMap { Artist(managedObject: $0) }
        self.albums = searchResult.albumsIDs
          .compactMap { self.appDelegate.storage.main.context.object(with: $0) as? AlbumMO }
          .compactMap { Album(managedObject: $0) }
        self.playlists = searchResult.playlistsIDs
          .compactMap { self.appDelegate.storage.main.context.object(with: $0) as? PlaylistMO }
          .compactMap { Playlist(library: self.appDelegate.storage.main.library, managedObject: $0)
          }
        self.songs = searchResult.songsIDs
          .compactMap { self.appDelegate.storage.main.context.object(with: $0) as? SongMO }
          .compactMap { Song(managedObject: $0) }
        self.tableView.separatorStyle = .singleLine
        self.updateDataSource(animated: false)
      } catch {
        // do nothing
      }}
    } else {
      isSearchActive = false
      searchHistory = appDelegate.storage.main.library.getSearchHistory()
      artists = []
      albums = []
      playlists = []
      songs = []
      tableView.separatorStyle = .singleLine
      updateDataSource(animated: false)
    }
  }
}
