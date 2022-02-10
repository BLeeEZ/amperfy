import UIKit
import CoreData

class GenreDetailVC: BasicTableViewController {

    var genre: Genre!
    private var artistsFetchedResultsController: GenreArtistsFetchedResultsController!
    private var albumsFetchedResultsController: GenreAlbumsFetchedResultsController!
    private var songsFetchedResultsController: GenreSongsFetchedResultsController!
    private var detailOperationsView: GenreDetailTableHeader?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        appDelegate.userStatistics.visited(.genreDetail)
        
        artistsFetchedResultsController = GenreArtistsFetchedResultsController(for: genre, managedObjectContext: appDelegate.persistentStorage.context, isGroupedInAlphabeticSections: false)
        artistsFetchedResultsController.delegate = self
        albumsFetchedResultsController = GenreAlbumsFetchedResultsController(for: genre, managedObjectContext: appDelegate.persistentStorage.context, isGroupedInAlphabeticSections: false)
        albumsFetchedResultsController.delegate = self
        songsFetchedResultsController = GenreSongsFetchedResultsController(for: genre, managedObjectContext: appDelegate.persistentStorage.context, isGroupedInAlphabeticSections: false)
        songsFetchedResultsController.delegate = self
        tableView.register(nibName: ArtistTableCell.typeName)
        tableView.register(nibName: AlbumTableCell.typeName)
        tableView.register(nibName: SongTableCell.typeName)
        
        configureSearchController(placeholder: "Artists, Albums and Songs", scopeButtonTitles: ["All", "Cached"])
        tableView.tableHeaderView = UIView(frame: CGRect(x: 0, y: 0, width: view.bounds.size.width, height: GenreDetailTableHeader.frameHeight + LibraryElementDetailTableHeaderView.frameHeight))
        if let genreDetailTableHeaderView = ViewBuilder<GenreDetailTableHeader>.createFromNib(withinFixedFrame: CGRect(x: 0, y: 0, width: view.bounds.size.width, height: GenreDetailTableHeader.frameHeight)) {
            genreDetailTableHeaderView.prepare(toWorkOn: genre, rootView: self)
            tableView.tableHeaderView?.addSubview(genreDetailTableHeaderView)
            detailOperationsView = genreDetailTableHeaderView
        }
        if let libraryElementDetailTableHeaderView = ViewBuilder<LibraryElementDetailTableHeaderView>.createFromNib(withinFixedFrame: CGRect(x: 0, y: GenreDetailTableHeader.frameHeight, width: view.bounds.size.width, height: LibraryElementDetailTableHeaderView.frameHeight)) {
            libraryElementDetailTableHeaderView.prepare(
                playContextCb: {() in PlayContext(name: self.genre.name, playables: self.songsFetchedResultsController.getContextSongs(onlyCachedSongs: self.appDelegate.persistentStorage.settings.isOfflineMode) ?? [])},
                with: appDelegate.player)
            tableView.tableHeaderView?.addSubview(libraryElementDetailTableHeaderView)
        }
        
        swipeCallback = { (indexPath, completionHandler) in
            switch indexPath.section+1 {
            case LibraryElement.Artist.rawValue:
                let artist = self.artistsFetchedResultsController.getWrappedEntity(at: IndexPath(row: indexPath.row, section: 0))
                artist.fetchAsync(storage: self.appDelegate.persistentStorage, backendApi: self.appDelegate.backendApi) {
                    completionHandler(SwipeActionContext(containable: artist))
                }
            case LibraryElement.Album.rawValue:
                let album = self.albumsFetchedResultsController.getWrappedEntity(at: IndexPath(row: indexPath.row, section: 0))
                album.fetchAsync(storage: self.appDelegate.persistentStorage, backendApi: self.appDelegate.backendApi) {
                    completionHandler(SwipeActionContext(containable: album))
                }
            case LibraryElement.Song.rawValue:
                let songIndexPath = IndexPath(row: indexPath.row, section: 0)
                let song = self.songsFetchedResultsController.getWrappedEntity(at: songIndexPath)
                let playContext = self.convertIndexPathToPlayContext(songIndexPath: songIndexPath)
                completionHandler(SwipeActionContext(containable: song, playContext: playContext))
            default:
                completionHandler(nil)
            }
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        genre.fetchAsync(storage: self.appDelegate.persistentStorage, backendApi: self.appDelegate.backendApi) {
            self.detailOperationsView?.refresh()
        }
    }
    
    func convertIndexPathToPlayContext(songIndexPath: IndexPath) -> PlayContext? {
        guard let songs = self.songsFetchedResultsController.getContextSongs(onlyCachedSongs: self.appDelegate.persistentStorage.settings.isOfflineMode)
        else { return nil }
        let selectedSong = self.songsFetchedResultsController.getWrappedEntity(at: songIndexPath)
        guard let playContextIndex = songs.firstIndex(of: selectedSong) else { return nil }
        return PlayContext(name: genre.name, index: playContextIndex, playables: songs)
    }
    
