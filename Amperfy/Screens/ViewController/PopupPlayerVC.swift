import UIKit

class PopupPlayerVC: UIViewController, UITableViewDelegate, UITableViewDataSource, UIScrollViewDelegate, UITableViewDragDelegate, UITableViewDropDelegate {

    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var playerPlaceholderView: UIView!
    
    private var playerViewToTableViewConstraint: NSLayoutConstraint?
    
    var appDelegate: AppDelegate!
    var player: MusicPlayer!
    var playerView: PlayerView!
    var groupedPlaylist: PopupPlaylistGrouper!
    var hostingTabBarVC: TabBarVC?
    var backgroundColorGradient: PopupAnimatedGradientLayer!
    let backgroundGradientDelayTime: UInt32 = 2

    override func viewDidLoad() {
        super.viewDidLoad()
        self.tableView.delegate = self
        self.tableView.dataSource = self
        self.tableView.dragDelegate = self
        self.tableView.dropDelegate = self
        self.tableView.dragInteractionEnabled = true
            
        appDelegate = (UIApplication.shared.delegate as! AppDelegate)
        player = appDelegate.player
        player.addNotifier(notifier: self)
        appDelegate.songDownloadManager.addNotifier(self)
        groupedPlaylist = PopupPlaylistGrouper(player: player)
        backgroundColorGradient = PopupAnimatedGradientLayer(view: view)
        backgroundColorGradient.changeBackground(withStyleAndRandomColor: self.traitCollection.userInterfaceStyle)
        
        if let createdPlayerView = ViewBuilder<PlayerView>.createFromNib(withinFixedFrame: CGRect(x: 0, y: 0, width: playerPlaceholderView.bounds.size.width, height: playerPlaceholderView.bounds.size.height)) {
            playerView = createdPlayerView
            playerView.prepare(toWorkOnRootView: self)
            playerPlaceholderView.addSubview(playerView)
        }

        tableView.register(nibName: SongTableCell.typeName)
        tableView.rowHeight = SongTableCell.rowHeight
        tableView.backgroundColor = UIColor.clear
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        appDelegate.userStatistics.visited(.popupPlayer)
        reloadData()
        adjustConstraintsForCompactPlayer()
        self.playerView.viewWillAppear(animated)
    }

    func reloadData() {
        groupedPlaylist = PopupPlaylistGrouper(player: player)
        tableView.reloadData()
    }
    
    func changeBackgroundGradient(forSong song: Song) {
        var customColor: UIColor?
        let songArtwork = song.image

        if playerView.lastDisplayedSong != song {
            DispatchQueue.global().async {
                if songArtwork != Artwork.defaultImage {
                    customColor = songArtwork.averageColor()
                }
                sleep(self.backgroundGradientDelayTime)
                DispatchQueue.main.async {
                    if self.playerView.lastDisplayedSong == song {
                        if let customColor = customColor {
                            self.backgroundColorGradient.changeBackground(style: self.traitCollection.userInterfaceStyle, customColor: customColor)
                        } else {
                            self.backgroundColorGradient.changeBackground(withStyleAndRandomColor: self.traitCollection.userInterfaceStyle)
                        }
                    }
                }
            }
        }
    }
    
    // handle dark/light mode change
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        backgroundColorGradient.applyStyleChange(traitCollection.userInterfaceStyle)
    }
    
    func scrollToNextPlayingRow() {
        if let nextPlayingIndex = groupedPlaylist.nextPlayingtIndexPath {
            tableView.scrollToRow(at: nextPlayingIndex, at: .top, animated: true)
        }
    }
    
    // MARK: - PopupPlayer frame height animation
    
    var availableFrameHeightForLargePlayer: CGFloat {
        let playerOriginPoint = self.playerView.convert(self.playerView.frame.origin, to: self.view)
        return self.view.frame.size.height - playerOriginPoint.y
    }
    
    func renderAnimationForCompactPlayer(ofHight: CGFloat, animationDuration: TimeInterval) {
        UIView.animate(withDuration: animationDuration, animations: ({
            self.playerPlaceholderView.frame.size.height = ofHight
            self.view.layoutIfNeeded()
        }), completion: ({ _ in
            self.adjustConstraintsForCompactPlayer()
            self.view.layoutIfNeeded()
        }))
    }
    
    func renderAnimationForLargePlayer(animationDuration: TimeInterval) {
        UIView.animate(withDuration: animationDuration, animations: ({
            self.playerPlaceholderView.frame.size.height = self.availableFrameHeightForLargePlayer
            self.adjustConstraintsForLargePlayer()
            self.view.layoutIfNeeded()
        }), completion: nil)
    }
    
    func adjustConstraintsForCompactPlayer() {
        playerViewToTableViewConstraint?.isActive = false
        playerViewToTableViewConstraint = NSLayoutConstraint(item: self.tableView!,
                               attribute: .bottom,
                               relatedBy: .equal,
                               toItem: self.view,
                               attribute: .bottom,
                               multiplier: 1.0,
                               constant: 0)
        playerViewToTableViewConstraint?.isActive = true
    }
    
    func adjustConstraintsForLargePlayer() {
        playerViewToTableViewConstraint?.isActive = false
        playerViewToTableViewConstraint = NSLayoutConstraint(item: self.tableView!,
                               attribute: .bottom,
                               relatedBy: .greaterThanOrEqual,
                               toItem: self.view,
                               attribute: .bottom,
                               multiplier: 1.0,
                               constant: 0)
        playerViewToTableViewConstraint?.isActive = true
    }

    // MARK: - Table view data source
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 2
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return groupedPlaylist.sectionNames[section]
    }

    func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
        guard let headerView = view as? UITableViewHeaderFooterView else { return }
        headerView.backgroundView = UIView()
        headerView.backgroundView?.backgroundColor = UIColor.clear
        headerView.textLabel?.font = UIFont.systemFont(ofSize: 20)
        headerView.textLabel?.textColor = UIColor.labelColor
        // text needs to be overridden here, otherwise the text is completely capital
        headerView.textLabel?.text = groupedPlaylist.sectionNames[section]
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
        cell.backgroundColor = UIColor.clear
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
    
    // MARK: - UIScrollViewDelegate
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        return
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
        appDelegate.userStatistics.usedAction(.playerOptions)
        let alert = UIAlertController(title: "Player", message: nil, preferredStyle: .actionSheet)
        
        alert.addAction(UIAlertAction(title: "Clear playlist", style: .default, handler: { _ in
            self.appDelegate.player.cleanPlaylist()
            self.reloadData()
            self.playerView.refreshPlayer()
        }))
        alert.addAction(UIAlertAction(title: "Add all songs to playlist", style: .default, handler: { _ in
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
        self.reloadData()
    }

    func didElapsedTimeChange() {
    }
    
    func didPlaylistChange() {
        self.reloadData()
    }

}

extension PopupPlayerVC: DownloadViewUpdatable {
    
    func downloadManager(_ downloadManager: DownloadManager, updatedRequest: DownloadRequest, updateReason: DownloadRequestEvent) {
        switch(updateReason) {
        case .finished:
            if let song = updatedRequest.element as? Song {
                let indicesOfDownloadedSong = player.playlist.songs.allIndices(of: song)
                for index in indicesOfDownloadedSong {
                    if let indexPath = groupedPlaylist.convertPlaylistIndexToIndexPath(playlistIndex: index), let cell = self.tableView.cellForRow(at: indexPath) as? SongTableCell {
                        cell.refresh()
                    }
                }
            }
        default:
            break
        }
    }
    
}
