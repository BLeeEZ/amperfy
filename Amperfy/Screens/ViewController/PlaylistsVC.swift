import UIKit

class PlaylistsVC: UITableViewController {

    var appDelegate: AppDelegate!
    var playlistsAsyncFetch = AsynchronousFetch(result: nil)
    var playlistsAll = [Playlist]()
    var playlistsUnfiltered = [Playlist]()
    var playlistsFiltered = [Playlist]()
    
    private let searchController = UISearchController(searchResultsController: nil)
    private let loadingSpinner = SpinnerViewController()

    override func viewDidLoad() {
        super.viewDidLoad()
        appDelegate = (UIApplication.shared.delegate as! AppDelegate)
        
        configureSearchController()
        tableView.register(nibName: PlaylistTableCell.typeName)
        tableView.rowHeight = PlaylistTableCell.rowHeight
        self.refreshControl?.addTarget(self, action: #selector(PlaylistsVC.handleRefresh), for: UIControl.Event.valueChanged)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        playlistsAll = [Playlist]()
        self.updateSearchResults(for: self.searchController)
        loadingSpinner.display(on: self)
        appDelegate.storage.persistentContainer.performBackgroundTask() { (context) in
            let backgroundLibrary = LibraryStorage(context: context)
            self.playlistsAsyncFetch = backgroundLibrary.getPlaylistsAsync(forMainContex: self.appDelegate.storage.context) { playlists in
                self.playlistsAll = playlists.sortAlphabeticallyAscending()
                self.updateSearchResults(for: self.searchController)
                self.loadingSpinner.hide()
            }
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        self.playlistsAsyncFetch.cancle()
    }
    
    private func configureSearchController() {
        searchController.searchResultsUpdater = self
        searchController.searchBar.autocapitalizationType = .none
        if appDelegate.backendProxy.selectedApi == .ampache {
            searchController.searchBar.scopeButtonTitles = ["All", "User Playlists", "Smart Playlists"]
        }

        if #available(iOS 11.0, *) {
            // For iOS 11 and later, place the search bar in the navigation bar.
            navigationItem.searchController = searchController
            // Make the search bar always visible.
            navigationItem.hidesSearchBarWhenScrolling = false
        } else {
            // For iOS 10 and earlier, place the search controller's search bar in the table view's header.
            tableView.tableHeaderView = searchController.searchBar
        }
        
        searchController.delegate = self
        searchController.obscuresBackgroundDuringPresentation = false
        searchController.searchBar.delegate = self // Monitor when the search button is tapped.
        self.definesPresentationContext = true
    }
    
    // MARK: - Table view data source
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return playlistsFiltered.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell: PlaylistTableCell = dequeueCell(for: tableView, at: indexPath)
        
        let playlist = playlistsFiltered[indexPath.row]
        cell.display(playlist: playlist)
        
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let playlist = playlistsFiltered[indexPath.row]
        performSegue(withIdentifier: Segues.toPlaylistDetail.rawValue, sender: playlist)
    }
    
    // Override to support editing the table view.
    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            let playlist = playlistsFiltered[indexPath.row]
            playlistsFiltered.remove(at: indexPath.row)
            appDelegate.persistentLibraryStorage.deletePlaylist(playlist)
            appDelegate.persistentLibraryStorage.saveContext()
            playlistsAll = playlistsAll.filter{ $0.managedObject.objectID != playlist.managedObject.objectID }
            tableView.deleteRows(at: [indexPath], with: .fade)
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
        appDelegate.storage.persistentContainer.performBackgroundTask() { (context) in
            let syncer = self.appDelegate.backendApi.createLibrarySyncer()
            let backgroundLibrary = LibraryStorage(context: context)
            syncer.syncDownPlaylistsWithoutSongs(libraryStorage: backgroundLibrary)
            self.playlistsAsyncFetch = backgroundLibrary.getPlaylistsAsync(forMainContex: self.appDelegate.storage.context) { playlists in
                self.playlistsAll = playlists.sortAlphabeticallyAscending()
                self.updateSearchResults(for: self.searchController)
                refreshControl.endRefreshing()
            }
        }
    }
    
}

extension PlaylistsVC: UISearchResultsUpdating {
    
    func updateSearchResults(for searchController: UISearchController) {
        updateDataBasedOnScope()
        if let searchText = searchController.searchBar.text, !searchText.isEmpty {
            playlistsFiltered = playlistsUnfiltered.filterBy(searchText: searchText)
        } else {
            playlistsFiltered = playlistsUnfiltered
        }
        tableView.reloadData()
    }
    
}

extension PlaylistsVC: UISearchBarDelegate {
    
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
    }
    
    func searchBar(_ searchBar: UISearchBar, selectedScopeButtonIndexDidChange selectedScope: Int) {
        updateSearchResults(for: searchController)
    }

    func updateDataBasedOnScope() {
        switch searchController.searchBar.selectedScopeButtonIndex {
        case 1:
            playlistsUnfiltered = playlistsAll.filterRegualarPlaylists()
        case 2:
            playlistsUnfiltered = playlistsAll.filterSmartPlaylists()
        default:
            playlistsUnfiltered = playlistsAll
        }
    }
}

extension PlaylistsVC: UISearchControllerDelegate {
}
