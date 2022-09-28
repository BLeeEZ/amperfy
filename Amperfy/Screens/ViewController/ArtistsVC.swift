//
//  ArtistsVC.swift
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

class ArtistsVC: SingleFetchedResultsTableViewController<ArtistMO> {

    private var fetchedResultsController: ArtistFetchedResultsController!
    private var sortButton: UIBarButtonItem!
    public var displayFilter: DisplayCategoryFilter = .all
    private var sortType: ElementSortType = .name
    private var filterTitle = "Artists"
    
    override func viewDidLoad() {
        super.viewDidLoad()
        appDelegate.userStatistics.visited(.artists)
        
        applyFilter()
        change(sortType: appDelegate.storage.settings.artistsSortSetting)
        configureSearchController(placeholder: "Search in \"\(filterTitle)\"", scopeButtonTitles: ["All", "Cached"], showSearchBarAtEnter: false)
        tableView.register(nibName: GenericTableCell.typeName)
        tableView.rowHeight = GenericTableCell.rowHeight

        sortButton = UIBarButtonItem(image: UIImage.sort, style: .plain, target: self, action: #selector(sortButtonPressed))
        navigationItem.rightBarButtonItems = [sortButton]
        self.refreshControl?.addTarget(self, action: #selector(Self.handleRefresh), for: UIControl.Event.valueChanged)
        
        containableAtIndexPathCallback = { (indexPath) in
            return self.fetchedResultsController.getWrappedEntity(at: indexPath)
        }
        swipeCallback = { (indexPath, completionHandler) in
            let artist = self.fetchedResultsController.getWrappedEntity(at: indexPath)
            firstly {
                artist.fetch(storage: self.appDelegate.storage, librarySyncer: self.appDelegate.librarySyncer, playableDownloadManager: self.appDelegate.playableDownloadManager)
            }.catch { error in
                self.appDelegate.eventLogger.report(topic: "Artist Sync", error: error)
            }.finally {
                completionHandler(SwipeActionContext(containable: artist))
            }
        }
    }
    
    func applyFilter() {
        switch displayFilter {
        case .all:
            self.filterTitle = "Artists"
        case .recentlyAdded:
            self.filterTitle = "Recent Artists"
        case .favorites:
            self.filterTitle = "Favorite Artists"
        }
        self.navigationItem.title = self.filterTitle
    }
    
    func change(sortType: ElementSortType) {
        self.sortType = sortType
        appDelegate.storage.settings.artistsSortSetting = sortType
        singleFetchedResultsController?.clearResults()
        tableView.reloadData()
        fetchedResultsController = ArtistFetchedResultsController(coreDataCompanion: appDelegate.storage.main, sortType: sortType, isGroupedInAlphabeticSections: true)
        fetchedResultsController.fetchResultsController.sectionIndexType = sortType == .rating ? .rating : .alphabet
        singleFetchedResultsController = fetchedResultsController
        tableView.reloadData()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        updateFromRemote()
    }
    
    func updateFromRemote() {
        guard self.appDelegate.storage.settings.isOnlineMode else { return }
        switch displayFilter {
        case .all:
            break
        case .recentlyAdded:
            break
        case .favorites:
            firstly {
                self.appDelegate.librarySyncer.syncFavoriteLibraryElements()
            }.catch { error in
                self.appDelegate.eventLogger.report(topic: "Favorite Artists Sync", error: error)
            }.finally {
                self.updateSearchResults(for: self.searchController)
            }
        }
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell: GenericTableCell = dequeueCell(for: tableView, at: indexPath)
        let artist = fetchedResultsController.getWrappedEntity(at: indexPath)
        cell.display(container: artist, rootView: self)
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
        let artist = fetchedResultsController.getWrappedEntity(at: indexPath)
        performSegue(withIdentifier: Segues.toArtistDetail.rawValue, sender: artist)
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == Segues.toArtistDetail.rawValue {
            let vc = segue.destination as! ArtistDetailVC
            let artist = sender as? Artist
            vc.artist = artist
        }
    }
    
    override func updateSearchResults(for searchController: UISearchController) {
        let searchText = searchController.searchBar.text ?? ""
        fetchedResultsController.search(searchText: searchText, onlyCached: searchController.searchBar.selectedScopeButtonIndex == 1, displayFilter: displayFilter)
        tableView.reloadData()
        if searchText.count > 0, searchController.searchBar.selectedScopeButtonIndex == 0 {
            firstly {
                self.appDelegate.librarySyncer.searchArtists(searchText: searchText)
            }.catch { error in
                self.appDelegate.eventLogger.report(topic: "Artists Search", error: error)
            }
        }
    }
    
    @objc private func sortButtonPressed() {
        let alert = UIAlertController(title: "Artists sorting", message: nil, preferredStyle: .actionSheet)
        var action = UIAlertAction(title: "Sort by name", style: .default, handler: { _ in
            self.change(sortType: .name)
            self.updateSearchResults(for: self.searchController)
        })
        if sortType == .name {
            action.image = UIImage.check
        }
        alert.addAction(action)
        action = UIAlertAction(title: "Sort by rating", style: .default, handler: { _ in
            self.change(sortType: .rating)
            self.updateSearchResults(for: self.searchController)
        })
        if sortType == .rating {
            action.image = UIImage.check
        }
        alert.addAction(action)
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.popoverPresentationController?.barButtonItem = sortButton
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
            self.appDelegate.eventLogger.report(topic: "Artists Latest Elements Sync", error: error)
        }.finally {
            self.refreshControl?.endRefreshing()
        }
    }

}

