import UIKit

class PopupPlaylistGrouper {
    
    let sectionNames = ["Previous", "Next"]
    var sections: [[Song]]
    private var playIndex: Int
    
    init(player: MusicPlayer) {
        playIndex = player.currentlyPlaying?.index ?? 0
        
        let playlist = player.playlist
        var played = [Song]()
        if playIndex > 0 {
            played = Array(playlist.songs[0...playIndex-1])
        }
        var next = [Song]()
        if playlist.songs.count > 0, playIndex < playlist.songs.count-1 {
            next = Array(playlist.songs[(playIndex+1)...])
        }
        sections = [played, next]
    }
    
    func convertIndexPathToPlaylistIndex(indexPath: IndexPath) -> Int {
        var playlistIndex = indexPath.row
        if indexPath.section == 1 {
            playlistIndex += (1 + sections[0].count)
        }
        return playlistIndex
    }
    
    func convertPlaylistIndexToIndexPath(playlistIndex: Int) -> IndexPath? {
        if playlistIndex == playIndex {
            return nil
        }
        if playlistIndex < playIndex {
            return IndexPath(row: playlistIndex, section: 0)
        } else {
            return IndexPath(row: playlistIndex-playIndex-1, section: 1)
        }
    }
    
}

class PopupPlayerVC: UIViewController, UITableViewDelegate, UITableViewDataSource, UITableViewDragDelegate, UITableViewDropDelegate {

    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var playerPlaceholderView: UIView!
    
