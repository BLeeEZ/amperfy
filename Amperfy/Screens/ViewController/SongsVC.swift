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
    
    override var sceneTitle: String? { "Library" }

    private var fetchedResultsController: SongsFetchedResultsController!
    private var optionsButton: UIBarButtonItem!
    public var displayFilter: DisplayCategoryFilter = .all
    private var sortType: SongElementSortType = .name
    private var filterTitle = "Songs"
    
    override func viewDidLoad() {
        super.viewDidLoad()

        #if !targetEnvironment(macCatalyst)
        self.refreshControl = UIRefreshControl()
        #endif

        appDelegate.userStatistics.visited(.songs)
        
        optionsButton = OptionsBarButton()

        applyFilter()
        configureSearchController(placeholder: "Search in \"\(self.filterTitle)\"", scopeButtonTitles: ["All", "Cached"], showSearchBarAtEnter: true)
        tableView.register(nibName: PlayableTableCell.typeName)
        tableView.rowHeight = PlayableTableCell.rowHeight
        tableView.estimatedRowHeight = PlayableTableCell.rowHeight

        let playShuffleInfoConfig = PlayShuffleInfoConfiguration(
            infoCB: { "\(self.fetchedResultsController.fetchedObjects?.count ?? 0) Song\((self.fetchedResultsController.fetchedObjects?.count ?? 0) == 1 ? "" : "s")" },
            playContextCb: self.handleHeaderPlay,
            player: appDelegate.player,
            isInfoAlwaysHidden: false,
            shuffleContextCb: self.handleHeaderShuffle)
        _ = LibraryElementDetailTableHeaderView.createTableHeader(rootView: self, configuration: playShuffleInfoConfig)
        #if !targetEnvironment(macCatalyst)
        self.refreshControl?.addTarget(self, action: #selector(Self.handleRefresh), for: UIControl.Event.valueChanged)
        #endif

        containableAtIndexPathCallback = { (indexPath) in
            return self.fetchedResultsController.getWrappedEntity(at: indexPath)
        }
        playContextAtIndexPathCallback = convertIndexPathToPlayContext
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
            change(sortType: appDelegate.storage.settings.songsSortSetting)
        case .newest, .recent:
            break
        case .favorites:
            self.filterTitle = "Favorite Songs"
            self.isIndexTitelsHidden = false
            change(sortType: appDelegate.storage.settings.songsSortSetting)
        }
        setNavBarTitle(title: self.filterTitle)
    }
    
    func change(sortType: SongElementSortType) {
        self.sortType = sortType
        singleFetchedResultsController?.clearResults()
        tableView.reloadData()
        fetchedResultsController = SongsFetchedResultsController(coreDataCompanion: appDelegate.storage.main, sortType: sortType, isGroupedInAlphabeticSections: true)
        fetchedResultsController.fetchResultsController.sectionIndexType = sortType.asSectionIndexType
        singleFetchedResultsController = fetchedResultsController
        tableView.reloadData()
        updateRightBarButtonItems()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        updateRightBarButtonItems()
        updateFromRemote()
    }
    
    func updateRightBarButtonItems() {
        var actions = [UIMenu]()
        actions.append(createSortButtonMenu())
        if appDelegate.storage.settings.isOnlineMode {
            actions.append(createActionButtonMenu())
        }
        optionsButton.menu = UIMenu(children: actions)
        navigationItem.rightBarButtonItems = [optionsButton]
    }
    
    func updateFromRemote() {
        guard self.appDelegate.storage.settings.isOnlineMode else { return }
        switch displayFilter {
        case .all:
            break
        case .newest, .recent:
            break
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
        let cell: PlayableTableCell = dequeueCell(for: tableView, at: indexPath)
        let song = fetchedResultsController.getWrappedEntity(at: indexPath)
        cell.display(playable: song, playContextCb: self.convertCellViewToPlayContext, rootView: self)
        return cell
    }
    
    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        switch sortType {
        case .name:
            return 0.0
        case .rating:
            return CommonScreenOperations.tableSectionHeightLarge
        case .duration:
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
        case .duration:
            return nil
        }
    }
    
    func convertIndexPathToPlayContext(songIndexPath: IndexPath) -> PlayContext {
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
    
    private func handleHeaderPlay() -> PlayContext {
        guard let displayedSongsMO = self.fetchedResultsController.fetchedObjects else { return PlayContext(name: filterTitle, playables: []) }
        if displayedSongsMO.count > appDelegate.player.maxSongsToAddOnce {
            let songsToPlay = displayedSongsMO.prefix(appDelegate.player.maxSongsToAddOnce).compactMap{ Song(managedObject: $0) }
            return PlayContext(name: filterTitle, playables: songsToPlay)
        } else {
            let songsToPlay = displayedSongsMO.compactMap{ Song(managedObject: $0) }
            return PlayContext(name: filterTitle, playables: songsToPlay)
        }
    }
    
    private func handleHeaderShuffle() -> PlayContext {
        guard let displayedSongsMO = self.fetchedResultsController.fetchedObjects else { return PlayContext(name: filterTitle, playables: []) }
        if displayedSongsMO.count > appDelegate.player.maxSongsToAddOnce {
            let songsToPlay = displayedSongsMO[randomPick: appDelegate.player.maxSongsToAddOnce].compactMap{ Song(managedObject: $0) }
            return PlayContext(name: filterTitle, playables: songsToPlay)
        } else {
            let songsToPlay = displayedSongsMO.compactMap{ Song(managedObject: $0) }
            return PlayContext(name: filterTitle, playables: songsToPlay)
        }
    }
    
    private func createSortButtonMenu() -> UIMenu {
        let sortByName = UIAction(title: "Name", image: sortType == .name ? .check : nil, handler: { _ in
            self.change(sortType: .name)
            self.appDelegate.storage.settings.songsSortSetting = .name
            self.updateSearchResults(for: self.searchController)
            self.appDelegate.notificationHandler.post(name: .fetchControllerSortChanged, object: nil, userInfo: nil)
        })
        let sortByRating = UIAction(title: "Rating", image: sortType == .rating ? .check : nil, handler: { _ in
            self.change(sortType: .rating)
            self.appDelegate.storage.settings.songsSortSetting = .rating
            self.updateSearchResults(for: self.searchController)
            self.appDelegate.notificationHandler.post(name: .fetchControllerSortChanged, object: nil, userInfo: nil)
        })
        let sortByDuration = UIAction(title: "Duration", image: sortType == .duration ? .check : nil, handler: { _ in
            self.change(sortType: .duration)
            self.appDelegate.storage.settings.songsSortSetting = .duration
            self.updateSearchResults(for: self.searchController)
            self.appDelegate.notificationHandler.post(name: .fetchControllerSortChanged, object: nil, userInfo: nil)
        })
        return UIMenu(title: "Sort", image: .sort, options: [], children: [sortByName, sortByRating, sortByDuration])
    }
    
    private func createActionButtonMenu() -> UIMenu {
        let action = UIAction(title: "Download \(filterTitle)", image: UIImage.startDownload, handler: { _ in
            var songs = [Song]()
            switch self.displayFilter {
            case .all:
                songs = self.appDelegate.storage.main.library.getSongs()
            case .newest, .recent:
                break
            case .favorites:
                songs = self.appDelegate.storage.main.library.getFavoriteSongs()
            }
            if songs.count > AppDelegate.maxPlayablesDownloadsToAddAtOnceWithoutWarning {
                let alert = UIAlertController(title: "Many Songs", message: "Are you shure to add \(songs.count) songs from \"\(self.filterTitle)\" to download queue?", preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { _ in
                    self.appDelegate.playableDownloadManager.download(objects: songs)
                }))
                alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
                self.present(alert, animated: true, completion: nil)
            } else {
                self.appDelegate.playableDownloadManager.download(objects: songs)
            }
        })
        return UIMenu(options: [.displayInline], children: [action])
    }
    
    @objc func handleRefresh(refreshControl: UIRefreshControl) {
        guard self.appDelegate.storage.settings.isOnlineMode else {
            #if !targetEnvironment(macCatalyst)
            self.refreshControl?.endRefreshing()
            #endif
            return
        }
        firstly {
            AutoDownloadLibrarySyncer(storage: self.appDelegate.storage, librarySyncer: self.appDelegate.librarySyncer, playableDownloadManager: self.appDelegate.playableDownloadManager)
                .syncNewestLibraryElements()
        }.catch { error in
            self.appDelegate.eventLogger.report(topic: "Songs Newest Elements Sync", error: error)
        }.finally {
            #if !targetEnvironment(macCatalyst)
            self.refreshControl?.endRefreshing()
            #endif
        }
    }
    
}
