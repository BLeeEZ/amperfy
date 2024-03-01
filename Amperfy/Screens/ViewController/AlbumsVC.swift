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

class AlbumsDiffableDataSource: BasicUITableViewDiffableDataSource {
}

class AlbumsVC: SingleSnapshotFetchedResultsTableViewController<AlbumMO> {

    private var fetchedResultsController: AlbumFetchedResultsController!
    private var optionsButton: UIBarButtonItem!
    public var displayFilter: DisplayCategoryFilter = .all
    private var sortType: AlbumElementSortType = .name
    private var filterTitle = "Albums"
    private var newestElementsOffsetsSynced = Set<Int>()
    
    override func createDiffableDataSource() -> BasicUITableViewDiffableDataSource {
        let source = AlbumsDiffableDataSource(tableView: tableView) { (tableView, indexPath, objectID) -> UITableViewCell? in
            guard let object = try? self.appDelegate.storage.main.context.existingObject(with: objectID),
                  let albumMO = object as? AlbumMO
            else {
                fatalError("Managed object should be available")
            }
            let album = Album(managedObject: albumMO)
            return self.createCell(tableView, forRowAt: indexPath, album: album)
        }
        return source
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        appDelegate.userStatistics.visited(.albums)

        applyFilter()
        configureSearchController(placeholder: "Search in \"\(filterTitle)\"", scopeButtonTitles: ["All", "Cached"], showSearchBarAtEnter: true)
        tableView.register(nibName: GenericTableCell.typeName)
        tableView.rowHeight = GenericTableCell.rowHeight
        
        tableView.tableHeaderView = UIView(frame: CGRect(x: 0, y: 0, width: view.bounds.size.width, height: LibraryElementDetailTableHeaderView.frameHeight))
        if let libraryElementDetailTableHeaderView = ViewBuilder<LibraryElementDetailTableHeaderView>.createFromNib(withinFixedFrame: CGRect(x: 0, y: 0, width: view.bounds.size.width, height: LibraryElementDetailTableHeaderView.frameHeight)) {
            libraryElementDetailTableHeaderView.prepare(
                infoCB: { "\(self.fetchedResultsController.fetchedObjects?.count ?? 0) Album\((self.fetchedResultsController.fetchedObjects?.count ?? 0) == 1 ? "" : "s")" },
                playContextCb: self.handleHeaderPlay,
                with: appDelegate.player,
                isShuffleOnContextNeccessary: false,
                shuffleContextCb: self.handleHeaderShuffle)
            tableView.tableHeaderView?.addSubview(libraryElementDetailTableHeaderView)
        }
        
        self.refreshControl?.addTarget(self, action: #selector(Self.handleRefresh), for: UIControl.Event.valueChanged)
        
        containableAtIndexPathCallback = { (indexPath) in
            return self.fetchedResultsController.getWrappedEntity(at: indexPath)
        }
        playContextAtIndexPathCallback = { (indexPath) in
            let entity = self.fetchedResultsController.getWrappedEntity(at: indexPath)
            return PlayContext(containable: entity)
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
            change(sortType: appDelegate.storage.settings.albumsSortSetting)
        case .newest:
            self.filterTitle = "Newest Albums"
            self.isIndexTitelsHidden = true
            change(sortType: .newest)
        case .recent:
            self.filterTitle = "Recently Played Albums"
            self.isIndexTitelsHidden = true
            change(sortType: .recent)
        case .favorites:
            self.filterTitle = "Favorite Albums"
            self.isIndexTitelsHidden = false
            change(sortType: appDelegate.storage.settings.albumsSortSetting)
        }
        self.navigationItem.title = self.filterTitle
    }
    
    func change(sortType: AlbumElementSortType) {
        self.sortType = sortType
        singleFetchedResultsController?.clearResults()
        var isGroupedInAlphabeticSections = false
        switch sortType {
        case .name, .rating, .artist, .duration, .year:
            isGroupedInAlphabeticSections = true
        case .newest, .recent:
            isGroupedInAlphabeticSections = false
        }
        
        fetchedResultsController = AlbumFetchedResultsController(coreDataCompanion: appDelegate.storage.main, sortType: sortType, isGroupedInAlphabeticSections: isGroupedInAlphabeticSections)
        fetchedResultsController.fetchResultsController.sectionIndexType = sortType.asSectionIndexType
        singleFetchedResultsController = fetchedResultsController
        singleFetchedResultsController?.delegate = self
        singleFetchedResultsController?.fetch()
        updateRightBarButtonItems()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        updateRightBarButtonItems()
        updateFromRemote()
    }
    
    func updateRightBarButtonItems() {
        var actions = [UIMenu]()

        switch sortType {
        case .name, .rating, .artist, .duration, .year:
            actions.append(createSortButtonMenu())
        case .newest, .recent:
            break
        }

        if appDelegate.storage.settings.isOnlineMode {
            actions.append(createActionButtonMenu())
        }
            
        if !actions.isEmpty {
            optionsButton = OptionsBarButton()
            optionsButton.menu = UIMenu(children: actions)
            navigationItem.rightBarButtonItems = [optionsButton]
        } else {
            navigationItem.rightBarButtonItems = []
        }
    }
    
    func updateFromRemote(offset: Int = 0, count: Int = AmperKit.newestElementsFetchCount) {
        guard self.appDelegate.storage.settings.isOnlineMode else { return }
        switch displayFilter {
        case .all:
            break
        case .newest:
            firstly {
                AutoDownloadLibrarySyncer(storage: self.appDelegate.storage, librarySyncer: self.appDelegate.librarySyncer, playableDownloadManager: self.appDelegate.playableDownloadManager)
                    .syncNewestLibraryElements(offset: offset, count: count)
            }.catch { error in
                self.appDelegate.eventLogger.report(topic: "Newest Albums Sync", error: error)
            }.finally {
                self.updateSearchResults(for: self.searchController)
            }
        case .recent:
            firstly {
                self.appDelegate.librarySyncer.syncRecentAlbums(offset: offset, count: count)
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
    
    override func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        guard let elementCount = fetchedResultsController.fetchResultsController.fetchedObjects?.count else { return}
        if sortType == .newest || sortType == .recent,
           (searchController.searchBar.text ?? "").isEmpty,
           indexPath.row > 0,
           // fetch each 20th row or on last element
           indexPath.row == elementCount-1 || (indexPath.row % 20 == 0),
           // this offset has not been synced yet
           !newestElementsOffsetsSynced.contains(indexPath.row) {
            newestElementsOffsetsSynced.insert(indexPath.row)
            updateFromRemote(offset: indexPath.row, count: AmperKit.newestElementsFetchCount)
        }
    }
    
    func createCell(_ tableView: UITableView, forRowAt indexPath: IndexPath, album: Album) -> UITableViewCell {
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
        case .newest, .recent:
            return 0.0
        case .artist:
            return 0.0
        case .duration:
            return 0.0
        case .year:
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
        case .newest, .recent:
            return super.tableView(tableView, titleForHeaderInSection: section)
        case .artist:
            return super.tableView(tableView, titleForHeaderInSection: section)
        case .duration:
            return nil
        case .year:
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
    
    private func handleHeaderPlay() -> PlayContext {
        guard let displayedAlbumsMO = self.fetchedResultsController.fetchedObjects else { return PlayContext(name: filterTitle, playables: []) }
        let firstAlbums = displayedAlbumsMO.prefix(5).compactMap{ Album(managedObject: $0) }
        var songs = [AbstractPlayable]()
        firstAlbums.forEach { songs.append(contentsOf: $0.playables) }
        return PlayContext(name: filterTitle, playables: Array(songs.prefix(appDelegate.player.maxSongsToAddOnce)))
    }
    
    private func handleHeaderShuffle() -> PlayContext {
        guard let displayedAlbumsMO = self.fetchedResultsController.fetchedObjects else { return PlayContext(name: filterTitle, playables: []) }
        let randomAlbums = displayedAlbumsMO[randomPick: 5].compactMap{ Album(managedObject: $0) }
        var songs = [AbstractPlayable]()
        randomAlbums.forEach { songs.append(contentsOf: $0.playables) }
        return PlayContext(name: filterTitle, playables: Array(songs.prefix(appDelegate.player.maxSongsToAddOnce)))
    }
    
    private func createSortButtonMenu() -> UIMenu {
        let sortByName = UIAction(title: "Name", image: sortType == .name ? .check : nil, handler: { _ in
            self.change(sortType: .name)
            self.appDelegate.storage.settings.albumsSortSetting = .name
            self.updateSearchResults(for: self.searchController)
            self.appDelegate.notificationHandler.post(name: .fetchControllerSortChanged, object: nil, userInfo: nil)
        })
        let sortByRating = UIAction(title: "Rating", image: sortType == .rating ? .check : nil, handler: { _ in
            self.change(sortType: .rating)
            self.appDelegate.storage.settings.albumsSortSetting = .rating
            self.updateSearchResults(for: self.searchController)
            self.appDelegate.notificationHandler.post(name: .fetchControllerSortChanged, object: nil, userInfo: nil)
        })
        let sortByArtist = UIAction(title: "Artist", image: sortType == .artist ? .check : nil, handler: { _ in
            self.change(sortType: .artist)
            self.appDelegate.storage.settings.albumsSortSetting = .artist
            self.updateSearchResults(for: self.searchController)
            self.appDelegate.notificationHandler.post(name: .fetchControllerSortChanged, object: nil, userInfo: nil)
        })
        let sortByDuration = UIAction(title: "Duration", image: sortType == .duration ? .check : nil, handler: { _ in
            self.change(sortType: .duration)
            self.appDelegate.storage.settings.albumsSortSetting = .duration
            self.updateSearchResults(for: self.searchController)
            self.appDelegate.notificationHandler.post(name: .fetchControllerSortChanged, object: nil, userInfo: nil)
        })
        let sortByYear = UIAction(title: "Year", image: sortType == .year ? .check : nil, handler: { _ in
            self.change(sortType: .year)
            self.appDelegate.storage.settings.albumsSortSetting = .year
            self.updateSearchResults(for: self.searchController)
            self.appDelegate.notificationHandler.post(name: .fetchControllerSortChanged, object: nil, userInfo: nil)
        })
        return UIMenu(title: "Sort", image: .sort, options: [], children: [sortByName, sortByRating, sortByArtist, sortByDuration, sortByYear])
    }
    
    private func createActionButtonMenu() -> UIMenu {
        let action = UIAction(title: "Download \(filterTitle)", image: UIImage.startDownload, handler: { _ in
            var albums = [Album]()
            switch self.displayFilter {
            case .all:
                albums = self.appDelegate.storage.main.library.getAlbums()
            case .newest:
                albums = self.appDelegate.storage.main.library.getNewestAlbums()
            case .recent:
                albums = self.appDelegate.storage.main.library.getRecentAlbums()
            case .favorites:
                albums = self.appDelegate.storage.main.library.getFavoriteAlbums()
            }
            let albumSongs = Array(albums.compactMap{ $0.playables }.joined())
            if albumSongs.count > AppDelegate.maxPlayablesDownloadsToAddAtOnceWithoutWarning {
                let alert = UIAlertController(title: "Many Songs", message: "Are you shure to add \(albumSongs.count) songs from \"\(self.filterTitle)\" to download queue?", preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { _ in
                    self.appDelegate.playableDownloadManager.download(objects: albumSongs)
                }))
                alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
                self.present(alert, animated: true, completion: nil)
            } else {
                self.appDelegate.playableDownloadManager.download(objects: albumSongs)
            }
        })
        return UIMenu(options: [.displayInline], children: [action])
    }
    
    @objc func handleRefresh(refreshControl: UIRefreshControl) {
        guard self.appDelegate.storage.settings.isOnlineMode else {
            self.refreshControl?.endRefreshing()
            return
        }
        firstly {
            if self.displayFilter == .recent {
                return self.appDelegate.librarySyncer.syncRecentAlbums(offset: 0, count: AmperKit.newestElementsFetchCount)
            } else {
                return AutoDownloadLibrarySyncer(storage: self.appDelegate.storage, librarySyncer: self.appDelegate.librarySyncer, playableDownloadManager: self.appDelegate.playableDownloadManager)
                    .syncNewestLibraryElements()
            }
        }.catch { error in
            self.appDelegate.eventLogger.report(topic: "Albums Newest Elements Sync", error: error)
        }.finally {
            self.refreshControl?.endRefreshing()
        }
    }
    
}
