//
//  SongsVC.swift
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

class SongsVC: SingleFetchedResultsTableViewController<SongMO> {
    
    static let maxPlayAllSongsCount = 2000
    static let maxPlayRandomSongsCount = 500

    private var fetchedResultsController: SongsFetchedResultsController!
    private var optionsButton: UIBarButtonItem!
    private var filterButton: UIBarButtonItem!
    private var sortButton: UIBarButtonItem!
    private var displayFilter: DisplayCategoryFilter = .all
    private var sortType: ElementSortType = .name
    
    override func viewDidLoad() {
        super.viewDidLoad()
        appDelegate.userStatistics.visited(.songs)
        
        change(sortType: appDelegate.persistentStorage.settings.songsSortSetting)
        
        configureSearchController(placeholder: "Search in \"Songs\"", scopeButtonTitles: ["All", "Cached"], showSearchBarAtEnter: false)
        tableView.register(nibName: SongTableCell.typeName)
        tableView.rowHeight = SongTableCell.rowHeight
        
        optionsButton = UIBarButtonItem(image: UIImage.ellipsis, style: .plain, target: self, action: #selector(optionsPressed))
        filterButton = UIBarButtonItem(image: UIImage.filter, style: .plain, target: self, action: #selector(filterButtonPressed))
        sortButton = UIBarButtonItem(image: UIImage.sort, style: .plain, target: self, action: #selector(sortButtonPressed))
        self.refreshControl?.addTarget(self, action: #selector(Self.handleRefresh), for: UIControl.Event.valueChanged)
        
        containableAtIndexPathCallback = { (indexPath) in
            return self.fetchedResultsController.getWrappedEntity(at: indexPath)
        }
        swipeCallback = { (indexPath, completionHandler) in
            let song = self.fetchedResultsController.getWrappedEntity(at: indexPath)
            let playContext = self.convertIndexPathToPlayContext(songIndexPath: indexPath)
            completionHandler(SwipeActionContext(containable: song, playContext: playContext))
        }
    }
    
    func change(sortType: ElementSortType) {
        self.sortType = sortType
        appDelegate.persistentStorage.settings.songsSortSetting = sortType
        singleFetchedResultsController?.clearResults()
        tableView.reloadData()
        fetchedResultsController = SongsFetchedResultsController(managedObjectContext: appDelegate.persistentStorage.context, sortType: sortType, isGroupedInAlphabeticSections: true)
        fetchedResultsController.fetchResultsController.sectionIndexType = sortType == .rating ? .rating : .alphabet
        singleFetchedResultsController = fetchedResultsController
        tableView.reloadData()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        updateFilterButton()
        navigationItem.rightBarButtonItems = [optionsButton, filterButton, sortButton]
    }

    func updateFilterButton() {
        filterButton.image = displayFilter == .all ? UIImage.filter : UIImage.filterActive
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell: SongTableCell = dequeueCell(for: tableView, at: indexPath)
        let song = fetchedResultsController.getWrappedEntity(at: indexPath)
        cell.display(song: song, playContextCb: self.convertCellViewToPlayContext, rootView: self)
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
    
    func convertIndexPathToPlayContext(songIndexPath: IndexPath) -> PlayContext? {
        let song = fetchedResultsController.getWrappedEntity(at: songIndexPath)
        return PlayContext(containable: song)
    }
    
    func convertCellViewToPlayContext(cell: UITableViewCell) -> PlayContext? {
        guard let indexPath = tableView.indexPath(for: cell) else { return nil }
        return convertIndexPathToPlayContext(songIndexPath: indexPath)
    }
    
    override func updateSearchResults(for searchController: UISearchController) {
        guard let searchText = searchController.searchBar.text else { return }
        if searchText.count > 0, searchController.searchBar.selectedScopeButtonIndex == 0 {
            appDelegate.persistentStorage.persistentContainer.performBackgroundTask() { (context) in
                let backgroundLibrary = LibraryStorage(context: context)
                let syncer = self.appDelegate.backendApi.createLibrarySyncer()
                syncer.searchSongs(searchText: searchText, library: backgroundLibrary)
            }
            fetchedResultsController.search(searchText: searchText, onlyCachedSongs: false, displayFilter: displayFilter)
        } else if searchController.searchBar.selectedScopeButtonIndex == 1 {
            fetchedResultsController.search(searchText: searchText, onlyCachedSongs: true, displayFilter: displayFilter)
        } else if displayFilter != .all {
            fetchedResultsController.search(searchText: searchText, onlyCachedSongs: searchController.searchBar.selectedScopeButtonIndex == 1, displayFilter: displayFilter)
        } else {
            fetchedResultsController.showAllResults()
        }
        tableView.reloadData()
    }
    
    @objc private func sortButtonPressed() {
        let alert = UIAlertController(title: "Songs sorting", message: nil, preferredStyle: .actionSheet)
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
        let alert = UIAlertController(title: "Songs filter", message: nil, preferredStyle: .actionSheet)
        
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
    
    @objc private func optionsPressed() {
        let alert = UIAlertController(title: "Songs", message: nil, preferredStyle: .actionSheet)

        alert.addAction(UIAlertAction(title: "Play all displayed songs", style: .default, handler: { _ in
            guard let displayedSongsMO = self.fetchedResultsController.fetchedObjects else { return }
            let displayedSongs = displayedSongsMO.compactMap{ Song(managedObject: $0) }
            guard displayedSongs.count > 0 else { return }
            if displayedSongs.count > Self.maxPlayAllSongsCount {
                let toManySongsAlert = UIAlertController(title: "Too many songs", message: nil, preferredStyle: .actionSheet)
                toManySongsAlert.addAction(UIAlertAction(title: "Play the first \(Self.maxPlayAllSongsCount) songs", style: .default, handler: { _ in
                    self.appDelegate.player.play(context: PlayContext(name: "Song Collection", playables: Array(displayedSongs.prefix(Self.maxPlayAllSongsCount))))
                }))
                toManySongsAlert.addAction(UIAlertAction(title: "Play the last \(Self.maxPlayAllSongsCount) songs", style: .default, handler: { _ in
                    self.appDelegate.player.play(context: PlayContext(name: "Song Collection", playables: Array(displayedSongs[(displayedSongs.count-Self.maxPlayAllSongsCount)...])))
                }))
                toManySongsAlert.addAction(UIAlertAction(title: "Play \(Self.maxPlayAllSongsCount) random songs from collection", style: .default, handler: { _ in
                    self.appDelegate.player.play(context: PlayContext(name: "Song Collection", playables: displayedSongs[randomPick: Self.maxPlayAllSongsCount]))
                }))
                toManySongsAlert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
                toManySongsAlert.pruneNegativeWidthConstraintsToAvoidFalseConstraintWarnings()
                toManySongsAlert.setOptionsForIPadToDisplayPopupCentricIn(view: self.view)
                self.present(toManySongsAlert, animated: true, completion: nil)
                
            } else {
                self.appDelegate.player.play(context: PlayContext(name: "Song Collection", playables: displayedSongs))
            }
        }))
        alert.addAction(UIAlertAction(title: "Play random songs", style: .default, handler: { _ in
            let songs = self.appDelegate.library.getSongs().filterCached(dependigOn: self.appDelegate.persistentStorage.settings.isOfflineMode)
            self.appDelegate.player.play(context: PlayContext(name: "Song Collection", playables: songs[randomPick: Self.maxPlayRandomSongsCount]))
        }))
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

