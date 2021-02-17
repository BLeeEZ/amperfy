import UIKit

class PopupPlayerVC: UIViewController, UITableViewDelegate, UITableViewDataSource {

    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var playerPlaceholderView: UIView!
    
    var appDelegate: AppDelegate!
    var player: MusicPlayer!
    var playerView: PlayerView!
    var hostingTabBarVC: TabBarVC?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.tableView.delegate = self
        self.tableView.dataSource = self
        if let createdPlayerView = ViewBuilder<PlayerView>.createFromNib(withinFixedFrame: CGRect(x: 0, y: 0, width: playerPlaceholderView.bounds.size.width, height: playerPlaceholderView.bounds.size.height)) {
            assert(playerPlaceholderView.bounds.size.height >= PlayerView.frameHeight, "Placeholder must provide enough height for player")
            playerView = createdPlayerView
            playerView.prepare(toWorkOnRootView: self)
            playerPlaceholderView.addSubview(playerView)
        }

        appDelegate = (UIApplication.shared.delegate as! AppDelegate)
        player = appDelegate.player
        player.addNotifier(notifier: self)
        appDelegate.downloadManager.addNotifier(self)
        tableView.register(nibName: SongTableCell.typeName)
        tableView.rowHeight = SongTableCell.rowHeight
        tableView.isEditing = true
    }
    
    override func viewWillAppear(_ animated: Bool) {
        self.tableView.reloadData()
        self.playerView.viewWillAppear(animated)
    }

    // MARK: - Table view data source
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return player.playlist.songs.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell: SongTableCell = self.tableView.dequeueCell(for: tableView, at: indexPath)
        
        let song = player.playlist.songs[indexPath.row]
        
        cell.display(song: song, rootView: self)
        cell.confToPlayPlaylistIndexOnTab(indexInPlaylist: indexPath.row)
        if let currentlyPlaingIndex = player.currentlyPlaying?.index, indexPath.row == currentlyPlaingIndex {
            cell.displayAsPlaying()
        }
        
        return cell
    }
    
    // Override to support editing the table view.
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            player.removeFromPlaylist(at: indexPath.row)
            tableView.deleteRows(at: [indexPath], with: .fade)
        }
    }

    // Override to support rearranging the table view.
    func tableView(_ tableView: UITableView, moveRowAt fromIndexPath: IndexPath, to: IndexPath) {
        player.movePlaylistSong(fromIndex: fromIndexPath.row, to: to.row)
    }

    // Override to support conditional rearranging of the table view.
    func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {
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
        alert.setOptionsForIPadToDisplayPopupCentricIn(view: self.view)
        
        self.present(alert, animated: true, completion: nil)
    }

}

extension PopupPlayerVC: MusicPlayable {

    func didStartPlaying(playlistItem: PlaylistItem) {
        tableView.reloadData()
    }
    
    func didPause() {
    }
    
    func didStopPlaying(playlistItem: PlaylistItem?) {
        if let stoppedPlaylistItem = playlistItem, let index = stoppedPlaylistItem.index, let cell = self.tableView.cellForRow(at: IndexPath(row: index, section: 0)) as? SongTableCell {
            cell.refresh()
        }
    }

    func didElapsedTimeChange() {
    }
    
    func didPlaylistChange() {
        tableView.reloadData()
    }

}

extension PopupPlayerVC: SongDownloadViewUpdatable {
    
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
