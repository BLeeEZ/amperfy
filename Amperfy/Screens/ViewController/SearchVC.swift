import UIKit
import CoreData

class SearchVC: BasicTableViewController {

    private var playlistFetchedResultsController: PlaylistFetchedResultsController!
    private var artistFetchedResultsController: ArtistFetchedResultsController!
    private var albumFetchedResultsController: AlbumFetchedResultsController!
    private var songFetchedResultsController: SongFetchedResultsController!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        playlistFetchedResultsController = PlaylistFetchedResultsController(managedObjectContext: appDelegate.storage.context, isGroupedInAlphabeticSections: false)
        playlistFetchedResultsController.delegate = self
        artistFetchedResultsController = ArtistFetchedResultsController(managedObjectContext: appDelegate.storage.context, isGroupedInAlphabeticSections: false)
        artistFetchedResultsController.delegate = self
        albumFetchedResultsController = AlbumFetchedResultsController(managedObjectContext: appDelegate.storage.context, isGroupedInAlphabeticSections: false)
        albumFetchedResultsController.delegate = self
        songFetchedResultsController = SongFetchedResultsController(managedObjectContext: appDelegate.storage.context, isGroupedInAlphabeticSections: false)
        songFetchedResultsController.delegate = self
        
        configureSearchController(scopeButtonTitles: ["All", "Cached"])
        tableView.register(nibName: PlaylistTableCell.typeName)
        tableView.register(nibName: ArtistTableCell.typeName)
        tableView.register(nibName: AlbumTableCell.typeName)
        tableView.register(nibName: SongTableCell.typeName)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        // Fetch will only via search be perfromed in this view
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
            cell.display(playlist: playlist)
            return cell
        case LibraryElement.Artist.rawValue:
            let cell: ArtistTableCell = dequeueCell(for: tableView, at: indexPath)
            let artist = artistFetchedResultsController.getWrappedEntity(at: IndexPath(row: indexPath.row, section: 0))
            cell.display(artist: artist)
            return cell
        case LibraryElement.Album.rawValue:
            let cell: AlbumTableCell = dequeueCell(for: tableView, at: indexPath)
            let album = albumFetchedResultsController.getWrappedEntity(at: IndexPath(row: indexPath.row, section: 0))
            cell.display(album: album)
            return cell
        case LibraryElement.Song.rawValue:
            let cell: SongTableCell = dequeueCell(for: tableView, at: indexPath)
            let song = songFetchedResultsController.getWrappedEntity(at: IndexPath(row: indexPath.row, section: 0))
            cell.display(song: song, rootView: self)
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
            playlistFetchedResultsController.search(searchText: searchText, playlistSearchCategory: .all)
            artistFetchedResultsController.search(searchText: searchText)
            albumFetchedResultsController.search(searchText: searchText)
            songFetchedResultsController.search(searchText: searchText, onlyCachedSongs: false)
        } else if searchController.searchBar.selectedScopeButtonIndex == 1 {
            playlistFetchedResultsController.clearResults()
            artistFetchedResultsController.clearResults()
            albumFetchedResultsController.clearResults()
            songFetchedResultsController.search(searchText: searchText, onlyCachedSongs: true)
        } else {
            playlistFetchedResultsController.clearResults()
            artistFetchedResultsController.clearResults()
            albumFetchedResultsController.clearResults()
            songFetchedResultsController.clearResults()
        }
        tableView.reloadData()
    }
    
    override func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange anObject: Any, at indexPath: IndexPath?, for type: NSFetchedResultsChangeType, newIndexPath: IndexPath?) {
        var section: Int = 0
        switch controller {
        case playlistFetchedResultsController:
            section = LibraryElement.Playlist.rawValue
        case artistFetchedResultsController:
            section = LibraryElement.Artist.rawValue
        case albumFetchedResultsController:
            section = LibraryElement.Album.rawValue
        case songFetchedResultsController:
            section = LibraryElement.Song.rawValue
        default:
            return
        }
        
        switch type {
        case .insert:
            tableView.insertRows(at: [IndexPath(row: newIndexPath!.row, section: section)], with: .bottom)
        case .delete:
            tableView.deleteRows(at: [IndexPath(row: indexPath!.row, section: section)], with: .left)
        case .move:
            tableView.deleteRows(at: [IndexPath(row: indexPath!.row, section: section)], with: .top)
            tableView.insertRows(at: [IndexPath(row: newIndexPath!.row, section: section)], with: .bottom)
        case .update:
            tableView.reloadRows(at: [IndexPath(row: indexPath!.row, section: section)], with: .none)
        @unknown default:
            break
        }
    }
    
    override func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange sectionInfo: NSFetchedResultsSectionInfo, atSectionIndex sectionIndex: Int, for type: NSFetchedResultsChangeType) {
    }
    
}
