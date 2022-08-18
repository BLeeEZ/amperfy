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

class AlbumsVC: SingleFetchedResultsTableViewController<AlbumMO> {

    private var fetchedResultsController: AlbumFetchedResultsController!
    private var filterButton: UIBarButtonItem!
    private var sortButton: UIBarButtonItem!
    private var displayFilter: DisplayCategoryFilter = .all
    private var sortType: ElementSortType = .name
    
    override func viewDidLoad() {
        super.viewDidLoad()
        appDelegate.userStatistics.visited(.albums)
        
        change(sortType: appDelegate.persistentStorage.settings.albumsSortSetting)
        
        configureSearchController(placeholder: "Search in \"Albums\"", scopeButtonTitles: ["All", "Cached"], showSearchBarAtEnter: false)
        tableView.register(nibName: GenericTableCell.typeName)
        tableView.rowHeight = GenericTableCell.rowHeight
        
        filterButton = UIBarButtonItem(image: UIImage.filter, style: .plain, target: self, action: #selector(filterButtonPressed))
        sortButton = UIBarButtonItem(image: UIImage.sort, style: .plain, target: self, action: #selector(sortButtonPressed))
        navigationItem.rightBarButtonItems = [filterButton, sortButton]
        self.refreshControl?.addTarget(self, action: #selector(Self.handleRefresh), for: UIControl.Event.valueChanged)
        
        containableAtIndexPathCallback = { (indexPath) in
            return self.fetchedResultsController.getWrappedEntity(at: indexPath)
        }
        swipeCallback = { (indexPath, completionHandler) in
            let album = self.fetchedResultsController.getWrappedEntity(at: indexPath)
            album.fetchAsync(storage: self.appDelegate.persistentStorage, backendApi: self.appDelegate.backendApi, playableDownloadManager: self.appDelegate.playableDownloadManager) {
                completionHandler(SwipeActionContext(containable: album))
            }
        }
    }
    
    func change(sortType: ElementSortType) {
        self.sortType = sortType
        appDelegate.persistentStorage.settings.albumsSortSetting = sortType
        singleFetchedResultsController?.clearResults()
        tableView.reloadData()
        fetchedResultsController = AlbumFetchedResultsController(managedObjectContext: appDelegate.persistentStorage.context, sortType: sortType, isGroupedInAlphabeticSections: true)
        fetchedResultsController.fetchResultsController.sectionIndexType = sortType == .rating ? .rating : .alphabet
        singleFetchedResultsController = fetchedResultsController
        tableView.reloadData()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        updateFilterButton()
    }
    
    func updateFilterButton() {
        filterButton.image = displayFilter == .all ? UIImage.filter : UIImage.filterActive
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
            appDelegate.persistentStorage.persistentContainer.performBackgroundTask() { (context) in
                let backgroundLibrary = LibraryStorage(context: context)
                let syncer = self.appDelegate.backendApi.createLibrarySyncer()
                syncer.searchAlbums(searchText: searchText, library: backgroundLibrary)
            }
        }
        fetchedResultsController.search(searchText: searchText, onlyCached: searchController.searchBar.selectedScopeButtonIndex == 1, displayFilter: displayFilter)
        tableView.reloadData()
    }
    
    @objc private func sortButtonPressed() {
        let alert = UIAlertController(title: "Albums sorting", message: nil, preferredStyle: .actionSheet)
        if sortType != .name {
            alert.addAction(UIAlertAction(title: "Sort by name", style: .default, handler: { _ in
                self.change(sortType: .name)
                self.updateSearchResults(for: self.searchController)
            }))
        }
        if sortType != .rating {
            alert.addAction(UIAlertAction(title: "Sort by rating", style: .default, handler: { _ in
                self.change(sortType: .rating)
                self.updateSearchResults(for: self.searchController)
            }))
        }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.pruneNegativeWidthConstraintsToAvoidFalseConstraintWarnings()
        alert.setOptionsForIPadToDisplayPopupCentricIn(view: self.view)
        present(alert, animated: true, completion: nil)
    }
    
    @objc private func filterButtonPressed() {
        let alert = UIAlertController(title: "Albums filter", message: nil, preferredStyle: .actionSheet)
        
        if displayFilter != .favorites {
            alert.addAction(UIAlertAction(title: "Show favorites", image: UIImage.heartFill, style: .default, handler: { _ in
                self.displayFilter = .favorites
                self.updateFilterButton()
                self.updateSearchResults(for: self.searchController)
                if self.appDelegate.persistentStorage.settings.isOnlineMode {
                    self.appDelegate.persistentStorage.persistentContainer.performBackgroundTask() { (context) in
                        let syncLibrary = LibraryStorage(context: context)
                        let syncer = self.appDelegate.backendApi.createLibrarySyncer()
                        syncer.syncFavoriteLibraryElements(library: syncLibrary)
                        DispatchQueue.main.async {
                            self.updateSearchResults(for: self.searchController)
                        }
                    }
                }
            }))
        }
        if displayFilter != .recentlyAdded {
            alert.addAction(UIAlertAction(title: "Show recently added", image: UIImage.clock, style: .default, handler: { _ in
                self.displayFilter = .recentlyAdded
                self.updateFilterButton()
                self.updateSearchResults(for: self.searchController)
                if self.appDelegate.persistentStorage.settings.isOnlineMode {
                    self.appDelegate.persistentStorage.persistentContainer.performBackgroundTask() { (context) in
                        let autoDownloadSyncer = AutoDownloadLibrarySyncer(settings: self.appDelegate.persistentStorage.settings, backendApi: self.appDelegate.backendApi, playableDownloadManager: self.appDelegate.playableDownloadManager)
                        autoDownloadSyncer.syncLatestLibraryElements(context: context)
                        DispatchQueue.main.async {
                            self.updateSearchResults(for: self.searchController)
                        }
                    }
                }
            }))
        }
        if displayFilter != .all {
            alert.addAction(UIAlertAction(title: "Show all", style: .default, handler: { _ in
                self.displayFilter = .all
                self.updateFilterButton()
                self.updateSearchResults(for: self.searchController)
            }))
        }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.pruneNegativeWidthConstraintsToAvoidFalseConstraintWarnings()
        alert.setOptionsForIPadToDisplayPopupCentricIn(view: self.view)
        present(alert, animated: true, completion: nil)
    }
    
    @objc func handleRefresh(refreshControl: UIRefreshControl) {
        appDelegate.persistentStorage.persistentContainer.performBackgroundTask() { (context) in
            if self.appDelegate.persistentStorage.settings.isOnlineMode {
                let autoDownloadSyncer = AutoDownloadLibrarySyncer(settings: self.appDelegate.persistentStorage.settings, backendApi: self.appDelegate.backendApi, playableDownloadManager: self.appDelegate.playableDownloadManager)
                autoDownloadSyncer.syncLatestLibraryElements(context: context)
                DispatchQueue.main.async {
                    self.refreshControl?.endRefreshing()
                }
            } else {
                DispatchQueue.main.async {
                    self.refreshControl?.endRefreshing()
                }
            }

        }
    }
    
}

