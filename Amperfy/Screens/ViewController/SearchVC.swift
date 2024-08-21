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

import UIKit
import CoreData
import AmperfyKit
import PromiseKit

public enum SearchSection: Int, CaseIterable {
    case History
    case Artist
    case Album
    case Playlist
    case Song
}

class SearchDiffableDataSource: BasicUITableViewDiffableDataSource {
    
    public var searchVC: SearchVC!
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch SearchSection(rawValue: section) {
        case .History:
            if searchVC.searchHistory.isEmpty {
                return  "No Recent Searches"
            } else {
                return  "Recently Searched"
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

class SearchVC: BasicTableViewController {
    
    override var sceneTitle: String { "Search" }

    private static let categoryItemLimit = 10
    
    private var diffableDataSource: SearchDiffableDataSource?
    fileprivate var searchHistory: [SearchHistoryItem] = []
    fileprivate var artists: [Artist] = []
    fileprivate var albums: [Album] = []
    fileprivate var playlists: [Playlist] = []
    fileprivate var songs: [Song] = []
    
    private var optionsButton: UIBarButtonItem!
    private var isSearchActive = false
    
    func createDiffableDataSource() -> SearchDiffableDataSource {
        let source = SearchDiffableDataSource(tableView: tableView) { (tableView, indexPath, objectID) -> UITableViewCell? in
            return self.tableView(self.tableView, cellForRowAt: indexPath)
        }
        source.searchVC = self
        return source
    }
    
    func updateDataSource(animated: Bool) {
        guard let dataSource = tableView?.dataSource as? UITableViewDiffableDataSource<Int, NSManagedObjectID> else {
            assertionFailure("The data source has not implemented snapshot support while it should")
            return
        }
        var snapshot = dataSource.snapshot() as NSDiffableDataSourceSnapshot<Int, NSManagedObjectID>
        snapshot.deleteAllItems()
        snapshot.appendSections(SearchSection.allCases.compactMap{ $0.rawValue })
        snapshot.appendItems(searchHistory.compactMap{$0.managedObject.objectID}, toSection: SearchSection.History.rawValue)
        snapshot.appendItems(artists.compactMap{$0.managedObject.objectID}, toSection: SearchSection.Artist.rawValue)
        snapshot.appendItems(albums.compactMap{$0.managedObject.objectID}, toSection: SearchSection.Album.rawValue)
        snapshot.appendItems(playlists.compactMap{$0.managedObject.objectID}, toSection: SearchSection.Playlist.rawValue)
        snapshot.appendItems(songs.compactMap{$0.managedObject.objectID}, toSection: SearchSection.Song.rawValue)
        dataSource.apply(snapshot, animatingDifferences: animated)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        /// Store the data source in an instance property to make sure it's retained.
        self.diffableDataSource = createDiffableDataSource()
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

        containableAtIndexPathCallback = { (indexPath) in
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
        playContextAtIndexPathCallback = { (indexPath) in
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
        swipeCallback = { (indexPath, completionHandler) in
            self.determSwipeActionContext(at: indexPath) { actionContext in
                completionHandler(actionContext)
            }
        }
        
        #if targetEnvironment(macCatalyst)
        if #available(macCatalyst 16.0, *) {
            self.navigationController?.navigationBar.preferredBehavioralStyle = .mac
        }
        #endif
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        appDelegate.userStatistics.visited(.search)
    }

    override func viewWillLayoutSubviews() {
        self.extendSafeAreaToAccountForTabbar()
        super.viewWillLayoutSubviews()
    }

    #if targetEnvironment(macCatalyst)
    override func viewIsAppearing(_ animated: Bool) {
        // Request a search update (in case we navigated back to the search)
        NotificationCenter.default.post(name: .RequestSearchUpdate, object: self.view.window)
        super.viewIsAppearing(animated)
    }
    #endif
    
    override func viewDidAppear(_ animated: Bool) {
        configureSearchController(placeholder: "Playlists, Songs and more", scopeButtonTitles: ["All", "Cached"], showSearchBarAtEnter: true)
    }

    public func activateSearchBar() {
        if self.isViewLoaded {
            // activate searchBar
            self.searchController.searchBar.becomeFirstResponder()
        }
    }

    override func configureSearchController(placeholder: String?, scopeButtonTitles: [String]? = nil, showSearchBarAtEnter: Bool = false) {
        super.configureSearchController(placeholder: placeholder, scopeButtonTitles: scopeButtonTitles, showSearchBarAtEnter: showSearchBarAtEnter)
        
        optionsButton = OptionsBarButton()
        optionsButton.menu = UIMenu(children: [
            UIAction(title: "Clear Search History", image: .clear, handler: { _ in
                self.appDelegate.storage.main.library.deleteSearchHistory()
                self.appDelegate.storage.main.library.saveContext()
                self.searchHistory = []
                self.updateDataSource(animated: true)
            })
        ])

        #if targetEnvironment(macCatalyst)
        self.addPlayerControls()

        // Remove the search bar from the navigationbar on macOS
        navigationItem.searchController = nil

        // Listen for search changes from the sidebar
        NotificationCenter.default.addObserver(self, selector: #selector(handleSearchUpdate(notification:)), name: .SearchChanged, object: nil)

        // Add the scope buttons to the navigation bar instead
        if let scopeButtonTitles {
            let segmentedControl = UISegmentedControl(frame: .zero, actions: scopeButtonTitles.enumerated().map { (i, title) in
                UIAction(title: title) { _ in self.searchController.searchBar.selectedScopeButtonIndex = i }
            })
            segmentedControl.selectedSegmentIndex = 0
            let scopeButton = UIBarButtonItem(customView: segmentedControl)
            navigationItem.rightBarButtonItems = [optionsButton, scopeButton]
        } else {
            navigationItem.rightBarButtonItem = optionsButton
        }
        #else
        navigationItem.rightBarButtonItem = optionsButton
        #endif
    }

    #if targetEnvironment(macCatalyst)
    @objc func handleSearchUpdate(notification: Notification) {
        // only update the search in this tab
        guard notification.object as? UIWindow == self.view.window else { return }
        self.searchController.searchBar.text = notification.userInfo?["searchText"] as? String
    }
    #endif

    func determSwipeActionContext(at indexPath: IndexPath, completionHandler: @escaping (_ actionContext: SwipeActionContext?) -> Void) {
        switch SearchSection(rawValue: indexPath.section) {
        case .History:
            let history = self.searchHistory[indexPath.row]
            guard let container = history.searchedPlayableContainable else { completionHandler(nil); return }
            firstly {
                container.fetch(storage: self.appDelegate.storage, librarySyncer: self.appDelegate.librarySyncer, playableDownloadManager: self.appDelegate.playableDownloadManager)
            }.catch { error in
                self.appDelegate.eventLogger.report(topic: "History Sync", error: error)
            }.finally {
                completionHandler(SwipeActionContext(containable: container))
            }
        case .Playlist:
            let playlist = self.playlists[indexPath.row]
            firstly {
                playlist.fetch(storage: self.appDelegate.storage, librarySyncer: self.appDelegate.librarySyncer, playableDownloadManager: self.appDelegate.playableDownloadManager)
            }.catch { error in
                self.appDelegate.eventLogger.report(topic: "Playlist Sync", error: error)
            }.finally {
                completionHandler(SwipeActionContext(containable: playlist))
            }
        case .Artist:
            let artist = self.artists[indexPath.row]
            firstly {
                artist.fetch(storage: self.appDelegate.storage, librarySyncer: self.appDelegate.librarySyncer, playableDownloadManager: self.appDelegate.playableDownloadManager)
            }.catch { error in
                self.appDelegate.eventLogger.report(topic: "Artist Sync", error: error)
            }.finally {
                completionHandler(SwipeActionContext(containable: artist))
            }
        case .Album:
            let album = self.albums[indexPath.row]
            firstly {
                album.fetch(storage: self.appDelegate.storage, librarySyncer: self.appDelegate.librarySyncer, playableDownloadManager: self.appDelegate.playableDownloadManager)
            }.catch { error in
                self.appDelegate.eventLogger.report(topic: "Album Sync", error: error)
            }.finally {
                completionHandler(SwipeActionContext(containable: album))
            }
        case .Song:
            let song = self.songs[indexPath.row]
            completionHandler(SwipeActionContext(containable: song))
        case .none:
            completionHandler(nil)
        }
    }

    func convertCellViewToPlayContext(cell: UITableViewCell) -> PlayContext? {
        guard let indexPath = tableView.indexPath(for: cell) else { return nil }
        if SearchSection(rawValue: indexPath.section) == .Song {
            let song = self.songs[indexPath.row]
            return PlayContext(containable: song)
        } else if SearchSection(rawValue: indexPath.section) == .History {
            let history = self.searchHistory[indexPath.row]
            guard let song = history.searchedPlayableContainable as? Song else { return nil }
            return PlayContext(containable: song)
        }
        return nil
    }

    // MARK: - Table view data source
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch SearchSection(rawValue: indexPath.section) {
        case .History:
            let history = self.searchHistory[indexPath.row]
            guard let container = history.searchedPlayableContainable else { return UITableViewCell() }
            if let playlist = container as? Playlist {
                let cell: PlaylistTableCell = dequeueCell(for: tableView, at: indexPath)
                cell.display(playlist: playlist, rootView: self)
                cell.accessoryType = .disclosureIndicator
                return cell
            } else if let song = container as? Song {
                let cell: PlayableTableCell = dequeueCell(for: tableView, at: indexPath)
                cell.display(playable: song, playContextCb: self.convertCellViewToPlayContext, rootView: self)
                return cell
            } else {
                let cell: GenericTableCell = dequeueCell(for: tableView, at: indexPath)
                cell.display(container: container, rootView: self)
                cell.accessoryType = .disclosureIndicator
                return cell
            }
        case .Playlist:
            let cell: PlaylistTableCell = dequeueCell(for: tableView, at: indexPath)
            let playlist = self.playlists[indexPath.row]
            cell.display(playlist: playlist, rootView: self)
            cell.accessoryType = .disclosureIndicator
            return cell
        case .Artist:
            let cell: GenericTableCell = dequeueCell(for: tableView, at: indexPath)
            let artist = self.artists[indexPath.row]
            cell.display(container: artist, rootView: self)
            cell.accessoryType = .disclosureIndicator
            return cell
        case .Album:
            let cell: GenericTableCell = dequeueCell(for: tableView, at: indexPath)
            let album = self.albums[indexPath.row]
            cell.display(container: album, rootView: self)
            cell.accessoryType = .disclosureIndicator
            return cell
        case .Song:
            let cell: PlayableTableCell = dequeueCell(for: tableView, at: indexPath)
            let song = self.songs[indexPath.row]
            cell.display(playable: song, playContextCb: self.convertCellViewToPlayContext, rootView: self)
            return cell
        case .none:
            return UITableViewCell()
        }
    }
    
    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        switch SearchSection(rawValue: section) {
        case .History:
            return !isSearchActive ? CommonScreenOperations.tableSectionHeightLarge : 0
        case .Playlist:
            return (isSearchActive && !self.playlists.isEmpty) ? CommonScreenOperations.tableSectionHeightLarge : 0
        case .Artist:
            return (isSearchActive && !self.artists.isEmpty) ? CommonScreenOperations.tableSectionHeightLarge : 0
        case .Album:
            return (isSearchActive && !self.albums.isEmpty) ? CommonScreenOperations.tableSectionHeightLarge : 0
        case .Song:
            return (isSearchActive && !self.songs.isEmpty) ? CommonScreenOperations.tableSectionHeightLarge : 0
        case .none:
            return 0.0
        }
    }
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        switch SearchSection(rawValue: indexPath.section) {
        case .History:
            let history = self.searchHistory[indexPath.row]
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
            let history = self.searchHistory[indexPath.row]
            guard let container = history.searchedPlayableContainable else { break }
            let _ = appDelegate.storage.main.library.createOrUpdateSearchHistory(container: container)
            if !(container is Song) {
                EntityPreviewActionBuilder(container: container, on: self).performPreviewTransition()
            }
        case .Playlist:
            let playlist = self.playlists[indexPath.row]
            let _ = appDelegate.storage.main.library.createOrUpdateSearchHistory(container: playlist)
            performSegue(withIdentifier: Segues.toPlaylistDetail.rawValue, sender: playlist)
        case .Artist:
            let artist = self.artists[indexPath.row]
            let _ = appDelegate.storage.main.library.createOrUpdateSearchHistory(container: artist)
            performSegue(withIdentifier: Segues.toArtistDetail.rawValue, sender: artist)
        case .Album:
            let album = self.albums[indexPath.row]
            let _ = appDelegate.storage.main.library.createOrUpdateSearchHistory(container: album)
            performSegue(withIdentifier: Segues.toAlbumDetail.rawValue, sender: album)
        case .Song:
            let song = self.songs[indexPath.row]
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
    
    override func updateSearchResults(for searchController: UISearchController) {
        guard let searchText = searchController.searchBar.text else { return }
        if searchText.count > 0, searchController.searchBar.selectedScopeButtonIndex == 0 {
            firstly {
                self.appDelegate.librarySyncer.searchArtists(searchText: searchText)
            }.catch { error in
                self.appDelegate.eventLogger.report(topic: "Artists Search", error: error)
            }
            
            firstly {
                self.appDelegate.librarySyncer.searchAlbums(searchText: searchText)
            }.catch { error in
                self.appDelegate.eventLogger.report(topic: "Albums Search", error: error)
            }
            
            firstly {
                self.appDelegate.librarySyncer.searchSongs(searchText: searchText)
            }.catch { error in
                self.appDelegate.eventLogger.report(topic: "Songs Search", error: error)
            }

            appDelegate.storage.async.perform { asyncCompanion in
                let artists = asyncCompanion.library.searchArtists(searchText: searchText, onlyCached: false, displayFilter: .all)
                let albums = asyncCompanion.library.searchAlbums(searchText: searchText, onlyCached: false, displayFilter: .all)
                let playlists = asyncCompanion.library.searchPlaylists(searchText: searchText, playlistSearchCategory: .all)
                let songs = asyncCompanion.library.searchSongs(searchText: searchText, onlyCached: false, displayFilter: .all)
                
                let artistsIDs = FuzzySearcher.findBestMatch(in: artists, search: searchText)
                    .prefix(upToAsArray: Self.categoryItemLimit)
                    .compactMap{ $0 as? Artist }
                    .compactMap{ $0.managedObject.objectID }
                let albumsIDs = FuzzySearcher.findBestMatch(in: albums, search: searchText)
                    .prefix(upToAsArray: Self.categoryItemLimit)
                    .compactMap{ $0 as? Album }
                    .compactMap{ $0.managedObject.objectID }
                let playlistsIDs = FuzzySearcher.findBestMatch(in: playlists, search: searchText)
                    .prefix(upToAsArray: Self.categoryItemLimit)
                    .compactMap{ $0 as? Playlist }
                    .compactMap{ $0.managedObject.objectID }
                let songsIDs = FuzzySearcher.findBestMatch(in: songs, search: searchText)
                    .prefix(upToAsArray: Self.categoryItemLimit)
                    .compactMap{ $0 as? Song }
                    .compactMap{ $0.managedObject.objectID }
                
                DispatchQueue.main.async {
                    guard searchText == self.searchController.searchBar.text else { return }
                    self.isSearchActive = true
                    self.searchHistory = []
                    self.artists = artistsIDs
                        .compactMap{ self.appDelegate.storage.main.context.object(with: $0) as? ArtistMO }
                        .compactMap{ Artist(managedObject: $0) }
                    self.albums = albumsIDs
                        .compactMap{ self.appDelegate.storage.main.context.object(with: $0) as? AlbumMO }
                        .compactMap{ Album(managedObject: $0) }
                    self.playlists = playlistsIDs
                        .compactMap{ self.appDelegate.storage.main.context.object(with: $0) as? PlaylistMO }
                        .compactMap{ Playlist(library: self.appDelegate.storage.main.library, managedObject: $0) }
                    self.songs = songsIDs
                        .compactMap{ self.appDelegate.storage.main.context.object(with: $0) as? SongMO }
                        .compactMap{ Song(managedObject: $0) }
                    self.tableView.separatorStyle = .singleLine
                    self.updateDataSource(animated: false)
                }
            }.catch { error in }
        } else if searchText.count > 0, searchController.searchBar.selectedScopeButtonIndex == 1 {
            appDelegate.storage.async.perform { asyncCompanion in
                let artists = asyncCompanion.library.searchArtists(searchText: searchText, onlyCached: true, displayFilter: .all)
                let albums = asyncCompanion.library.searchAlbums(searchText: searchText, onlyCached: true, displayFilter: .all)
                let playlists = asyncCompanion.library.searchPlaylists(searchText: searchText, playlistSearchCategory: .cached)
                let songs = asyncCompanion.library.searchSongs(searchText: searchText, onlyCached: true, displayFilter: .all)
                
                let artistsIDs = FuzzySearcher.findBestMatch(in: artists, search: searchText)
                    .prefix(upToAsArray: Self.categoryItemLimit)
                    .compactMap{ $0 as? Artist }
                    .compactMap{ $0.managedObject.objectID }
                let albumsIDs = FuzzySearcher.findBestMatch(in: albums, search: searchText)
                    .prefix(upToAsArray: Self.categoryItemLimit)
                    .compactMap{ $0 as? Album }
                    .compactMap{ $0.managedObject.objectID }
                let playlistsIDs = FuzzySearcher.findBestMatch(in: playlists, search: searchText)
                    .prefix(upToAsArray: Self.categoryItemLimit)
                    .compactMap{ $0 as? Playlist }
                    .compactMap{ $0.managedObject.objectID }
                let songsIDs = FuzzySearcher.findBestMatch(in: songs, search: searchText)
                    .prefix(upToAsArray: Self.categoryItemLimit)
                    .compactMap{ $0 as? Song }
                    .compactMap{ $0.managedObject.objectID }
                
                DispatchQueue.main.async {
                    guard searchText == self.searchController.searchBar.text else { return }
                    self.isSearchActive = true
                    self.searchHistory = []
                    self.artists = artistsIDs
                        .compactMap{ self.appDelegate.storage.main.context.object(with: $0) as? ArtistMO }
                        .compactMap{ Artist(managedObject: $0) }
                    self.albums = albumsIDs
                        .compactMap{ self.appDelegate.storage.main.context.object(with: $0) as? AlbumMO }
                        .compactMap{ Album(managedObject: $0) }
                    self.playlists = playlistsIDs
                        .compactMap{ self.appDelegate.storage.main.context.object(with: $0) as? PlaylistMO }
                        .compactMap{ Playlist(library: self.appDelegate.storage.main.library, managedObject: $0) }
                    self.songs = songsIDs
                        .compactMap{ self.appDelegate.storage.main.context.object(with: $0) as? SongMO }
                        .compactMap{ Song(managedObject: $0) }
                    self.tableView.separatorStyle = .singleLine
                    self.updateDataSource(animated: false)
                }
            }.catch { error in }
        } else {
            isSearchActive = false
            self.searchHistory = appDelegate.storage.main.library.getSearchHistory()
            self.artists = []
            self.albums = []
            self.playlists = []
            self.songs = []
            tableView.separatorStyle = .singleLine
            self.updateDataSource(animated: false)
        }
    }
    
}
