import UIKit

class PlaylistDetailVC: UITableViewController {

    var appDelegate: AppDelegate!
    var playlist: Playlist?
    
    var editButton: UIBarButtonItem!
    var doneButton: UIBarButtonItem!
    var playlistOperationsView: PlaylistDetailTableHeader?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        appDelegate = (UIApplication.shared.delegate as! AppDelegate)
        tableView.register(nibName: SongTableCell.typeName)
        tableView.rowHeight = SongTableCell.rowHeight
        
        editButton = UIBarButtonItem(title: "Edit", style: .plain, target: self, action: #selector(startEditing))
        doneButton = UIBarButtonItem(title: "Done", style: .plain, target: self, action: #selector(endEditing))
        navigationItem.rightBarButtonItem = editButton
        
        tableView.tableHeaderView = UIView(frame: CGRect(x: 0, y: 0, width: view.bounds.size.width, height: PlaylistDetailTableHeader.frameHeight + LibraryElementDetailTableHeaderView.frameHeight))
        if let (fixedView, headerView) = ViewBuilder<PlaylistDetailTableHeader>.createFromNib(withinFixedFrame: CGRect(x: 0, y: 0, width: view.bounds.size.width, height: PlaylistDetailTableHeader.frameHeight)) {
            headerView.prepare(toWorkOnPlaylist: playlist, rootView: self)
            tableView.tableHeaderView?.addSubview(fixedView)
            playlistOperationsView = headerView
        }
        if let (fixedView, headerView) = ViewBuilder<LibraryElementDetailTableHeaderView>.createFromNib(withinFixedFrame: CGRect(x: 0, y: PlaylistDetailTableHeader.frameHeight, width: view.bounds.size.width, height: LibraryElementDetailTableHeaderView.frameHeight)) {
            headerView.prepare(toWorkOnPlaylist: playlist, with: appDelegate.player)
            tableView.tableHeaderView?.addSubview(fixedView)
        }
        self.refreshControl?.addTarget(self, action: #selector(PlaylistsVC.handleRefresh), for: UIControl.Event.valueChanged)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        self.tableView.reloadData()
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
    
    // MARK: - Table view data source
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return playlist?.songs.count ?? 0
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell: SongTableCell = dequeueCell(for: tableView, at: indexPath)
        
        if let song = playlist?.songs[indexPath.row] {
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
            playlist?.remove(at: indexPath.row)
            tableView.deleteRows(at: [indexPath], with: .fade)
        }
    }
    
    // Override to support rearranging the table view.
    override func tableView(_ tableView: UITableView, moveRowAt fromIndexPath: IndexPath, to: IndexPath) {
        playlist?.movePlaylistSong(fromIndex: fromIndexPath.row, to: to.row)
    }
    
    // Override to support conditional rearranging of the table view.
    override func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {
        // Return false if you do not want the item to be re-orderable.
        return true
    }
    
    @objc func handleRefresh(refreshControl: UIRefreshControl) {
        appDelegate.storage.persistentContainer.performBackgroundTask() { (context) in
            let backgroundStorage = LibraryStorage(context: context)
            let syncer = self.appDelegate.backendApi.createLibrarySyncer()
            guard let playlistMain = self.playlist, let playlistAsync = backgroundStorage.getPlaylist(id: playlistMain.id) else { return }
            syncer.syncDown(playlist: playlistAsync, libraryStorage: backgroundStorage, statusNotifyier: self)
        }
    }
    
}

extension PlaylistDetailVC: PlaylistSyncCallbacks {
    
    func notifyPlaylistWillCleared() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.playlist = nil
            self.tableView.reloadData()
            self.playlistOperationsView?.refreshArtworks(playlist: nil)
        }
    }
    
    func notifyPlaylistSyncFinished(playlist: Playlist) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.playlist = self.appDelegate.persistentLibraryStorage.getPlaylist(id: playlist.id)
            self.tableView.reloadData()
            self.playlistOperationsView?.refresh()
            self.refreshControl?.endRefreshing()
        }
    }

    func notifyPlaylistUploadFinished(success: Bool) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            if success {
                let alert = UIAlertController(title: "Upload successful", message: nil, preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "OK", style: .default))
                self.present(alert, animated: true, completion: nil)
            } else {
                let alert = UIAlertController(title: "Upload failed", message: nil, preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "OK", style: .default))
                self.present(alert, animated: true, completion: nil)
            }
        }
    }
    
}
