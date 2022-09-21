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
import PromiseKit

class SongsVC: SingleFetchedResultsTableViewController<SongMO> {
    
    static let maxPlayAllSongsCount = 2000
    static let maxPlayRandomSongsCount = 500

    private var fetchedResultsController: SongsFetchedResultsController!
    private var optionsButton: UIBarButtonItem!
    private var sortButton: UIBarButtonItem!
    public var displayFilter: DisplayCategoryFilter = .all
    private var sortType: ElementSortType = .name
    private var filterTitle = "Songs"
    
    override func viewDidLoad() {
        super.viewDidLoad()
        appDelegate.userStatistics.visited(.songs)
        
        applyFilter()
        change(sortType: appDelegate.storage.settings.songsSortSetting)
        configureSearchController(placeholder: "Search in \"\(self.filterTitle)\"", scopeButtonTitles: ["All", "Cached"], showSearchBarAtEnter: false)
        tableView.register(nibName: SongTableCell.typeName)
        tableView.rowHeight = SongTableCell.rowHeight
        
        optionsButton = UIBarButtonItem(image: UIImage.ellipsis, style: .plain, target: self, action: #selector(optionsPressed))
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
    
    func applyFilter() {
        switch displayFilter {
        case .all:
            self.filterTitle = "Songs"
            self.isIndexTitelsHidden = false
        case .recentlyAdded:
            self.filterTitle = "Recent Songs"
            self.isIndexTitelsHidden = true
        case .favorites:
            self.filterTitle = "Favorite Songs"
            self.isIndexTitelsHidden = false
        }
        self.navigationItem.title = self.filterTitle
    }
    
    func change(sortType: ElementSortType) {
        self.sortType = sortType
        singleFetchedResultsController?.clearResults()
        tableView.reloadData()
        fetchedResultsController = SongsFetchedResultsController(coreDataCompanion: appDelegate.storage.main, sortType: sortType, isGroupedInAlphabeticSections: true)
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
            navigationItem.rightBarButtonItems = [optionsButton]
        } else {
            navigationItem.rightBarButtonItems = [optionsButton, sortButton]
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
                self.appDelegate.eventLogger.report(topic: "Recent Songs Sync", error: error)
            }.finally {
                self.updateSearchResults(for: self.searchController)
            }
        case .favorites:
            firstly {
                self.appDelegate.librarySyncer.syncFavoriteLibraryElements()
            }.catch { error in
                self.appDelegate.eventLogger.report(topic: "Favorite Songs Sync", error: error)
            }.finally {
                self.updateSearchResults(for: self.searchController)
            }
        }
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
            firstly {
                self.appDelegate.librarySyncer.searchSongs(searchText: searchText)
            }.catch { error in
                self.appDelegate.eventLogger.report(topic: "Songs Search", error: error)
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
                self.appDelegate.storage.settings.songsSortSetting = .name
                self.updateSearchResults(for: self.searchController)
            }))
        }
        if sortType != .rating {
            alert.addAction(UIAlertAction(title: "Sort by rating", style: .default, handler: { _ in
                self.change(sortType: .rating)
                self.appDelegate.storage.settings.songsSortSetting = .rating
                self.updateSearchResults(for: self.searchController)
            }))
        }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.pruneNegativeWidthConstraintsToAvoidFalseConstraintWarnings()
        alert.setOptionsForIPadToDisplayPopupCentricIn(view: self.view)
        present(alert, animated: true, completion: nil)
    }
    
    @objc private func optionsPressed() {
        let alert = UIAlertController(title: self.filterTitle, message: nil, preferredStyle: .actionSheet)

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
            let songs = self.appDelegate.storage.main.library.getSongs().filterCached(dependigOn: self.appDelegate.storage.settings.isOfflineMode)
            self.appDelegate.player.play(context: PlayContext(name: "Song Collection", playables: songs[randomPick: Self.maxPlayRandomSongsCount]))
        }))
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
            self.appDelegate.eventLogger.report(topic: "Songs Latest Elements Sync", error: error)
        }.finally {
            self.refreshControl?.endRefreshing()
        }
    }
    
}

