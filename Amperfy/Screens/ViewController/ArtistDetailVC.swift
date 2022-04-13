import UIKit
import CoreData

class ArtistDetailVC: BasicTableViewController {

    var artist: Artist!
    private var albumsFetchedResultsController: ArtistAlbumsItemsFetchedResultsController!
    private var songsFetchedResultsController: ArtistSongsItemsFetchedResultsController!
    private var optionsButton: UIBarButtonItem!
    private var detailOperationsView: GenericDetailTableHeader?

    override func viewDidLoad() {
        super.viewDidLoad()
        appDelegate.userStatistics.visited(.artistDetail)
        
        albumsFetchedResultsController = ArtistAlbumsItemsFetchedResultsController(for: artist, managedObjectContext: appDelegate.persistentStorage.context, isGroupedInAlphabeticSections: false)
        albumsFetchedResultsController.delegate = self
        songsFetchedResultsController = ArtistSongsItemsFetchedResultsController(for: artist, managedObjectContext: appDelegate.persistentStorage.context, isGroupedInAlphabeticSections: false)
        songsFetchedResultsController.delegate = self
        tableView.register(nibName: GenericTableCell.typeName)
        tableView.register(nibName: SongTableCell.typeName)
        
        configureSearchController(placeholder: "Albums and Songs", scopeButtonTitles: ["All", "Cached"])
        tableView.tableHeaderView = UIView(frame: CGRect(x: 0, y: 0, width: view.bounds.size.width, height: GenericDetailTableHeader.frameHeight + LibraryElementDetailTableHeaderView.frameHeight))
        if let genericDetailTableHeaderView = ViewBuilder<GenericDetailTableHeader>.createFromNib(withinFixedFrame: CGRect(x: 0, y: 0, width: view.bounds.size.width, height: GenericDetailTableHeader.frameHeight)) {
            genericDetailTableHeaderView.prepare(toWorkOn: artist, rootView: self)
            tableView.tableHeaderView?.addSubview(genericDetailTableHeaderView)
            detailOperationsView = genericDetailTableHeaderView
        }
        if let libraryElementDetailTableHeaderView = ViewBuilder<LibraryElementDetailTableHeaderView>.createFromNib(withinFixedFrame: CGRect(x: 0, y: GenericDetailTableHeader.frameHeight, width: view.bounds.size.width, height: LibraryElementDetailTableHeaderView.frameHeight)) {
            libraryElementDetailTableHeaderView.prepare(
                playContextCb: {() in PlayContext(containable: self.artist, playables: self.songsFetchedResultsController.getContextSongs(onlyCachedSongs: self.appDelegate.persistentStorage.settings.isOfflineMode) ?? [])},
                with: appDelegate.player)
            tableView.tableHeaderView?.addSubview(libraryElementDetailTableHeaderView)
        }
        
        optionsButton = UIBarButtonItem(image: UIImage.ellipsis, style: .plain, target: self, action: #selector(optionsPressed))
        navigationItem.rightBarButtonItem = optionsButton
        
        containableAtIndexPathCallback = { (indexPath) in
            switch indexPath.section+2 {
            case LibraryElement.Album.rawValue:
                return self.albumsFetchedResultsController.getWrappedEntity(at: IndexPath(row: indexPath.row, section: 0))
            case LibraryElement.Song.rawValue:
                return self.songsFetchedResultsController.getWrappedEntity(at: IndexPath(row: indexPath.row, section: 0))
            default:
                return nil
            }
        }
        swipeCallback = { (indexPath, completionHandler) in
            switch indexPath.section+2 {
            case LibraryElement.Album.rawValue:
                let album = self.albumsFetchedResultsController.getWrappedEntity(at: IndexPath(row: indexPath.row, section: 0))
                album.fetchAsync(storage: self.appDelegate.persistentStorage, backendApi: self.appDelegate.backendApi, playableDownloadManager: self.appDelegate.playableDownloadManager) {
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
        artist.fetchAsync(storage: self.appDelegate.persistentStorage, backendApi: self.appDelegate.backendApi, playableDownloadManager: self.appDelegate.playableDownloadManager) {
            self.detailOperationsView?.refresh()
        }
    }

    func convertIndexPathToPlayContext(songIndexPath: IndexPath) -> PlayContext? {
        guard let songs = self.songsFetchedResultsController.getContextSongs(onlyCachedSongs: self.appDelegate.persistentStorage.settings.isOfflineMode)
        else { return nil }
        let selectedSong = self.songsFetchedResultsController.getWrappedEntity(at: songIndexPath)
        guard let playContextIndex = songs.firstIndex(of: selectedSong) else { return nil }
        return PlayContext(containable: artist, index: playContextIndex, playables: songs)
    }
    
    func convertCellViewToPlayContext(cell: UITableViewCell) -> PlayContext? {
        guard let indexPath = tableView.indexPath(for: cell),
              indexPath.section+2 == LibraryElement.Song.rawValue
        else { return nil }
        return convertIndexPathToPlayContext(songIndexPath: IndexPath(row: indexPath.row, section: 0))
    }
    
    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 2
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch section+2 {
        case LibraryElement.Album.rawValue:
            return "Albums"
        case LibraryElement.Song.rawValue:
            return "Songs"
        default:
            return ""
        }
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch section+2 {
        case LibraryElement.Album.rawValue:
            return albumsFetchedResultsController.sections?[0].numberOfObjects ?? 0
        case LibraryElement.Song.rawValue:
            return songsFetchedResultsController.sections?[0].numberOfObjects ?? 0
        default:
            return 0
        }
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch indexPath.section+2 {
        case LibraryElement.Album.rawValue:
            let cell: GenericTableCell = dequeueCell(for: tableView, at: indexPath)
            let album = albumsFetchedResultsController.getWrappedEntity(at: IndexPath(row: indexPath.row, section: 0))
            cell.display(container: album, rootView: self)
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
        switch section+2 {
        case LibraryElement.Album.rawValue:
            return albumsFetchedResultsController.sections?[0].numberOfObjects ?? 0 > 0 ? CommonScreenOperations.tableSectionHeightLarge : 0
        case LibraryElement.Song.rawValue:
            return songsFetchedResultsController.sections?[0].numberOfObjects ?? 0 > 0 ? CommonScreenOperations.tableSectionHeightLarge : 0
        default:
            return 0.0
        }
    }
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        switch indexPath.section+2 {
        case LibraryElement.Album.rawValue:
            return GenericTableCell.rowHeight
        case LibraryElement.Song.rawValue:
            return SongTableCell.rowHeight
        default:
            return 0.0
        }
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        switch indexPath.section+2 {
        case LibraryElement.Album.rawValue:
            let album = albumsFetchedResultsController.getWrappedEntity(at: IndexPath(row: indexPath.row, section: 0))
            performSegue(withIdentifier: Segues.toAlbumDetail.rawValue, sender: album)
        case LibraryElement.Song.rawValue: break
        default: break
        }
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == Segues.toAlbumDetail.rawValue {
            let vc = segue.destination as! AlbumDetailVC
            let album = sender as? Album
            vc.album = album
        }
    }
    
    override func updateSearchResults(for searchController: UISearchController) {
        guard let searchText = searchController.searchBar.text else { return }
        if searchText.count > 0, searchController.searchBar.selectedScopeButtonIndex == 0 {
            albumsFetchedResultsController.search(searchText: searchText, onlyCached: false)
            songsFetchedResultsController.search(searchText: searchText, onlyCachedSongs: false)
        } else if searchController.searchBar.selectedScopeButtonIndex == 1 {
            albumsFetchedResultsController.search(searchText: searchText, onlyCached: true)
            songsFetchedResultsController.search(searchText: searchText, onlyCachedSongs: true)
        } else {
            albumsFetchedResultsController.showAllResults()
            songsFetchedResultsController.showAllResults()
        }
        tableView.reloadData()
    }
    
    override func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange anObject: Any, at indexPath: IndexPath?, for type: NSFetchedResultsChangeType, newIndexPath: IndexPath?) {
        var section: Int = 0
        switch controller {
        case albumsFetchedResultsController.fetchResultsController:
            section = LibraryElement.Album.rawValue - 2
        case songsFetchedResultsController.fetchResultsController:
            section = LibraryElement.Song.rawValue - 2
        default:
            return
        }
        
        super.applyChangesOfMultiRowType(determinedSection: section, at: indexPath, for: type, newIndexPath: newIndexPath)
    }
    
    override func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange sectionInfo: NSFetchedResultsSectionInfo, atSectionIndex sectionIndex: Int, for type: NSFetchedResultsChangeType) {
    }
    
    @objc private func optionsPressed() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
        guard let artist = self.artist else { return }
        let detailVC = LibraryEntityDetailVC()
        detailVC.display(container: artist, on: self)
        present(detailVC, animated: true)
    }
    
}
