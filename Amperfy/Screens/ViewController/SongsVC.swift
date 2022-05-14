import UIKit
import CoreData

class SongsVC: SingleFetchedResultsTableViewController<SongMO> {

    private var fetchedResultsController: SongsFetchedResultsController!
    private var optionsButton: UIBarButtonItem!
    private var filterButton: UIBarButtonItem!
    private var displayFilter: DisplayCategoryFilter = .all
    
    override func viewDidLoad() {
        super.viewDidLoad()
        appDelegate.userStatistics.visited(.songs)
        
        fetchedResultsController = SongsFetchedResultsController(managedObjectContext: appDelegate.persistentStorage.context, isGroupedInAlphabeticSections: true)
        singleFetchedResultsController = fetchedResultsController
        
        configureSearchController(placeholder: "Search in \"Songs\"", scopeButtonTitles: ["All", "Cached"], showSearchBarAtEnter: false)
        tableView.register(nibName: SongTableCell.typeName)
        tableView.rowHeight = SongTableCell.rowHeight
        
        optionsButton = UIBarButtonItem(image: UIImage.ellipsis, style: .plain, target: self, action: #selector(optionsPressed))
        filterButton = UIBarButtonItem(image: UIImage.filter, style: .plain, target: self, action: #selector(filterButtonPressed))
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
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        updateFilterButton()
        if appDelegate.persistentStorage.settings.isOnlineMode {
            navigationItem.rightBarButtonItems = [optionsButton, filterButton]
        } else {
            navigationItem.rightBarButtonItems = [filterButton]
        }
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
            self.appDelegate.player.play(context: PlayContext(name: "Song Collection", playables: displayedSongs))
        }))
        if self.appDelegate.persistentStorage.settings.isOnlineMode {
            alert.addAction(UIAlertAction(title: "Play random songs", style: .default, handler: { _ in
                self.appDelegate.persistentStorage.persistentContainer.performBackgroundTask() { (context) in
                    let syncLibrary = LibraryStorage(context: context)
                    let syncer = self.appDelegate.backendApi.createLibrarySyncer()
                    let randomSongsPlaylist = syncLibrary.createPlaylist()
                    syncer.requestRandomSongs(playlist: randomSongsPlaylist, count: 100, library: syncLibrary)
                    DispatchQueue.main.async {
                        let playlistMain = randomSongsPlaylist.getManagedObject(in: self.appDelegate.persistentStorage.context, library: self.appDelegate.library)
                        self.appDelegate.player.clearContextQueue()
                        self.appDelegate.player.appendContextQueue(playables: playlistMain.playables)
                        self.appDelegate.player.play()
                        self.appDelegate.library.deletePlaylist(playlistMain)
                        self.appDelegate.library.saveContext()
                    }
                }
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

