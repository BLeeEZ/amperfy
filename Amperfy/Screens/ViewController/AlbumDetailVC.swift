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
        tableView.register(nibName: AlbumSongTableCell.typeName)
        tableView.rowHeight = AlbumSongTableCell.albumSongRowHeight
        
        tableView.tableHeaderView = UIView(frame: CGRect(x: 0, y: 0, width: view.bounds.size.width, height: AlbumDetailTableHeader.frameHeight + LibraryElementDetailTableHeaderView.frameHeight))
        if let albumDetailTableHeaderView = ViewBuilder<AlbumDetailTableHeader>.createFromNib(withinFixedFrame: CGRect(x: 0, y: 0, width: view.bounds.size.width, height: AlbumDetailTableHeader.frameHeight)) {
            albumDetailTableHeaderView.prepare(toWorkOnAlbum: album, rootView: self)
            tableView.tableHeaderView?.addSubview(albumDetailTableHeaderView)
            detailOperationsView = albumDetailTableHeaderView
        }
        if let libraryElementDetailTableHeaderView = ViewBuilder<LibraryElementDetailTableHeaderView>.createFromNib(withinFixedFrame: CGRect(x: 0, y: AlbumDetailTableHeader.frameHeight, width: view.bounds.size.width, height: LibraryElementDetailTableHeaderView.frameHeight)) {
            libraryElementDetailTableHeaderView.prepare(
                playContextCb: {() in PlayContext(name: self.album.name, playables: self.fetchedResultsController.getContextSongs(onlyCachedSongs: self.appDelegate.persistentStorage.settings.isOfflineMode) ?? [])},
                with: appDelegate.player)
            tableView.tableHeaderView?.addSubview(libraryElementDetailTableHeaderView)
        }
        
        swipeCallback = { (indexPath, completionHandler) in
            let song = self.fetchedResultsController.getWrappedEntity(at: indexPath)
            let playContext = self.convertIndexPathToPlayContext(songIndexPath: indexPath)
            completionHandler(SwipeActionContext(containable: song, playContext: playContext))
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        album.fetchAsync(storage: self.appDelegate.persistentStorage, backendApi: self.appDelegate.backendApi) {
            self.detailOperationsView?.refresh()
        }
    }
    
    func convertIndexPathToPlayContext(songIndexPath: IndexPath) -> PlayContext? {
        guard let songs = self.fetchedResultsController.getContextSongs(onlyCachedSongs: self.appDelegate.persistentStorage.settings.isOfflineMode)
        else { return nil }
        let selectedSong = self.fetchedResultsController.getWrappedEntity(at: songIndexPath)
        guard let playContextIndex = songs.firstIndex(of: selectedSong) else { return nil }
        return PlayContext(name: album.name, index: playContextIndex, playables: songs)
    }
    
    func convertCellViewToPlayContext(cell: UITableViewCell) -> PlayContext? {
        guard let indexPath = tableView.indexPath(for: cell) else { return nil }
        return convertIndexPathToPlayContext(songIndexPath: indexPath)
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell: AlbumSongTableCell = dequeueCell(for: tableView, at: indexPath)
        let song = fetchedResultsController.getWrappedEntity(at: indexPath)
        cell.display(song: song, playContextCb: convertCellViewToPlayContext, rootView: self)
        return cell
    }
    
    override func updateSearchResults(for searchController: UISearchController) {
        fetchedResultsController.search(searchText: searchController.searchBar.text ?? "", onlyCachedSongs: searchController.searchBar.selectedScopeButtonIndex == 1 )
        tableView.reloadData()
    }
    
}
