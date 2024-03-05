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

class SearchVC: MultiSourceTableViewController {
    
    private static let fetchLimit = 10
    
    private var searchHistoryFetchedResultsController: SearchHistoryFetchedResultsController!
    private var artistFetchedResultsController: ArtistFetchedResultsController!
    private var albumFetchedResultsController: AlbumFetchedResultsController!
    private var playlistFetchedResultsController: PlaylistFetchedResultsController!
    private var songFetchedResultsController: SongsFetchedResultsController!
    
    private var optionsButton: UIBarButtonItem!
    private var isSearchActive = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        searchHistoryFetchedResultsController = SearchHistoryFetchedResultsController(
            coreDataCompanion: appDelegate.storage.main)
        playlistFetchedResultsController = PlaylistFetchedResultsController(
            coreDataCompanion: appDelegate.storage.main,
            sortType: .name,
            isGroupedInAlphabeticSections: false,
            fetchLimit: Self.fetchLimit)
        artistFetchedResultsController = ArtistFetchedResultsController(
            coreDataCompanion: appDelegate.storage.main,
            sortType: .name,
            isGroupedInAlphabeticSections: false,
            fetchLimit: Self.fetchLimit)
        albumFetchedResultsController = AlbumFetchedResultsController(
            coreDataCompanion: appDelegate.storage.main,
            sortType: .name,
            isGroupedInAlphabeticSections: false,
            fetchLimit: Self.fetchLimit)
        songFetchedResultsController = SongsFetchedResultsController(
            coreDataCompanion: appDelegate.storage.main,
            sortType: .name,
            isGroupedInAlphabeticSections: false,
            fetchLimit: Self.fetchLimit)
        
        configureSearchController(placeholder: "Playlists, Songs and more", scopeButtonTitles: ["All", "Cached"], showSearchBarAtEnter: true)
        tableView.register(nibName: PlaylistTableCell.typeName)
        tableView.register(nibName: GenericTableCell.typeName)
        tableView.register(nibName: GenericTableCell.typeName)
        tableView.register(nibName: PlayableTableCell.typeName)
        tableView.separatorStyle = .none
        tableView.sectionHeaderTopPadding = 0
        
        optionsButton = OptionsBarButton()
        optionsButton.menu = UIMenu(children: [
            UIAction(title: "Clear Search History", image: .clear, handler: { _ in
                self.appDelegate.storage.main.library.deleteSearchHistory()
                self.appDelegate.storage.main.library.saveContext()
                self.searchHistoryFetchedResultsController.fetch()
                self.tableView.reloadSections(IndexSet(integer: SearchSection.History.rawValue), with: .fade)
            })
        ])
        navigationItem.rightBarButtonItem = optionsButton
        
