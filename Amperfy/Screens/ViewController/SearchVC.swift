import UIKit
import CoreData

class SearchVC: BasicTableViewController {

    private var playlistFetchedResultsController: PlaylistFetchedResultsController!
    private var artistFetchedResultsController: ArtistFetchedResultsController!
    private var albumFetchedResultsController: AlbumFetchedResultsController!
    private var songFetchedResultsController: SongFetchedResultsController!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        playlistFetchedResultsController = PlaylistFetchedResultsController(managedObjectContext: appDelegate.persistentStorage.context, isGroupedInAlphabeticSections: false)
        playlistFetchedResultsController.delegate = self
        artistFetchedResultsController = ArtistFetchedResultsController(managedObjectContext: appDelegate.persistentStorage.context, isGroupedInAlphabeticSections: false)
        artistFetchedResultsController.delegate = self
        albumFetchedResultsController = AlbumFetchedResultsController(managedObjectContext: appDelegate.persistentStorage.context, isGroupedInAlphabeticSections: false)
        albumFetchedResultsController.delegate = self
        songFetchedResultsController = SongFetchedResultsController(managedObjectContext: appDelegate.persistentStorage.context, isGroupedInAlphabeticSections: false)
        songFetchedResultsController.delegate = self
        
        configureSearchController(placeholder: "Playlists, Songs and more", scopeButtonTitles: ["All", "Cached"])
        tableView.register(nibName: PlaylistTableCell.typeName)
        tableView.register(nibName: ArtistTableCell.typeName)
        tableView.register(nibName: AlbumTableCell.typeName)
        tableView.register(nibName: SongTableCell.typeName)
        tableView.separatorStyle = .none
        
