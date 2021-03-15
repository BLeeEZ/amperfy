import UIKit

class PlaylistSelectorVC: UITableViewController {

    var songToAdd: Song?
    var songsToAdd: [Song]?
    private var appDelegate: AppDelegate!
    private var playlistsAsyncFetch = AsynchronousFetch(result: nil)
    private var playlistsUnfiltered = [Playlist]()
    private var playlistsFiltered = [Playlist]()
    
    private let searchController = UISearchController(searchResultsController: nil)
    private let loadingSpinner = SpinnerViewController()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        appDelegate = (UIApplication.shared.delegate as! AppDelegate)

        configureSearchController()
        tableView.register(nibName: PlaylistTableCell.typeName)
        tableView.rowHeight = PlaylistTableCell.rowHeight
        
        tableView.tableHeaderView = UIView(frame: CGRect(x: 0, y: 0, width: view.bounds.size.width, height: NewPlaylistTableHeader.frameHeight))
        if let newPlaylistTableHeaderView = ViewBuilder<NewPlaylistTableHeader>.createFromNib(withinFixedFrame: CGRect(x: 0, y: 0, width: view.bounds.size.width, height: NewPlaylistTableHeader.frameHeight)) {
            newPlaylistTableHeaderView.reactOnCreation() { _ in
                self.loadingSpinner.display(on: self)
                self.appDelegate.storage.persistentContainer.performBackgroundTask() { (context) in
                    let backgroundLibrary = LibraryStorage(context: context)
                    self.playlistsAsyncFetch = backgroundLibrary.getPlaylistsAsync(forMainContex: self.appDelegate.storage.context) { playlistsResult in
                        self.playlistsUnfiltered = playlistsResult.sortAlphabeticallyAscending()
                        self.updateSearchResults(for: self.searchController)
                        self.loadingSpinner.hide()
                    }
                }
                
            }
            tableView.tableHeaderView?.addSubview(newPlaylistTableHeaderView)
        }

        loadingSpinner.display(on: self)
        appDelegate.storage.persistentContainer.performBackgroundTask() { (context) in
            let backgroundLibrary = LibraryStorage(context: context)
            self.playlistsAsyncFetch = backgroundLibrary.getPlaylistsAsync(forMainContex: self.appDelegate.storage.context) { playlistsResult in
                self.playlistsUnfiltered = playlistsResult.sortAlphabeticallyAscending()
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
    
    @IBAction func cancelButtonPressed(_ sender: UIBarButtonItem) {
        dismiss()
    }
    
    private func dismiss() {
        dismiss(animated: true, completion: nil)
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
        if let song = songToAdd {
            playlist.append(song: song)
        }
        if let songs = songsToAdd {
            playlist.append(songs: songs)
        }
        dismiss()
    }
    
}

extension PlaylistSelectorVC: UISearchResultsUpdating {
    
    func filterSearchResults(for searchController: UISearchController, playlists: [Playlist]) -> [Playlist]  {
        var filteredPlaylists = [Playlist]()
        if let searchText = searchController.searchBar.text, !searchText.isEmpty {
            filteredPlaylists = playlists.filterBy(searchText: searchText)
        } else {
            filteredPlaylists = playlists
        }
        return filteredPlaylists
    }
    
    func updateSearchResults(for searchController: UISearchController) {
        playlistsFiltered = filterSearchResults(for: searchController, playlists: playlistsUnfiltered)
        tableView.reloadData()
    }
    
}

extension PlaylistSelectorVC: UISearchBarDelegate {
    
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
    }
    
    func searchBar(_ searchBar: UISearchBar, selectedScopeButtonIndexDidChange selectedScope: Int) {
        updateSearchResults(for: searchController)
    }

}

extension PlaylistSelectorVC: UISearchControllerDelegate {
}
