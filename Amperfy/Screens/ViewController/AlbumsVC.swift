//
//  AlbumsVC.swift
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

class AlbumsVC: SingleFetchedResultsTableViewController<AlbumMO> {

    private var fetchedResultsController: AlbumFetchedResultsController!
    private var sortButton: UIBarButtonItem!
    public var displayFilter: DisplayCategoryFilter = .all
    private var sortType: ElementSortType = .name
    private var filterTitle = "Albums"
    
    override func viewDidLoad() {
        super.viewDidLoad()
        appDelegate.userStatistics.visited(.albums)

        applyFilter()
        change(sortType: appDelegate.storage.settings.albumsSortSetting)
        configureSearchController(placeholder: "Search in \"\(filterTitle)\"", scopeButtonTitles: ["All", "Cached"], showSearchBarAtEnter: false)
        tableView.register(nibName: GenericTableCell.typeName)
        tableView.rowHeight = GenericTableCell.rowHeight
        
        tableView.tableHeaderView = UIView(frame: CGRect(x: 0, y: 0, width: view.bounds.size.width, height: LibraryElementDetailTableHeaderView.frameHeight))
        if let libraryElementDetailTableHeaderView = ViewBuilder<LibraryElementDetailTableHeaderView>.createFromNib(withinFixedFrame: CGRect(x: 0, y: 0, width: view.bounds.size.width, height: LibraryElementDetailTableHeaderView.frameHeight)) {
            libraryElementDetailTableHeaderView.prepare(
                playContextCb: self.handleHeaderPlay,
                with: appDelegate.player,
                shuffleContextCb: self.handleHeaderShuffle)
            tableView.tableHeaderView?.addSubview(libraryElementDetailTableHeaderView)
        }
        
        sortButton = UIBarButtonItem(image: UIImage.sort, style: .plain, target: self, action: #selector(sortButtonPressed))
        self.refreshControl?.addTarget(self, action: #selector(Self.handleRefresh), for: UIControl.Event.valueChanged)
        
        containableAtIndexPathCallback = { (indexPath) in
            return self.fetchedResultsController.getWrappedEntity(at: indexPath)
        }
        swipeCallback = { (indexPath, completionHandler) in
            let album = self.fetchedResultsController.getWrappedEntity(at: indexPath)
            firstly {
                album.fetch(storage: self.appDelegate.storage, librarySyncer: self.appDelegate.librarySyncer, playableDownloadManager: self.appDelegate.playableDownloadManager)
            }.catch { error in
                self.appDelegate.eventLogger.report(topic: "Album Sync", error: error)
            }.finally {
                completionHandler(SwipeActionContext(containable: album))
            }
        }
    }
    
    func applyFilter() {
        switch displayFilter {
        case .all:
            self.filterTitle = "Albums"
            self.isIndexTitelsHidden = false
        case .recentlyAdded:
            self.filterTitle = "Recent Albums"
            self.isIndexTitelsHidden = true
        case .favorites:
            self.filterTitle = "Favorite Albums"
            self.isIndexTitelsHidden = false
        }
        self.navigationItem.title = self.filterTitle
    }
    
    func change(sortType: ElementSortType) {
        self.sortType = sortType
        singleFetchedResultsController?.clearResults()
        tableView.reloadData()
        fetchedResultsController = AlbumFetchedResultsController(coreDataCompanion: appDelegate.storage.main, sortType: sortType, isGroupedInAlphabeticSections: true)
        fetchedResultsController.fetchResultsController.sectionIndexType = sortType.asSectionIndexType
        singleFetchedResultsController = fetchedResultsController
        tableView.reloadData()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        updateRightBarButtonItems()
        updateFromRemote()
    }
    
    func updateRightBarButtonItems() {
        if sortType == .recentlyAddedIndex {
            navigationItem.rightBarButtonItems = []
        } else {
            navigationItem.rightBarButtonItems = [sortButton]
        }
    }
    
    func updateFromRemote() {
        guard self.appDelegate.storage.settings.isOnlineMode else { return }
        switch displayFilter {
        case .all:
            break
        case .recentlyAdded:
            firstly {
                AutoDownloadLibrarySyncer(storage: self.appDelegate.storage, librarySyncer: self.appDelegate.librarySyncer, playableDownloadManager: self.appDelegate.playableDownloadManager)
                    .syncLatestLibraryElements()
            }.catch { error in
                self.appDelegate.eventLogger.report(topic: "Recent Albums Sync", error: error)
            }.finally {
                self.updateSearchResults(for: self.searchController)
            }
        case .favorites:
            firstly {
                self.appDelegate.librarySyncer.syncFavoriteLibraryElements()
            }.catch { error in
                self.appDelegate.eventLogger.report(topic: "Favorite Albums Sync", error: error)
            }.finally {
                self.updateSearchResults(for: self.searchController)
            }
        }
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell: GenericTableCell = dequeueCell(for: tableView, at: indexPath)
        let album = fetchedResultsController.getWrappedEntity(at: indexPath)
        cell.display(container: album, rootView: self)
        return cell
    }
    
    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        switch sortType {
        case .name:
            return 0.0
        case .rating:
            return CommonScreenOperations.tableSectionHeightLarge
        case .recentlyAddedIndex:
            return 0.0
        }
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch sortType {
        case .name:
            return super.tableView(tableView, titleForHeaderInSection: section)
        case .rating:
            if let sectionNameInitial = super.tableView(tableView, titleForHeaderInSection: section), sectionNameInitial != SectionIndexType.noRatingIndexSymbol {
                return "\(sectionNameInitial) Star\(sectionNameInitial != "1" ? "s" : "")"
            } else {
                return "Not rated"
            }
        case .recentlyAddedIndex:
            return super.tableView(tableView, titleForHeaderInSection: section)
        }
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let album = fetchedResultsController.getWrappedEntity(at: indexPath)
        performSegue(withIdentifier: Segues.toAlbumDetail.rawValue, sender: album)
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == Segues.toAlbumDetail.rawValue {
            let vc = segue.destination as! AlbumDetailVC
            let album = sender as? Album
            vc.album = album
        }
    }
    
    override func updateSearchResults(for searchController: UISearchController) {
        let searchText = searchController.searchBar.text ?? ""
        if searchText.count > 0, searchController.searchBar.selectedScopeButtonIndex == 0 {
            firstly {
                self.appDelegate.librarySyncer.searchAlbums(searchText: searchText)
            }.catch { error in
                self.appDelegate.eventLogger.report(topic: "Albums Search", error: error)
            }
        }
        fetchedResultsController.search(searchText: searchText, onlyCached: searchController.searchBar.selectedScopeButtonIndex == 1, displayFilter: displayFilter)
        tableView.reloadData()
    }
    
    private var displayedSongs: [AbstractPlayable] {
        guard let displayedAlbumsMO = self.fetchedResultsController.fetchedObjects else { return [] }
        let displayedAlbums = displayedAlbumsMO.compactMap{ Album(managedObject: $0) }
        var songs = [AbstractPlayable]()
        displayedAlbums.forEach { songs.append(contentsOf: $0.playables) }
        return songs
    }
    
    private func handleHeaderPlay() -> PlayContext {
        let songs = displayedSongs
        if songs.count > appDelegate.player.maxSongsToAddOnce {
            return PlayContext(name: filterTitle, playables: Array(songs.prefix(appDelegate.player.maxSongsToAddOnce)))
        } else {
            return PlayContext(name: filterTitle, playables: songs)
        }
    }
    
    private func handleHeaderShuffle() -> PlayContext {
        let songs = displayedSongs
        if songs.count > appDelegate.player.maxSongsToAddOnce {
            return PlayContext(name: filterTitle, playables: songs[randomPick: appDelegate.player.maxSongsToAddOnce])
        } else {
            return PlayContext(name: filterTitle, playables: songs)
        }
    }
    
    @objc private func sortButtonPressed() {
        let alert = UIAlertController(title: "Albums sorting", message: nil, preferredStyle: .actionSheet)
        if sortType != .name {
            alert.addAction(UIAlertAction(title: "Sort by name", style: .default, handler: { _ in
                self.change(sortType: .name)
                self.appDelegate.storage.settings.albumsSortSetting = .name
                self.updateSearchResults(for: self.searchController)
            }))
        }
        if sortType != .rating {
            alert.addAction(UIAlertAction(title: "Sort by rating", style: .default, handler: { _ in
                self.change(sortType: .rating)
                self.appDelegate.storage.settings.albumsSortSetting = .rating
                self.updateSearchResults(for: self.searchController)
            }))
        }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.pruneNegativeWidthConstraintsToAvoidFalseConstraintWarnings()
        alert.setOptionsForIPadToDisplayPopupCentricIn(view: self.view)
        present(alert, animated: true, completion: nil)
    }
    
    @objc func handleRefresh(refreshControl: UIRefreshControl) {
        guard self.appDelegate.storage.settings.isOnlineMode else {
            self.refreshControl?.endRefreshing()
            return
        }
        firstly {
            AutoDownloadLibrarySyncer(storage: self.appDelegate.storage, librarySyncer: self.appDelegate.librarySyncer, playableDownloadManager: self.appDelegate.playableDownloadManager)
                .syncLatestLibraryElements()
        }.catch { error in
            self.appDelegate.eventLogger.report(topic: "Albums Latest Elements Sync", error: error)
        }.finally {
            self.refreshControl?.endRefreshing()
        }
    }
    
}

