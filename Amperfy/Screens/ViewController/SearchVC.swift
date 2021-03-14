import UIKit
import CoreData

class SearchVC: UITableViewController {

    var appDelegate: AppDelegate!
    var playlistsAll = [Playlist]()
    var playlistsUnfiltered = [Playlist]()
    var playlistsFiltered = [Playlist]()
    var playlistsAsyncFetch = AsynchronousFetch(result: nil)
    private var playlistsFetchSemaphore = DispatchSemaphore(value: 0)
    var artistsAll = [Artist]()
    var artistsUnfiltered = [Artist]()
    var artistsFiltered = [Artist]()
    var artistsAsyncFetch = AsynchronousFetch(result: nil)
    private var artistsFetchSemaphore = DispatchSemaphore(value: 0)
    var albumsAll = [Album]()
    var albumsUnfiltered = [Album]()
    var albumsFiltered = [Album]()
    var albumsAsyncFetch = AsynchronousFetch(result: nil)
    private var albumsFetchSemaphore = DispatchSemaphore(value: 0)
    var songsAll = [Song]()
    var songsUnfiltered = [Song]()
    var songsFiltered = [Song]()
    var songsAsyncFetch = AsynchronousFetch(result: nil)
    private var songsFetchSemaphore = DispatchSemaphore(value: 0)
    
    private let searchController = UISearchController(searchResultsController: nil)
    private let loadingSpinner = SpinnerViewController()

    override func viewDidLoad() {
        super.viewDidLoad()
        appDelegate = (UIApplication.shared.delegate as! AppDelegate)

        configureSearchController()
        tableView.register(nibName: PlaylistTableCell.typeName)
        tableView.register(nibName: ArtistTableCell.typeName)
        tableView.register(nibName: AlbumTableCell.typeName)
        tableView.register(nibName: SongTableCell.typeName)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        playlistsAll = [Playlist]()
        artistsAll = [Artist]()
        albumsAll = [Album]()
        songsAll = [Song]()
        updateSearchResults(for: self.searchController)
        
        playlistsFetchSemaphore = DispatchSemaphore(value: 0)
        artistsFetchSemaphore = DispatchSemaphore(value: 0)
        albumsFetchSemaphore = DispatchSemaphore(value: 0)
        songsFetchSemaphore = DispatchSemaphore(value: 0)
        
        loadingSpinner.display(on: self)
        appDelegate.storage.persistentContainer.performBackgroundTask() { (context) in
            let backgroundLibrary = LibraryStorage(context: context)
            self.playlistsAsyncFetch = backgroundLibrary.getPlaylistsAsync(forMainContex: self.appDelegate.storage.context) { playlists in
                self.playlistsAll = playlists.sortAlphabeticallyAscending()
                self.playlistsFetchSemaphore.signal()
            }
            self.artistsAsyncFetch = backgroundLibrary.getArtistsAsync(forMainContex: self.appDelegate.storage.context) { artists in
                self.artistsAll = artists.sortAlphabeticallyAscending()
                self.artistsFetchSemaphore.signal()
            }
            self.albumsAsyncFetch = backgroundLibrary.getAlbumsAsync(forMainContex: self.appDelegate.storage.context) { albums in
                self.albumsAll = albums.sortAlphabeticallyAscending()
                self.albumsFetchSemaphore.signal()
            }
            self.songsAsyncFetch = backgroundLibrary.getSongsAsync(forMainContex: self.appDelegate.storage.context) { songs in
                self.songsAll = songs.sortAlphabeticallyAscending()
                self.songsFetchSemaphore.signal()
            }
        }
        DispatchQueue.global().async {
            self.playlistsFetchSemaphore.wait()
            self.artistsFetchSemaphore.wait()
            self.albumsFetchSemaphore.wait()
            self.songsFetchSemaphore.wait()
            DispatchQueue.main.async {
                self.reloadViewIfAllFetchesAreDone()
            }
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        playlistsAsyncFetch.cancle()
        artistsAsyncFetch.cancle()
        albumsAsyncFetch.cancle()
        songsAsyncFetch.cancle()
    }
    
    private func reloadViewIfAllFetchesAreDone() {
        updateSearchResults(for: self.searchController)
        self.loadingSpinner.hide()
    }

    private func configureSearchController() {
        searchController.searchResultsUpdater = self
        searchController.searchBar.autocapitalizationType = .none
        searchController.searchBar.scopeButtonTitles = ["All", "Cached"]
        
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
        
        /** Search presents a view controller by applying normal view controller presentation semantics.
         This means that the presentation moves up the view controller hierarchy until it finds the root
         view controller or one that defines a presentation context.
         */
        
        /** Specify that this view controller determines how the search controller is presented.
         The search controller should be presented modally and match the physical size of this view controller.
         */
        self.definesPresentationContext = true
    }
    
    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        return LibraryElement.allCases.count
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch section {
        case LibraryElement.Playlist.rawValue:
            return "Playlists"
        case LibraryElement.Artist.rawValue:
            return "Artists"
        case LibraryElement.Album.rawValue:
            return "Albums"
        case LibraryElement.Song.rawValue:
            return "Songs"
        default:
            return ""
        }
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch section {
        case LibraryElement.Playlist.rawValue:
            return playlistsFiltered.count
        case LibraryElement.Artist.rawValue:
            return artistsFiltered.count
        case LibraryElement.Album.rawValue:
            return albumsFiltered.count
        case LibraryElement.Song.rawValue:
            return songsFiltered.count
        default:
            return 0
        }
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch indexPath.section {
        case LibraryElement.Playlist.rawValue:
            let cell: PlaylistTableCell = dequeueCell(for: tableView, at: indexPath)
            let playlist = playlistsFiltered[indexPath.row]
            cell.display(playlist: playlist)
            return cell
        case LibraryElement.Artist.rawValue:
            let cell: ArtistTableCell = dequeueCell(for: tableView, at: indexPath)
            let artist = artistsFiltered[indexPath.row]
            cell.display(artist: artist)
            return cell
        case LibraryElement.Album.rawValue:
            let cell: AlbumTableCell = dequeueCell(for: tableView, at: indexPath)
            let album = albumsFiltered[indexPath.row]
            cell.display(album: album)
            return cell
        case LibraryElement.Song.rawValue:
            let cell: SongTableCell = dequeueCell(for: tableView, at: indexPath)
            let song = songsFiltered[indexPath.row]
            cell.display(song: song, rootView: self)
            return cell
        default:
            return UITableViewCell()
        }
    }
    
    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        switch section {
        case LibraryElement.Playlist.rawValue:
            return playlistsFiltered.count != 0 ? CommonScreenOperations.tableSectionHeightLarge : 0
        case LibraryElement.Artist.rawValue:
            return artistsFiltered.count != 0 ? CommonScreenOperations.tableSectionHeightLarge : 0
        case LibraryElement.Album.rawValue:
            return albumsFiltered.count != 0 ? CommonScreenOperations.tableSectionHeightLarge : 0
        case LibraryElement.Song.rawValue:
            return songsFiltered.count != 0 ? CommonScreenOperations.tableSectionHeightLarge : 0
        default:
            return 0.0
        }
    }
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        switch indexPath.section {
        case LibraryElement.Playlist.rawValue:
            return PlaylistTableCell.rowHeight
        case LibraryElement.Artist.rawValue:
            return ArtistTableCell.rowHeight
        case LibraryElement.Album.rawValue:
            return AlbumTableCell.rowHeight
        case LibraryElement.Song.rawValue:
            return SongTableCell.rowHeight
        default:
            return 0.0
        }
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        switch indexPath.section {
        case LibraryElement.Playlist.rawValue:
            let playlist = playlistsFiltered[indexPath.row]
            performSegue(withIdentifier: Segues.toPlaylistDetail.rawValue, sender: playlist)
        case LibraryElement.Artist.rawValue:
            let artist = artistsFiltered[indexPath.row]
            performSegue(withIdentifier: Segues.toArtistDetail.rawValue, sender: artist)
        case LibraryElement.Album.rawValue:
            let album = albumsFiltered[indexPath.row]
            performSegue(withIdentifier: Segues.toAlbumDetail.rawValue, sender: album)
        case LibraryElement.Song.rawValue: break
        default: break
        }
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        switch segue.identifier {
        case Segues.toPlaylistDetail.rawValue:
            let vc = segue.destination as! PlaylistDetailVC
            let playlist = sender as? Playlist
            vc.playlist = playlist
        case Segues.toArtistDetail.rawValue:
            let vc = segue.destination as! ArtistDetailVC
            let artist = sender as? Artist
            vc.artist = artist
        case Segues.toAlbumDetail.rawValue:
            let vc = segue.destination as! AlbumDetailVC
            let album = sender as? Album
            vc.album = album
        default: break
        }
    }

}

