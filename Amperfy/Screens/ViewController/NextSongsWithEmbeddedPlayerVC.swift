import UIKit

class NextSongsWithEmbeddedPlayerVC: UITableViewController {

    var appDelegate: AppDelegate!
    var player: AmperfyPlayer!
    var playerView: PlayerView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        appDelegate = (UIApplication.shared.delegate as! AppDelegate)
        player = appDelegate.player
        player.addNotifier(notifier: self)
        appDelegate.downloadManager.addNotifier(self)
        tableView.register(nibName: SongTableCell.typeName)
        tableView.rowHeight = SongTableCell.rowHeight
        tableView.isEditing = true
        
        tableView.tableHeaderView = UIView(frame: CGRect(x: 0, y: 0, width: view.bounds.size.width, height: PlayerView.frameHeight))
        if let (fixedView, headerView) = ViewBuilder<PlayerView>.createFromNib(withinFixedFrame: CGRect(x: 0, y: 0, width: view.bounds.size.width, height: PlayerView.frameHeight)) {
            playerView = headerView
            playerView.prepare(toWorkOnRootView: self)
            tableView.tableHeaderView?.addSubview(fixedView)
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        self.tableView.reloadData()
        self.playerView.viewWillAppear(animated)
    }

    // MARK: - Table view data source
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return player.playlist.songs.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell: SongTableCell = dequeueCell(for: tableView, at: indexPath)
        
        let song = player.playlist.songs[indexPath.row]
        
        cell.display(song: song, rootView: self)
        cell.confToPlayPlaylistIndexOnTab(indexInPlaylist: indexPath.row)
        if let currentlyPlaingIndex = player.currentlyPlaying?.index, indexPath.row == currentlyPlaingIndex {
            cell.displayAsPlaying()
        }
        cell.isEditing = true
        
        return cell
    }
    
    // Override to support editing the table view.
    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            player.removeFromPlaylist(at: indexPath.row)
            tableView.deleteRows(at: [indexPath], with: .fade)
        }
    }

    // Override to support rearranging the table view.
    override func tableView(_ tableView: UITableView, moveRowAt fromIndexPath: IndexPath, to: IndexPath) {
        player.movePlaylistSong(fromIndex: fromIndexPath.row, to: to.row)
    }

    // Override to support conditional rearranging of the table view.
    override func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {
    // Return false if you do not want the item to be re-orderable.
    return true
    }
    
    func optionsPressed() {
        let alert = UIAlertController(title: "Next songs", message: nil, preferredStyle: .actionSheet)
        
        alert.addAction(UIAlertAction(title: "Clear", style: .default, handler: { _ in
            self.appDelegate.player.cleanPlaylist()
            self.tableView.reloadData()
        }))
        alert.addAction(UIAlertAction(title: "Add all to playlist", style: .default, handler: { _ in
            let selectPlaylistVC = PlaylistSelectorVC.instantiateFromAppStoryboard()
            selectPlaylistVC.songsToAdd = self.appDelegate.player.playlist.songs
            let selectPlaylistNav = UINavigationController(rootViewController: selectPlaylistVC)
            self.present(selectPlaylistNav, animated: true, completion: nil)
        }))
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.pruneNegativeWidthConstraintsToAvoidFalseConstraintWarnings()
        
        self.present(alert, animated: true, completion: nil)
    }

}

extension NextSongsWithEmbeddedPlayerVC: MusicPlayable {

    func didStartedPlaying(playlistElement: PlaylistElement) {
        tableView.reloadData()
    }
    
    func didStartedPausing() {
    }
    
    func didStopped(playlistElement: PlaylistElement?) {
        if let stoppedPlaylistElement = playlistElement, let index = stoppedPlaylistElement.index, let cell = self.tableView.cellForRow(at: IndexPath(row: index, section: 0)) as? SongTableCell {
            cell.refresh()
        }
    }

    func didElapsedTimeChanged() {
    }
    
    func didUpdatePlaylist() {
        tableView.reloadData()
    }

}

extension NextSongsWithEmbeddedPlayerVC: SongDownloadViewUpdatable {
    
    func downloadManager(_ downloadManager: DownloadManager, updatedRequest: DownloadRequest<Song>, updateReason: SongDownloadRequestEvent) {
        switch(updateReason) {
        case .finished:
            let indicesOfDownloadedSong = player.playlist.songs.allIndices(of: updatedRequest.element)
            for index in indicesOfDownloadedSong {
                if let cell = self.tableView.cellForRow(at: IndexPath(row: index, section: 0)) as? SongTableCell {
                    cell.refresh()
                }
            }
        default:
            break
        }
    }
    
}