        containableAtIndexPathCallback = { (indexPath) in
            switch SearchSection(rawValue: indexPath.section) {
            case .History:
                return self.searchHistoryFetchedResultsController.getWrappedEntity(at: IndexPath(row: indexPath.row, section: 0)).searchedPlayableContainable
            case .Playlist:
                return self.playlistFetchedResultsController.getWrappedEntity(at: IndexPath(row: indexPath.row, section: 0))
            case .Artist:
                return self.artistFetchedResultsController.getWrappedEntity(at: IndexPath(row: indexPath.row, section: 0))
            case .Album:
                return self.albumFetchedResultsController.getWrappedEntity(at: IndexPath(row: indexPath.row, section: 0))
            case .Song:
                return self.songFetchedResultsController.getWrappedEntity(at: IndexPath(row: indexPath.row, section: 0))
            case .none:
                return nil
            }
        }
        playContextAtIndexPathCallback = { (indexPath) in
            switch SearchSection(rawValue: indexPath.section) {
            case .History:
                let history = self.searchHistoryFetchedResultsController.getWrappedEntity(at: IndexPath(row: indexPath.row, section: 0))
                guard let container = history.searchedPlayableContainable else { return nil }
                return PlayContext(containable: container)
            case .Playlist:
                let entity = self.playlistFetchedResultsController.getWrappedEntity(at: IndexPath(row: indexPath.row, section: 0))
                return PlayContext(containable: entity)
            case .Artist:
                let entity = self.artistFetchedResultsController.getWrappedEntity(at: IndexPath(row: indexPath.row, section: 0))
                return PlayContext(containable: entity)
            case .Album:
                let entity = self.albumFetchedResultsController.getWrappedEntity(at: IndexPath(row: indexPath.row, section: 0))
                return PlayContext(containable: entity)
            case .Song:
                let entity = self.songFetchedResultsController.getWrappedEntity(at: IndexPath(row: indexPath.row, section: 0))
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
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        appDelegate.userStatistics.visited(.search)
    }

    public func activateSearchBar() {
        if self.isViewLoaded {
            // activate searchBar
            self.searchController.searchBar.becomeFirstResponder()
        }
    }
    
    func determSwipeActionContext(at indexPath: IndexPath, completionHandler: @escaping (_ actionContext: SwipeActionContext?) -> Void) {
        switch SearchSection(rawValue: indexPath.section) {
        case .History:
            let history = searchHistoryFetchedResultsController.getWrappedEntity(at: IndexPath(row: indexPath.row, section: 0))
            guard let container = history.searchedPlayableContainable else { completionHandler(nil); return }
            firstly {
                container.fetch(storage: self.appDelegate.storage, librarySyncer: self.appDelegate.librarySyncer, playableDownloadManager: self.appDelegate.playableDownloadManager)
            }.catch { error in
                self.appDelegate.eventLogger.report(topic: "History Sync", error: error)
            }.finally {
                completionHandler(SwipeActionContext(containable: container))
            }
        case .Playlist:
            let playlist = playlistFetchedResultsController.getWrappedEntity(at: IndexPath(row: indexPath.row, section: 0))
            firstly {
                playlist.fetch(storage: self.appDelegate.storage, librarySyncer: self.appDelegate.librarySyncer, playableDownloadManager: self.appDelegate.playableDownloadManager)
            }.catch { error in
                self.appDelegate.eventLogger.report(topic: "Playlist Sync", error: error)
            }.finally {
                completionHandler(SwipeActionContext(containable: playlist))
            }
        case .Artist:
            let artist = artistFetchedResultsController.getWrappedEntity(at: IndexPath(row: indexPath.row, section: 0))
            firstly {
                artist.fetch(storage: self.appDelegate.storage, librarySyncer: self.appDelegate.librarySyncer, playableDownloadManager: self.appDelegate.playableDownloadManager)
            }.catch { error in
                self.appDelegate.eventLogger.report(topic: "Artist Sync", error: error)
            }.finally {
                completionHandler(SwipeActionContext(containable: artist))
            }
        case .Album:
            let album = albumFetchedResultsController.getWrappedEntity(at: IndexPath(row: indexPath.row, section: 0))
            firstly {
                album.fetch(storage: self.appDelegate.storage, librarySyncer: self.appDelegate.librarySyncer, playableDownloadManager: self.appDelegate.playableDownloadManager)
            }.catch { error in
                self.appDelegate.eventLogger.report(topic: "Album Sync", error: error)
            }.finally {
                completionHandler(SwipeActionContext(containable: album))
            }
        case .Song:
            let song = songFetchedResultsController.getWrappedEntity(at: IndexPath(row: indexPath.row, section: 0))
            completionHandler(SwipeActionContext(containable: song))
        case .none:
            completionHandler(nil)
        }
    }

    func convertCellViewToPlayContext(cell: UITableViewCell) -> PlayContext? {
        guard let indexPath = tableView.indexPath(for: cell) else { return nil }
        if SearchSection(rawValue: indexPath.section) == .Song {
            let song = songFetchedResultsController.getWrappedEntity(at: IndexPath(row: indexPath.row, section: 0))
            return PlayContext(containable: song)
        } else if SearchSection(rawValue: indexPath.section) == .History {
            let history = searchHistoryFetchedResultsController.getWrappedEntity(at: IndexPath(row: indexPath.row, section: 0))
            guard let song = history.searchedPlayableContainable as? Song else { return nil }
            return PlayContext(containable: song)
        }
        return nil
    }

    // MARK: - Table view data source
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return SearchSection.allCases.count
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch SearchSection(rawValue: section) {
        case .History:
            if searchHistoryFetchedResultsController.fetchedObjects?.isEmpty ?? true {
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

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch SearchSection(rawValue: section) {
        case .History:
            return searchHistoryFetchedResultsController.sections?[0].numberOfObjects ?? 0
        case .Playlist:
            return playlistFetchedResultsController.sections?[0].numberOfObjects ?? 0
        case .Artist:
            return artistFetchedResultsController.sections?[0].numberOfObjects ?? 0
        case .Album:
            return albumFetchedResultsController.sections?[0].numberOfObjects ?? 0
        case .Song:
            return songFetchedResultsController.sections?[0].numberOfObjects ?? 0
        case .none:
            return 0
        }
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch SearchSection(rawValue: indexPath.section) {
        case .History:
            let history = searchHistoryFetchedResultsController.getWrappedEntity(at: IndexPath(row: indexPath.row, section: 0))
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
            let playlist = playlistFetchedResultsController.getWrappedEntity(at: IndexPath(row: indexPath.row, section: 0))
            cell.display(playlist: playlist, rootView: self)
            cell.accessoryType = .disclosureIndicator
            return cell
        case .Artist:
            let cell: GenericTableCell = dequeueCell(for: tableView, at: indexPath)
            let artist = artistFetchedResultsController.getWrappedEntity(at: IndexPath(row: indexPath.row, section: 0))
            cell.display(container: artist, rootView: self)
            cell.accessoryType = .disclosureIndicator
            return cell
        case .Album:
            let cell: GenericTableCell = dequeueCell(for: tableView, at: indexPath)
            let album = albumFetchedResultsController.getWrappedEntity(at: IndexPath(row: indexPath.row, section: 0))
            cell.display(container: album, rootView: self)
            cell.accessoryType = .disclosureIndicator
            return cell
        case .Song:
            let cell: PlayableTableCell = dequeueCell(for: tableView, at: indexPath)
            let song = songFetchedResultsController.getWrappedEntity(at: IndexPath(row: indexPath.row, section: 0))
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
            return playlistFetchedResultsController.sections?[0].numberOfObjects ?? 0 > 0 ? CommonScreenOperations.tableSectionHeightLarge : 0
        case .Artist:
            return artistFetchedResultsController.sections?[0].numberOfObjects ?? 0 > 0 ? CommonScreenOperations.tableSectionHeightLarge : 0
        case .Album:
            return albumFetchedResultsController.sections?[0].numberOfObjects ?? 0 > 0 ? CommonScreenOperations.tableSectionHeightLarge : 0
        case .Song:
            return songFetchedResultsController.sections?[0].numberOfObjects ?? 0 > 0 ? CommonScreenOperations.tableSectionHeightLarge : 0
        case .none:
            return 0.0
        }
    }
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        switch SearchSection(rawValue: indexPath.section) {
        case .History:
            let history = searchHistoryFetchedResultsController.getWrappedEntity(at: IndexPath(row: indexPath.row, section: 0))
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
            let history = searchHistoryFetchedResultsController.getWrappedEntity(at: IndexPath(row: indexPath.row, section: 0))
            guard let container = history.searchedPlayableContainable else { break }
            let _ = appDelegate.storage.main.library.createOrUpdateSearchHistory(container: container)
            if !(container is Song) {
                EntityPreviewActionBuilder(container: container, on: self).performPreviewTransition()
            }
        case .Playlist:
            let playlist = playlistFetchedResultsController.getWrappedEntity(at: IndexPath(row: indexPath.row, section: 0))
            let _ = appDelegate.storage.main.library.createOrUpdateSearchHistory(container: playlist)
            performSegue(withIdentifier: Segues.toPlaylistDetail.rawValue, sender: playlist)
        case .Artist:
            let artist = artistFetchedResultsController.getWrappedEntity(at: IndexPath(row: indexPath.row, section: 0))
            let _ = appDelegate.storage.main.library.createOrUpdateSearchHistory(container: artist)
            performSegue(withIdentifier: Segues.toArtistDetail.rawValue, sender: artist)
        case .Album:
            let album = albumFetchedResultsController.getWrappedEntity(at: IndexPath(row: indexPath.row, section: 0))
            let _ = appDelegate.storage.main.library.createOrUpdateSearchHistory(container: album)
            performSegue(withIdentifier: Segues.toAlbumDetail.rawValue, sender: album)
        case .Song:
            let song = songFetchedResultsController.getWrappedEntity(at: IndexPath(row: indexPath.row, section: 0))
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
            isSearchActive = true
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

            searchHistoryFetchedResultsController.clearResults()
            playlistFetchedResultsController.search(searchText: searchText, playlistSearchCategory: .all)
            artistFetchedResultsController.search(searchText: searchText, onlyCached: false, displayFilter: .all)
            albumFetchedResultsController.search(searchText: searchText, onlyCached: false, displayFilter: .all)
            songFetchedResultsController.search(searchText: searchText, onlyCachedSongs: false, displayFilter: .all)
            tableView.separatorStyle = .singleLine
        } else if searchText.count > 0, searchController.searchBar.selectedScopeButtonIndex == 1 {
            isSearchActive = true
            searchHistoryFetchedResultsController.clearResults()
            playlistFetchedResultsController.search(searchText: searchText, playlistSearchCategory: .cached)
            artistFetchedResultsController.search(searchText: searchText, onlyCached: true, displayFilter: .all)
            albumFetchedResultsController.search(searchText: searchText, onlyCached: true, displayFilter: .all)
            songFetchedResultsController.search(searchText: searchText, onlyCachedSongs: true, displayFilter: .all)
            tableView.separatorStyle = .singleLine
        } else {
            isSearchActive = false
            searchHistoryFetchedResultsController.showAllResults()
            playlistFetchedResultsController.clearResults()
            artistFetchedResultsController.hideResults()
            albumFetchedResultsController.hideResults()
            songFetchedResultsController.hideResults()
            tableView.separatorStyle = .singleLine
        }
        tableView.reloadData()
    }
    
    override func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange anObject: Any, at indexPath: IndexPath?, for type: NSFetchedResultsChangeType, newIndexPath: IndexPath?) {
        var section: Int = 0
        switch controller {
        case playlistFetchedResultsController.fetchResultsController:
            section = SearchSection.Playlist.rawValue
        case artistFetchedResultsController.fetchResultsController:
            section = SearchSection.Artist.rawValue
        case albumFetchedResultsController.fetchResultsController:
            section = SearchSection.Album.rawValue
        case songFetchedResultsController.fetchResultsController:
            section = SearchSection.Song.rawValue
        default:
            return
        }
        
        resultUpdateHandler?.applyChangesOfMultiRowType(controller, didChange: anObject, determinedSection: section, at: indexPath, for: type, newIndexPath: newIndexPath)
    }
    
    override func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange sectionInfo: NSFetchedResultsSectionInfo, atSectionIndex sectionIndex: Int, for type: NSFetchedResultsChangeType) {
    }
    
}