extension SearchVC: UISearchResultsUpdating {
    
    func updateSearchResults(for searchController: UISearchController) {
        updateDataBasedOnScope()
        if let searchText = searchController.searchBar.text, !searchText.isEmpty {
            playlistsFiltered = playlistsUnfiltered.filterBy(searchText: searchText)
            artistsFiltered = artistsUnfiltered.filterBy(searchText: searchText)
            albumsFiltered = albumsUnfiltered.filterBy(searchText: searchText)
            songsFiltered = songsUnfiltered.filterBy(searchText: searchText)
        } else {
            playlistsFiltered = playlistsUnfiltered
            artistsFiltered = artistsUnfiltered
            albumsFiltered = albumsUnfiltered
            songsFiltered = songsUnfiltered
        }
        tableView.reloadData()
    }
    
}

extension SearchVC: UISearchBarDelegate {
    
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
    }
    
    func searchBar(_ searchBar: UISearchBar, selectedScopeButtonIndexDidChange selectedScope: Int) {
        updateSearchResults(for: searchController)
    }
    
    func updateDataBasedOnScope() {
        switch searchController.searchBar.selectedScopeButtonIndex {
        case 1:
            playlistsUnfiltered = [Playlist]()
            artistsUnfiltered = [Artist]()
            albumsUnfiltered = [Album]()
            songsUnfiltered = songsAll.filterCached()
        default:
            playlistsUnfiltered = playlistsAll
            artistsUnfiltered = artistsAll
            albumsUnfiltered = albumsAll
            songsUnfiltered = songsAll
        }
    }
    
}

extension SearchVC: UISearchControllerDelegate {
}
