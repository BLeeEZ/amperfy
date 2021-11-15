import UIKit

class PlaylistDetailVC: SingleFetchedResultsTableViewController<PlaylistItemMO> {

    private var fetchedResultsController: PlaylistItemsFetchedResultsController!
    var playlist: Playlist!
    
    var editButton: UIBarButtonItem!
    var doneButton: UIBarButtonItem!
    var playlistOperationsView: PlaylistDetailTableHeader?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        appDelegate.userStatistics.visited(.playlistDetail)
        fetchedResultsController = PlaylistItemsFetchedResultsController(forPlaylist: playlist, managedObjectContext: appDelegate.persistentStorage.context, isGroupedInAlphabeticSections: false)
        singleFetchedResultsController = fetchedResultsController
        
        tableView.register(nibName: SongTableCell.typeName)
        tableView.rowHeight = SongTableCell.rowHeight
        
        editButton = UIBarButtonItem(title: "Edit", style: .plain, target: self, action: #selector(startEditing))
        doneButton = UIBarButtonItem(title: "Done", style: .plain, target: self, action: #selector(endEditing))
        
        let playlistTableHeaderFrameHeight = PlaylistDetailTableHeader.frameHeight
        tableView.tableHeaderView = UIView(frame: CGRect(x: 0, y: 0, width: view.bounds.size.width, height: playlistTableHeaderFrameHeight + LibraryElementDetailTableHeaderView.frameHeight))

        if let playlistDetailTableHeaderView = ViewBuilder<PlaylistDetailTableHeader>.createFromNib(withinFixedFrame: CGRect(x: 0, y: 0, width: view.bounds.size.width, height: playlistTableHeaderFrameHeight)) {
            playlistDetailTableHeaderView.prepare(toWorkOnPlaylist: playlist, rootView: self)
            tableView.tableHeaderView?.addSubview(playlistDetailTableHeaderView)
            playlistOperationsView = playlistDetailTableHeaderView
        }
        if let libraryElementDetailTableHeaderView = ViewBuilder<LibraryElementDetailTableHeaderView>.createFromNib(withinFixedFrame: CGRect(x: 0, y: playlistTableHeaderFrameHeight, width: view.bounds.size.width, height: LibraryElementDetailTableHeaderView.frameHeight)) {
            libraryElementDetailTableHeaderView.prepare(playableContainer: playlist, with: appDelegate.player)
            tableView.tableHeaderView?.addSubview(libraryElementDetailTableHeaderView)
        }
        self.refreshControl?.addTarget(self, action: #selector(Self.handleRefresh), for: UIControl.Event.valueChanged)
        
        waitingQueueSwipeCallback = { (indexPath) in
            let playlistItem = self.fetchedResultsController.getWrappedEntity(at: indexPath)
            if let playable = playlistItem.playable {
                self.appDelegate.player.addToWaitingQueue(playable: playable)
            }
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if appDelegate.persistentStorage.settings.isOnlineMode {
            navigationItem.rightBarButtonItem = editButton
            if playlist?.isSmartPlaylist ?? false {
                navigationItem.rightBarButtonItem?.isEnabled = false
            }
        } else {
            navigationItem.rightBarButtonItem = nil
        }
        if appDelegate.persistentStorage.settings.isOnlineMode {
            appDelegate.persistentStorage.persistentContainer.performBackgroundTask() { (context) in
                let syncLibrary = LibraryStorage(context: context)
                let syncer = self.appDelegate.backendApi.createLibrarySyncer()
                let playlistAsync = self.playlist.getManagedObject(in: context, library: syncLibrary)
                syncer.syncDown(playlist: playlistAsync, library: syncLibrary)
                DispatchQueue.main.async {
                    self.playlistOperationsView?.refresh()
                }
            }
        }
    }
    
    @objc private func startEditing() {
        navigationItem.rightBarButtonItem = doneButton
        tableView.isEditing = true
        playlistOperationsView?.startEditing()
    }
    
    @objc private func endEditing() {
        navigationItem.rightBarButtonItem = editButton
        tableView.isEditing = false
        playlistOperationsView?.endEditing()
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell: SongTableCell = dequeueCell(for: tableView, at: indexPath)
        let playlistItem = fetchedResultsController.getWrappedEntity(at: indexPath)
        if let playable = playlistItem.playable, let song = playable.asSong {
            cell.display(song: song, rootView: self)
        }
        return cell
    }
    
    override func tableView(_ tableView: UITableView, editingStyleForRowAt indexPath: IndexPath) -> UITableViewCell.EditingStyle {
        if tableView.isEditing {
            return .delete
        }
        return .none
    }
    
    // Override to support editing the table view.
    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            playlist.remove(at: indexPath.row)
            self.playlistOperationsView?.refresh()
            if appDelegate.persistentStorage.settings.isOnlineMode {
                appDelegate.persistentStorage.persistentContainer.performBackgroundTask() { (context) in
                    let syncLibrary = LibraryStorage(context: context)
                    let syncer = self.appDelegate.backendApi.createLibrarySyncer()
                    let playlistAsync = self.playlist.getManagedObject(in: context, library: syncLibrary)
                    syncer.syncUpload(playlistToDeleteSong: playlistAsync, index: indexPath.row, library: syncLibrary)
                }
            }
        }
    }
    
    // Override to support rearranging the table view.
    override func tableView(_ tableView: UITableView, moveRowAt fromIndexPath: IndexPath, to: IndexPath) {
        noAnimationAtNextDataChange = true
        playlist.movePlaylistItem(fromIndex: fromIndexPath.row, to: to.row)
        if appDelegate.persistentStorage.settings.isOnlineMode {
            appDelegate.persistentStorage.persistentContainer.performBackgroundTask() { (context) in
                let syncLibrary = LibraryStorage(context: context)
                let syncer = self.appDelegate.backendApi.createLibrarySyncer()
                let playlistAsync = self.playlist.getManagedObject(in: context, library: syncLibrary)
                syncer.syncUpload(playlistToUpdateOrder: playlistAsync, library: syncLibrary)
            }
        }
    }
    
    // Override to support conditional rearranging of the table view.
    override func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {
        // Return false if you do not want the item to be re-orderable.
        return true
    }
    
    @objc func handleRefresh(refreshControl: UIRefreshControl) {
        appDelegate.persistentStorage.persistentContainer.performBackgroundTask() { (context) in
            let syncLibrary = LibraryStorage(context: context)
            let syncer = self.appDelegate.backendApi.createLibrarySyncer()
            let playlistAsync = self.playlist.getManagedObject(in: context, library: syncLibrary)
            syncer.syncDown(playlist: playlistAsync, library: syncLibrary)
            DispatchQueue.main.async {
                self.playlistOperationsView?.refresh()
                self.refreshControl?.endRefreshing()
            }
        }
    }
    
    override func updateSearchResults(for searchController: UISearchController) {
        fetchedResultsController.fetch()
        tableView.reloadData()
    }
    
}
