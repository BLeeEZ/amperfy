import UIKit

class AlbumDetailVC: SingleFetchedResultsTableViewController<SongMO> {

    var album: Album!
    private var fetchedResultsController: AlbumSongsFetchedResultsController!
    private var detailOperationsView: AlbumDetailTableHeader?

    override func viewDidLoad() {
        super.viewDidLoad()
        appDelegate.userStatistics.visited(.albumDetail)
        fetchedResultsController = AlbumSongsFetchedResultsController(forAlbum: album, managedObjectContext: appDelegate.persistentStorage.context, isGroupedInAlphabeticSections: false)
        singleFetchedResultsController = fetchedResultsController
        
        configureSearchController(placeholder: "Search in \"Album\"", scopeButtonTitles: ["All", "Cached"])
        tableView.register(nibName: SongTableCell.typeName)
        tableView.rowHeight = SongTableCell.rowHeight
        
        tableView.tableHeaderView = UIView(frame: CGRect(x: 0, y: 0, width: view.bounds.size.width, height: AlbumDetailTableHeader.frameHeight + LibraryElementDetailTableHeaderView.frameHeight))
        if let albumDetailTableHeaderView = ViewBuilder<AlbumDetailTableHeader>.createFromNib(withinFixedFrame: CGRect(x: 0, y: 0, width: view.bounds.size.width, height: AlbumDetailTableHeader.frameHeight)) {
            albumDetailTableHeaderView.prepare(toWorkOnAlbum: album, rootView: self)
            tableView.tableHeaderView?.addSubview(albumDetailTableHeaderView)
            detailOperationsView = albumDetailTableHeaderView
        }
        if let libraryElementDetailTableHeaderView = ViewBuilder<LibraryElementDetailTableHeaderView>.createFromNib(withinFixedFrame: CGRect(x: 0, y: AlbumDetailTableHeader.frameHeight, width: view.bounds.size.width, height: LibraryElementDetailTableHeaderView.frameHeight)) {
            libraryElementDetailTableHeaderView.prepare(playableContainer: album, with: appDelegate.player)
            tableView.tableHeaderView?.addSubview(libraryElementDetailTableHeaderView)
        }
        
        waitingQueueInsertSwipeCallback = { (indexPath) in
            let song = self.fetchedResultsController.getWrappedEntity(at: indexPath)
            self.appDelegate.player.addToWaitingQueueFirst(playable: song)
        }
        nextQueueInsertSwipeCallback = { (indexPath) in
            let song = self.fetchedResultsController.getWrappedEntity(at: indexPath)
            self.appDelegate.player.insertAsNextSongNoPlay(playable: song)
        }
        waitingQueueAppendSwipeCallback = { (indexPath) in
            let song = self.fetchedResultsController.getWrappedEntity(at: indexPath)
            self.appDelegate.player.addToWaitingQueueLast(playable: song)
        }
        nextQueueAppendSwipeCallback = { (indexPath) in
            let song = self.fetchedResultsController.getWrappedEntity(at: indexPath)
            self.appDelegate.player.addToPlaylist(playable: song)
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if appDelegate.persistentStorage.settings.isOnlineMode {
            appDelegate.persistentStorage.persistentContainer.performBackgroundTask() { (context) in
                let library = LibraryStorage(context: context)
                let syncer = self.appDelegate.backendApi.createLibrarySyncer()
                syncer.sync(album: self.album, library: library)
                DispatchQueue.main.async {
                    self.detailOperationsView?.refresh()
                }
            }
        }
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell: SongTableCell = dequeueCell(for: tableView, at: indexPath)
        let song = fetchedResultsController.getWrappedEntity(at: indexPath)
        cell.display(song: song, rootView: self)
        return cell
    }
    
    override func updateSearchResults(for searchController: UISearchController) {
        fetchedResultsController.search(searchText: searchController.searchBar.text ?? "", onlyCachedSongs: searchController.searchBar.selectedScopeButtonIndex == 1 )
        tableView.reloadData()
    }
    
}
