import UIKit

class PlaylistDetailVC: SingleFetchedResultsTableViewController<PlaylistItemMO> {

    private var fetchedResultsController: PlaylistItemsFetchedResultsController!
    var playlist: Playlist!
    
    private var editButton: UIBarButtonItem!
    private var doneButton: UIBarButtonItem!
    private var optionsButton: UIBarButtonItem!
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
        optionsButton = UIBarButtonItem(image: UIImage.ellipsis, style: .plain, target: self, action: #selector(optionsPressed))
        
        let playlistTableHeaderFrameHeight = PlaylistDetailTableHeader.frameHeight
        tableView.tableHeaderView = UIView(frame: CGRect(x: 0, y: 0, width: view.bounds.size.width, height: playlistTableHeaderFrameHeight + LibraryElementDetailTableHeaderView.frameHeight))

        if let playlistDetailTableHeaderView = ViewBuilder<PlaylistDetailTableHeader>.createFromNib(withinFixedFrame: CGRect(x: 0, y: 0, width: view.bounds.size.width, height: playlistTableHeaderFrameHeight)) {
            playlistDetailTableHeaderView.prepare(toWorkOnPlaylist: playlist, rootView: self)
            tableView.tableHeaderView?.addSubview(playlistDetailTableHeaderView)
            playlistOperationsView = playlistDetailTableHeaderView
        }
        if let libraryElementDetailTableHeaderView = ViewBuilder<LibraryElementDetailTableHeaderView>.createFromNib(withinFixedFrame: CGRect(x: 0, y: playlistTableHeaderFrameHeight, width: view.bounds.size.width, height: LibraryElementDetailTableHeaderView.frameHeight)) {
            libraryElementDetailTableHeaderView.prepare(
                playContextCb: {() in PlayContext(containable: self.playlist, playables: self.fetchedResultsController.getContextSongs(onlyCachedSongs: self.appDelegate.persistentStorage.settings.isOfflineMode) ?? [])},
                with: appDelegate.player)
            tableView.tableHeaderView?.addSubview(libraryElementDetailTableHeaderView)
        }
        self.refreshControl?.addTarget(self, action: #selector(Self.handleRefresh), for: UIControl.Event.valueChanged)
        
        containableAtIndexPathCallback = { (indexPath) in
            return self.fetchedResultsController.getWrappedEntity(at: indexPath).playable
        }
        swipeCallback = { (indexPath, completionHandler) in
            let playlistItem = self.fetchedResultsController.getWrappedEntity(at: indexPath)
            if let song = playlistItem.playable {
                let playContext = self.convertIndexPathToPlayContext(songIndexPath: indexPath)
                completionHandler(SwipeActionContext(containable: song, playContext: playContext))
            }
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        refreshBarButtons()
        playlist.fetchAsync(storage: self.appDelegate.persistentStorage, backendApi: self.appDelegate.backendApi) {
            self.playlistOperationsView?.refresh()
        }
    }
    
    func refreshBarButtons() {
        var edititingBarButton: UIBarButtonItem? = nil
        if !tableView.isEditing {
            if appDelegate.persistentStorage.settings.isOnlineMode {
                edititingBarButton = editButton
                if playlist?.isSmartPlaylist ?? false {
                    edititingBarButton?.isEnabled = false
                }
            }
        } else {
            edititingBarButton = doneButton
        }
        navigationItem.rightBarButtonItems = [optionsButton, edititingBarButton].compactMap{$0}
    }
    
    func convertIndexPathToPlayContext(songIndexPath: IndexPath) -> PlayContext? {
        guard let songs = fetchedResultsController.getContextSongs(onlyCachedSongs: appDelegate.persistentStorage.settings.isOfflineMode)
        else { return nil }
        return PlayContext(containable: playlist, index: songIndexPath.row, playables: songs)
    }
    
    func convertCellViewToPlayContext(cell: UITableViewCell) -> PlayContext? {
        guard let indexPath = tableView.indexPath(for: cell)
        else { return nil }
        return convertIndexPathToPlayContext(songIndexPath: IndexPath(row: indexPath.row, section: 0))
    }

    @objc private func startEditing() {
        tableView.isEditing = true
        playlistOperationsView?.startEditing()
        refreshBarButtons()
    }
    
    @objc private func endEditing() {
        tableView.isEditing = false
        playlistOperationsView?.endEditing()
        refreshBarButtons()
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell: SongTableCell = dequeueCell(for: tableView, at: indexPath)
        let playlistItem = fetchedResultsController.getWrappedEntity(at: indexPath)
        if let playable = playlistItem.playable, let song = playable.asSong {
            cell.display(song: song, playContextCb: convertCellViewToPlayContext, rootView: self)
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
    
    override func updateSearchResults(for searchController: UISearchController) {
        fetchedResultsController.search(onlyCachedSongs: appDelegate.persistentStorage.settings.isOfflineMode)
        tableView.reloadData()
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
    
    @objc private func optionsPressed() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
        guard let playlist = self.playlist else { return }
        let detailVC = LibraryEntityDetailVC()
        detailVC.display(container: playlist, on: self)
        present(detailVC, animated: true)
    }

}