    func convertCellViewToPlayContext(cell: UITableViewCell) -> PlayContext? {
        guard let indexPath = tableView.indexPath(for: cell),
              indexPath.section+1 == LibraryElement.Song.rawValue
        else { return nil }
        return convertIndexPathToPlayContext(songIndexPath: IndexPath(row: indexPath.row, section: 0))
    }

    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 3
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch section+1 {
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
        switch section+1 {
        case LibraryElement.Artist.rawValue:
            return artistsFetchedResultsController.sections?[0].numberOfObjects ?? 0
        case LibraryElement.Album.rawValue:
            return albumsFetchedResultsController.sections?[0].numberOfObjects ?? 0
        case LibraryElement.Song.rawValue:
            return songsFetchedResultsController.sections?[0].numberOfObjects ?? 0
        default:
            return 0
        }
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch indexPath.section+1 {
        case LibraryElement.Artist.rawValue:
            let cell: ArtistTableCell = dequeueCell(for: tableView, at: indexPath)
            let artist = artistsFetchedResultsController.getWrappedEntity(at: IndexPath(row: indexPath.row, section: 0))
            cell.display(artist: artist, rootView: self)
            return cell
        case LibraryElement.Album.rawValue:
            let cell: AlbumTableCell = dequeueCell(for: tableView, at: indexPath)
            let album = albumsFetchedResultsController.getWrappedEntity(at: IndexPath(row: indexPath.row, section: 0))
            cell.display(album: album, rootView: self)
            return cell
        case LibraryElement.Song.rawValue:
            let cell: SongTableCell = dequeueCell(for: tableView, at: indexPath)
            let song = songsFetchedResultsController.getWrappedEntity(at: IndexPath(row: indexPath.row, section: 0))
            cell.display(song: song, playContextCb: self.convertCellViewToPlayContext, rootView: self)
            return cell
        default:
            return UITableViewCell()
        }
    }
    
    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        switch section+1 {
        case LibraryElement.Artist.rawValue:
            return artistsFetchedResultsController.sections?[0].numberOfObjects ?? 0 > 0 ? CommonScreenOperations.tableSectionHeightLarge : 0
        case LibraryElement.Album.rawValue:
            return albumsFetchedResultsController.sections?[0].numberOfObjects ?? 0 > 0 ? CommonScreenOperations.tableSectionHeightLarge : 0
        case LibraryElement.Song.rawValue:
            return songsFetchedResultsController.sections?[0].numberOfObjects ?? 0 > 0 ? CommonScreenOperations.tableSectionHeightLarge : 0
        default:
            return 0.0
        }
    }
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        switch indexPath.section+1 {
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
        switch indexPath.section+1 {
        case LibraryElement.Artist.rawValue:
            let artist = artistsFetchedResultsController.getWrappedEntity(at: IndexPath(row: indexPath.row, section: 0))
            performSegue(withIdentifier: Segues.toArtistDetail.rawValue, sender: artist)
        case LibraryElement.Album.rawValue:
            let album = albumsFetchedResultsController.getWrappedEntity(at: IndexPath(row: indexPath.row, section: 0))
            performSegue(withIdentifier: Segues.toAlbumDetail.rawValue, sender: album)
        case LibraryElement.Song.rawValue: break
        default: break
        }
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == Segues.toArtistDetail.rawValue {
            let vc = segue.destination as! ArtistDetailVC
            let artist = sender as? Artist
            vc.artist = artist
        }
        if segue.identifier == Segues.toAlbumDetail.rawValue {
            let vc = segue.destination as! AlbumDetailVC
            let album = sender as? Album
            vc.album = album
        }
    }
    
    override func updateSearchResults(for searchController: UISearchController) {
        guard let searchText = searchController.searchBar.text else { return }
        if searchText.count > 0, searchController.searchBar.selectedScopeButtonIndex == 0 {
            artistsFetchedResultsController.search(searchText: searchText, onlyCached: false)
            albumsFetchedResultsController.search(searchText: searchText, onlyCached: false)
            songsFetchedResultsController.search(searchText: searchText, onlyCachedSongs: false)
        } else if searchController.searchBar.selectedScopeButtonIndex == 1 {
            artistsFetchedResultsController.search(searchText: searchText, onlyCached: true)
            albumsFetchedResultsController.search(searchText: searchText, onlyCached: true)
            songsFetchedResultsController.search(searchText: searchText, onlyCachedSongs: true)
        } else {
            artistsFetchedResultsController.showAllResults()
            albumsFetchedResultsController.showAllResults()
            songsFetchedResultsController.showAllResults()
        }
        tableView.reloadData()
    }
    
    override func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange anObject: Any, at indexPath: IndexPath?, for type: NSFetchedResultsChangeType, newIndexPath: IndexPath?) {
        var section: Int = 0
        switch controller {
        case artistsFetchedResultsController.fetchResultsController:
            section = LibraryElement.Artist.rawValue - 1
        case albumsFetchedResultsController.fetchResultsController:
            section = LibraryElement.Album.rawValue - 1
        case songsFetchedResultsController.fetchResultsController:
            section = LibraryElement.Song.rawValue - 1
        default:
            return
        }
        
        super.applyChangesOfMultiRowType(determinedSection: section, at: indexPath, for: type, newIndexPath: newIndexPath)
    }
    
    override func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange sectionInfo: NSFetchedResultsSectionInfo, atSectionIndex sectionIndex: Int, for type: NSFetchedResultsChangeType) {
    }
    
}
