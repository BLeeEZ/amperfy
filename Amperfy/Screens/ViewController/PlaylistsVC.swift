import UIKit
import CoreData

class PlaylistsVC: SingleFetchedResultsTableViewController<PlaylistMO> {

    private var fetchedResultsController: PlaylistFetchedResultsController!
    private var optionsButton: UIBarButtonItem!
    private var sortType: PlaylistSortType = .name
    
    override func viewDidLoad() {
        super.viewDidLoad()
        appDelegate.userStatistics.visited(.playlists)
        
        change(sortType: appDelegate.persistentStorage.settings.playlistsSortSetting)

        var searchTiles: [String]? = nil
        if appDelegate.backendProxy.selectedApi == .ampache {
            searchTiles = ["All", "Cached", "User", "Smart"]
        } else if appDelegate.backendProxy.selectedApi == .subsonic {
            searchTiles = ["All", "Cached"]
        }
        configureSearchController(placeholder: "Search in \"Playlists\"", scopeButtonTitles: searchTiles)
        tableView.register(nibName: PlaylistTableCell.typeName)
        tableView.rowHeight = PlaylistTableCell.rowHeight
        
        optionsButton = UIBarButtonItem(image: UIImage.sort, style: .plain, target: self, action: #selector(optionsPressed))
        navigationItem.rightBarButtonItem = optionsButton
        self.refreshControl?.addTarget(self, action: #selector(Self.handleRefresh), for: UIControl.Event.valueChanged)
        
        swipeCallback = { (indexPath, completionHandler) in
            let playlist = self.fetchedResultsController.getWrappedEntity(at: indexPath)
            playlist.fetchAsync(storage: self.appDelegate.persistentStorage, backendApi: self.appDelegate.backendApi) {
                completionHandler(SwipeActionContext(containable: playlist))
            }
        }
    }
    
    func change(sortType: PlaylistSortType) {
        self.sortType = sortType
        appDelegate.persistentStorage.settings.playlistsSortSetting = sortType
        singleFetchedResultsController?.clearResults()
        tableView.reloadData()
        fetchedResultsController = PlaylistFetchedResultsController(managedObjectContext: appDelegate.persistentStorage.context, sortType: sortType, isGroupedInAlphabeticSections: sortType == .name)
        singleFetchedResultsController = fetchedResultsController
        tableView.reloadData()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if appDelegate.persistentStorage.settings.isOnlineMode {
            appDelegate.persistentStorage.persistentContainer.performBackgroundTask() { (context) in
                let syncLibrary = LibraryStorage(context: context)
                let syncer = self.appDelegate.backendApi.createLibrarySyncer()
                syncer.syncDownPlaylistsWithoutSongs(library: syncLibrary)
            }
        }
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell: PlaylistTableCell = dequeueCell(for: tableView, at: indexPath)
        let playlist = fetchedResultsController.getWrappedEntity(at: indexPath)
        cell.display(playlist: playlist, rootView: self)
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let playlist = fetchedResultsController.getWrappedEntity(at: indexPath)
        performSegue(withIdentifier: Segues.toPlaylistDetail.rawValue, sender: playlist)
    }

    // Override to support editing the table view.
    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            let playlist = fetchedResultsController.getWrappedEntity(at: indexPath)
            appDelegate.persistentStorage.persistentContainer.performBackgroundTask() { (context) in
                let syncLibrary = LibraryStorage(context: context)
                let syncer = self.appDelegate.backendApi.createLibrarySyncer()
                let playlistAsync = playlist.getManagedObject(in: context, library: syncLibrary)
                syncer.syncUpload(playlistToDelete: playlistAsync)
            }
            appDelegate.library.deletePlaylist(playlist)
            appDelegate.library.saveContext()
        }
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == Segues.toPlaylistDetail.rawValue {
            let vc = segue.destination as! PlaylistDetailVC
            let playlist = sender as? Playlist
            vc.playlist = playlist
        }
    }
    
    @objc private func optionsPressed() {
        let alert = UIAlertController(title: "Playlists sorting", message: nil, preferredStyle: .actionSheet)
        if sortType != .name {
            alert.addAction(UIAlertAction(title: "Sort by name", style: .default, handler: { _ in
                self.change(sortType: .name)
                self.updateSearchResults(for: self.searchController)
            }))
        }
        if sortType != .lastPlayed {
            alert.addAction(UIAlertAction(title: "Sort by last time played", style: .default, handler: { _ in
                self.change(sortType: .lastPlayed)
                self.updateSearchResults(for: self.searchController)
            }))
        }
        if sortType != .lastChanged {
            alert.addAction(UIAlertAction(title: "Sort by last time changed", style: .default, handler: { _ in
                self.change(sortType: .lastChanged)
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
            let backgroundLibrary = LibraryStorage(context: context)
            let syncer = self.appDelegate.backendApi.createLibrarySyncer()
            syncer.syncDownPlaylistsWithoutSongs(library: backgroundLibrary)
            DispatchQueue.main.async {
                self.refreshControl?.endRefreshing()
            }
        }
    }

    override func updateSearchResults(for searchController: UISearchController) {
        let searchText = searchController.searchBar.text ?? ""
        let playlistSearchCategory = PlaylistSearchCategory(rawValue: searchController.searchBar.selectedScopeButtonIndex) ?? PlaylistSearchCategory.defaultValue
        fetchedResultsController.search(searchText: searchText, playlistSearchCategory: playlistSearchCategory)
        tableView.reloadData()
    }
    
}