        swipeCallback = { (indexPath, completionHandler) in
            self.determSwipeActionContext(at: indexPath) { actionContext in
                completionHandler(actionContext)
            }
        }
    }
    
    func determSwipeActionContext(at indexPath: IndexPath, completionHandler: @escaping (_ actionContext: SwipeActionContext?) -> Void) {
        switch indexPath.section {
        case LibraryElement.Playlist.rawValue:
            let playlist = playlistFetchedResultsController.getWrappedEntity(at: IndexPath(row: indexPath.row, section: 0))
            fetchDetails(of: playlist) {
                completionHandler(SwipeActionContext(containable: playlist))
            }
        case LibraryElement.Artist.rawValue:
            let artist = artistFetchedResultsController.getWrappedEntity(at: IndexPath(row: indexPath.row, section: 0))
            fetchDetails(of: artist) {
                completionHandler(SwipeActionContext(containable: artist))
            }
        case LibraryElement.Album.rawValue:
            let album = albumFetchedResultsController.getWrappedEntity(at: IndexPath(row: indexPath.row, section: 0))
            fetchDetails(of: album) {
                completionHandler(SwipeActionContext(containable: album))
            }
        case LibraryElement.Song.rawValue:
            let song = songFetchedResultsController.getWrappedEntity(at: IndexPath(row: indexPath.row, section: 0))
            completionHandler(SwipeActionContext(containable: song))
        default:
            completionHandler(nil)
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        appDelegate.userStatistics.visited(.search)
    }

    func convertCellViewToPlayContext(cell: UITableViewCell) -> PlayContext? {
        guard let indexPath = tableView.indexPath(for: cell), indexPath.section == LibraryElement.Song.rawValue else { return nil }
        let song = songFetchedResultsController.getWrappedEntity(at: indexPath)
        return PlayContext(name: song.title, playables: [song])
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
            return playlistFetchedResultsController.sections?[0].numberOfObjects ?? 0
        case LibraryElement.Artist.rawValue:
            return artistFetchedResultsController.sections?[0].numberOfObjects ?? 0
        case LibraryElement.Album.rawValue:
            return albumFetchedResultsController.sections?[0].numberOfObjects ?? 0
        case LibraryElement.Song.rawValue:
            return songFetchedResultsController.sections?[0].numberOfObjects ?? 0
        default:
            return 0
        }
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch indexPath.section {
        case LibraryElement.Playlist.rawValue:
            let cell: PlaylistTableCell = dequeueCell(for: tableView, at: indexPath)
            let playlist = playlistFetchedResultsController.getWrappedEntity(at: IndexPath(row: indexPath.row, section: 0))
            cell.display(playlist: playlist, rootView: self)
            return cell
        case LibraryElement.Artist.rawValue:
            let cell: ArtistTableCell = dequeueCell(for: tableView, at: indexPath)
            let artist = artistFetchedResultsController.getWrappedEntity(at: IndexPath(row: indexPath.row, section: 0))
            cell.display(artist: artist, rootView: self)
            return cell
        case LibraryElement.Album.rawValue:
            let cell: AlbumTableCell = dequeueCell(for: tableView, at: indexPath)
            let album = albumFetchedResultsController.getWrappedEntity(at: IndexPath(row: indexPath.row, section: 0))
            cell.display(album: album, rootView: self)
            return cell
        case LibraryElement.Song.rawValue:
            let cell: SongTableCell = dequeueCell(for: tableView, at: indexPath)
            let song = songFetchedResultsController.getWrappedEntity(at: IndexPath(row: indexPath.row, section: 0))
            cell.display(song: song, playContextCb: self.convertCellViewToPlayContext, rootView: self)
            return cell
        default:
            return UITableViewCell()
        }
    }
    
    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        switch section {
        case LibraryElement.Playlist.rawValue:
            return playlistFetchedResultsController.sections?[0].numberOfObjects ?? 0 > 0 ? CommonScreenOperations.tableSectionHeightLarge : 0
        case LibraryElement.Artist.rawValue:
            return artistFetchedResultsController.sections?[0].numberOfObjects ?? 0 > 0 ? CommonScreenOperations.tableSectionHeightLarge : 0
        case LibraryElement.Album.rawValue:
            return albumFetchedResultsController.sections?[0].numberOfObjects ?? 0 > 0 ? CommonScreenOperations.tableSectionHeightLarge : 0
        case LibraryElement.Song.rawValue:
            return songFetchedResultsController.sections?[0].numberOfObjects ?? 0 > 0 ? CommonScreenOperations.tableSectionHeightLarge : 0
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
            let playlist = playlistFetchedResultsController.getWrappedEntity(at: IndexPath(row: indexPath.row, section: 0))
            performSegue(withIdentifier: Segues.toPlaylistDetail.rawValue, sender: playlist)
        case LibraryElement.Artist.rawValue:
            let artist = artistFetchedResultsController.getWrappedEntity(at: IndexPath(row: indexPath.row, section: 0))
            performSegue(withIdentifier: Segues.toArtistDetail.rawValue, sender: artist)
        case LibraryElement.Album.rawValue:
            let album = albumFetchedResultsController.getWrappedEntity(at: IndexPath(row: indexPath.row, section: 0))
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
    
    override func updateSearchResults(for searchController: UISearchController) {
        guard let searchText = searchController.searchBar.text else { return }
        if searchText.count > 0, searchController.searchBar.selectedScopeButtonIndex == 0 {
            appDelegate.persistentStorage.persistentContainer.performBackgroundTask() { (context) in
                let backgroundLibrary = LibraryStorage(context: context)
                let syncer = self.appDelegate.backendApi.createLibrarySyncer()
                syncer.searchArtists(searchText: searchText, library: backgroundLibrary)
            }
            appDelegate.persistentStorage.persistentContainer.performBackgroundTask() { (context) in
                let backgroundLibrary = LibraryStorage(context: context)
                let syncer = self.appDelegate.backendApi.createLibrarySyncer()
                syncer.searchAlbums(searchText: searchText, library: backgroundLibrary)
            }
            appDelegate.persistentStorage.persistentContainer.performBackgroundTask() { (context) in
                let syncLibrary = LibraryStorage(context: context)
                let syncer = self.appDelegate.backendApi.createLibrarySyncer()
                syncer.searchSongs(searchText: searchText, library: syncLibrary)
            }
            playlistFetchedResultsController.search(searchText: searchText, playlistSearchCategory: .all)
            artistFetchedResultsController.search(searchText: searchText, onlyCached: false)
            albumFetchedResultsController.search(searchText: searchText, onlyCached: false, displayFilter: .all)
            songFetchedResultsController.search(searchText: searchText, onlyCachedSongs: false, displayFilter: .all)
            tableView.separatorStyle = .singleLine
        } else if searchController.searchBar.selectedScopeButtonIndex == 1 {
            playlistFetchedResultsController.search(searchText: searchText, playlistSearchCategory: .cached)
            artistFetchedResultsController.search(searchText: searchText, onlyCached: true)
            albumFetchedResultsController.search(searchText: searchText, onlyCached: true, displayFilter: .all)
            songFetchedResultsController.search(searchText: searchText, onlyCachedSongs: true, displayFilter: .all)
            tableView.separatorStyle = .singleLine
        } else {
            playlistFetchedResultsController.clearResults()
            artistFetchedResultsController.clearResults()
            albumFetchedResultsController.clearResults()
            songFetchedResultsController.clearResults()
            tableView.separatorStyle = .none
        }
        tableView.reloadData()
    }
    
    override func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange anObject: Any, at indexPath: IndexPath?, for type: NSFetchedResultsChangeType, newIndexPath: IndexPath?) {
        var section: Int = 0
        switch controller {
        case playlistFetchedResultsController.fetchResultsController:
            section = LibraryElement.Playlist.rawValue
        case artistFetchedResultsController.fetchResultsController:
            section = LibraryElement.Artist.rawValue
        case albumFetchedResultsController.fetchResultsController:
            section = LibraryElement.Album.rawValue
        case songFetchedResultsController.fetchResultsController:
            section = LibraryElement.Song.rawValue
        default:
            return
        }
        
        super.applyChangesOfMultiRowType(determinedSection: section, at: indexPath, for: type, newIndexPath: newIndexPath)
    }
    
    override func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange sectionInfo: NSFetchedResultsSectionInfo, atSectionIndex sectionIndex: Int, for type: NSFetchedResultsChangeType) {
    }
    
}