    var appDelegate: AppDelegate!
    var player: MusicPlayer!
    var playerView: PlayerView!
    var groupedPlaylist: PopupPlaylistGrouper!
    var hostingTabBarVC: TabBarVC?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.tableView.delegate = self
        self.tableView.dataSource = self
        self.tableView.dragDelegate = self
        self.tableView.dropDelegate = self
        self.tableView.dragInteractionEnabled = true
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
        groupedPlaylist = PopupPlaylistGrouper(player: player)
        tableView.register(nibName: SongTableCell.typeName)
        tableView.rowHeight = SongTableCell.rowHeight
    }
    
    override func viewWillAppear(_ animated: Bool) {
        reloadData()
        self.playerView.viewWillAppear(animated)
    }
    
    func reloadData() {
        groupedPlaylist = PopupPlaylistGrouper(player: player)
        tableView.reloadData()
    }

    // MARK: - Table view data source
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 2
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return groupedPlaylist.sectionNames[section]
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return CommonScreenOperations.tableSectionHeightLarge
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return groupedPlaylist.sections[section].count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell: SongTableCell = self.tableView.dequeueCell(for: tableView, at: indexPath)
        let song = groupedPlaylist.sections[indexPath.section][indexPath.row]
        cell.display(song: song, rootView: self, displayMode: .playerCell)
        let playlistIndex = groupedPlaylist.convertIndexPathToPlaylistIndex(indexPath: indexPath)
        cell.confToPlayPlaylistIndexOnTab(indexInPlaylist: playlistIndex)
        return cell
    }
    
    // Override to support editing the table view.
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            let deletedPlaylistIndex = groupedPlaylist.convertIndexPathToPlaylistIndex(indexPath: indexPath)
            for i in deletedPlaylistIndex+1...player.playlist.songs.count {
                if let targetIndexPath = groupedPlaylist.convertPlaylistIndexToIndexPath(playlistIndex: i),
                   let cell =  tableView.cellForRow(at: targetIndexPath) as? SongTableCell,
                   var newIndex = cell.indexInPlaylist {
                    newIndex -= 1
                    cell.confToPlayPlaylistIndexOnTab(indexInPlaylist: newIndex)
                }
            }
            player.removeFromPlaylist(at: groupedPlaylist.convertIndexPathToPlaylistIndex(indexPath: indexPath))
            groupedPlaylist = PopupPlaylistGrouper(player: player)
            tableView.deleteRows(at: [indexPath], with: .fade)
        }
    }

    // Override to support rearranging the table view.
    func tableView(_ tableView: UITableView, moveRowAt fromIndexPath: IndexPath, to: IndexPath) {
        let fromPlaylistIndex = groupedPlaylist.convertIndexPathToPlaylistIndex(indexPath: fromIndexPath)
        var toPlaylistIndex = groupedPlaylist.convertIndexPathToPlaylistIndex(indexPath: to)
        
        guard fromIndexPath != to else {
            return
        }
        if to.section == 1, fromIndexPath.section != to.section {
            toPlaylistIndex -= 1
        }
        if fromPlaylistIndex < toPlaylistIndex {
            for i in fromPlaylistIndex+1...toPlaylistIndex {
                if let targetIndexPath = groupedPlaylist.convertPlaylistIndexToIndexPath(playlistIndex: i),
                   let cell =  tableView.cellForRow(at: targetIndexPath) as? SongTableCell,
                   var newIndex = cell.indexInPlaylist {
                    newIndex -= 1
                    cell.confToPlayPlaylistIndexOnTab(indexInPlaylist: newIndex)
                }
            }
        } else {
            for i in toPlaylistIndex...fromPlaylistIndex-1 {
                if let targetIndexPath = groupedPlaylist.convertPlaylistIndexToIndexPath(playlistIndex: i),
                   let cell =  tableView.cellForRow(at: targetIndexPath) as? SongTableCell,
                   var newIndex = cell.indexInPlaylist {
                        newIndex += 1
                        cell.confToPlayPlaylistIndexOnTab(indexInPlaylist: newIndex)
                }
            }
        }
        if let cell =  tableView.cellForRow(at: fromIndexPath) as? SongTableCell {
            let newIndex = toPlaylistIndex
            cell.confToPlayPlaylistIndexOnTab(indexInPlaylist: newIndex)
        }

        player.movePlaylistSong(fromIndex: fromPlaylistIndex, to: toPlaylistIndex)
        groupedPlaylist = PopupPlaylistGrouper(player: player)
    }

    // Override to support conditional rearranging of the table view.
    func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {
        // Return false if you do not want the item to be re-orderable.
        return true
    }
    
    // MARK: - UITableViewDragDelegate
    func tableView(_ tableView: UITableView, itemsForBeginning session: UIDragSession, at indexPath: IndexPath) -> [UIDragItem] {
        // Create empty DragItem -> we are using tableView(_:moveRowAt:to:) method
        let itemProvider = NSItemProvider(object: String("") as NSItemProviderWriting)
        let dragItem = UIDragItem(itemProvider: itemProvider)
        return [dragItem]
    }

    // MARK: - UITableViewDropDelegate
    func tableView(_ tableView: UITableView, canHandle session: UIDropSession) -> Bool {
        return session.canLoadObjects(ofClass: NSString.self)
    }

    func tableView(_ tableView: UITableView, performDropWith coordinator: UITableViewDropCoordinator) {
        // Local drags with one item go through the existing tableView(_:moveRowAt:to:) method on the data source
        return
    }
    
    func optionsPressed() {
        let alert = UIAlertController(title: "Next songs", message: nil, preferredStyle: .actionSheet)
        
        alert.addAction(UIAlertAction(title: "Clear", style: .default, handler: { _ in
            self.appDelegate.player.cleanPlaylist()
            self.reloadData()
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
        self.reloadData()
    }
    
    func didPause() {
    }
    
    func didStopPlaying(playlistItem: PlaylistItem?) {
    }

    func didElapsedTimeChange() {
    }
    
    func didPlaylistChange() {
        self.reloadData()
    }

}

extension PopupPlayerVC: SongDownloadViewUpdatable {
    
    func downloadManager(_ downloadManager: DownloadManager, updatedRequest: DownloadRequest<Song>, updateReason: SongDownloadRequestEvent) {
        switch(updateReason) {
        case .finished:
            let indicesOfDownloadedSong = player.playlist.songs.allIndices(of: updatedRequest.element)
            for index in indicesOfDownloadedSong {
                if let indexPath = groupedPlaylist.convertPlaylistIndexToIndexPath(playlistIndex: index), let cell = self.tableView.cellForRow(at: indexPath) as? SongTableCell {
                    cell.refresh()
                }
            }
        default:
            break
        }
    }
    
}
