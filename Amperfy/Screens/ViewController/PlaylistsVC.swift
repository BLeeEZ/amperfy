import UIKit
import CoreData

class PlaylistsVC: SingleFetchedResultsTableViewController<PlaylistMO> {

    private var fetchedResultsController: PlaylistFetchedResultsController!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        appDelegate.userStatistics.visited(.playlists)
        
        fetchedResultsController = PlaylistFetchedResultsController(managedObjectContext: appDelegate.persistentStorage.context, isGroupedInAlphabeticSections: true)
        singleFetchedResultsController = fetchedResultsController
        
        var searchTiles: [String]? = nil
        if appDelegate.backendProxy.selectedApi == .ampache {
            searchTiles = ["All", "Cached", "User", "Smart"]
        } else if appDelegate.backendProxy.selectedApi == .subsonic {
            searchTiles = ["All", "Cached"]
        }
        configureSearchController(placeholder: "Search in \"Playlists\"", scopeButtonTitles: searchTiles)
        tableView.register(nibName: PlaylistTableCell.typeName)
        tableView.rowHeight = PlaylistTableCell.rowHeight
        self.refreshControl?.addTarget(self, action: #selector(Self.handleRefresh), for: UIControl.Event.valueChanged)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        fetchedResultsController.fetch()
        appDelegate.persistentStorage.persistentContainer.performBackgroundTask() { (context) in
            let syncLibrary = LibraryStorage(context: context)
            let syncer = self.appDelegate.backendApi.createLibrarySyncer()
            syncer.syncDownPlaylistsWithoutSongs(library: syncLibrary)
        }
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell: PlaylistTableCell = dequeueCell(for: tableView, at: indexPath)
        let playlist = fetchedResultsController.getWrappedEntity(at: indexPath)
        cell.display(playlist: playlist)
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
