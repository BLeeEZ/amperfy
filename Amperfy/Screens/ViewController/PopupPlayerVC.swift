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
        groupedPlaylist = PopupPlaylistGrouper(player: player)
        backgroundColorGradient = PopupAnimatedGradientLayer(view: view)
        backgroundColorGradient.changeBackground(withStyleAndRandomColor: self.traitCollection.userInterfaceStyle)
        
        if let createdPlayerView = ViewBuilder<PlayerView>.createFromNib(withinFixedFrame: CGRect(x: 0, y: 0, width: playerPlaceholderView.bounds.size.width, height: playerPlaceholderView.bounds.size.height)) {
            playerView = createdPlayerView
            playerView.prepare(toWorkOnRootView: self)
            playerPlaceholderView.addSubview(playerView)
        }
        
        tableView.register(nibName: PlayableTableCell.typeName)
        tableView.rowHeight = PlayableTableCell.rowHeight
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

    func convertCellViewToPlayerIndex(cell: PlayableTableCell) -> PlayerIndex? {
        guard let indexPath = tableView.indexPath(for: cell) else { return nil }
        return groupedPlaylist.convertIndexPathToPlayerIndex(indexPath: indexPath)
    }
    
    func changeBackgroundGradient(forPlayable playable: AbstractPlayable) {
        var customColor: UIColor?
        let artwork = playable.image

        if playerView.lastDisplayedPlayable != playable {
            DispatchQueue.global().async {
                if artwork != Artwork.defaultImage {
                    customColor = artwork.averageColor()
                }
                sleep(self.backgroundGradientDelayTime)
                DispatchQueue.main.async {
                    if self.playerView.lastDisplayedPlayable == playable {
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
        return 3
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return groupedPlaylist.sectionNames[section]
    }

    func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
        refreshSectionHeaderView(view: view, forSection: section)
    }
    
    func refreshSectionHeaderView(view: UIView, forSection section: Int) {
        guard let headerView = view as? UITableViewHeaderFooterView else { return }
        headerView.backgroundView = UIView()
        headerView.backgroundView?.backgroundColor = UIColor.clear
        headerView.textLabel?.font = UIFont.systemFont(ofSize: 20)
        headerView.textLabel?.textColor = UIColor.labelColor
        // text needs to be overridden here, otherwise the text is completely capital
        if section == 1, !groupedPlaylist.isWaitingQueueVisible {
            headerView.textLabel?.text = ""
        } else {
            headerView.textLabel?.text = groupedPlaylist.sectionNames[section]
        }
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        if section == 1, !groupedPlaylist.isWaitingQueueVisible {
            return CGFloat.leastNormalMagnitude
        }
        return CommonScreenOperations.tableSectionHeightLarge
    }
    
     func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
         if section == 1, !groupedPlaylist.isWaitingQueueVisible {
             return CGFloat.leastNormalMagnitude
         }
         return CommonScreenOperations.tableSectionHeightFooter
    }

    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return groupedPlaylist.sections[section].count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell: PlayableTableCell = self.tableView.dequeueCell(for: tableView, at: indexPath)
        let playable = groupedPlaylist.sections[indexPath.section][indexPath.row]
        cell.playerIndexConversionCallback = self.convertCellViewToPlayerIndex
        cell.backgroundColor = UIColor.clear
        cell.display(playable: playable, rootView: self)
        return cell
    }
    
    func tableView(_ tableView: UITableView, leadingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        return UISwipeActionsConfiguration(actions: [
            createWaitingQueueSwipeAction(indexPath: indexPath) { (indexPath) in
                let playable = self.groupedPlaylist.sections[indexPath.section][indexPath.row]
                tableView.beginUpdates()
                self.player.addToWaitingQueue(playable: playable)
                tableView.insertRows(at: [IndexPath(row: self.groupedPlaylist.sections[1].count, section: 1)], with: .top)
                self.groupedPlaylist = PopupPlaylistGrouper(player: self.player)
                tableView.endUpdates()
                self.refreshWaitingQueueSectionHeader()
            }
        ])
    }

    // Override to support editing the table view.
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            let deletedPlaylistIndex = groupedPlaylist.convertIndexPathToPlayerIndex(indexPath: indexPath)
            if deletedPlaylistIndex.queueType == .waitingQueue {
                player.removeFromWaitingQueue(at: deletedPlaylistIndex.index)
            } else {
                player.removeFromPlaylist(at: deletedPlaylistIndex.index)
            }
            groupedPlaylist = PopupPlaylistGrouper(player: player)
            tableView.deleteRows(at: [indexPath], with: .fade)
            if indexPath.section == 1 {
                refreshWaitingQueueSectionHeader()
            }
        }
    }
    
    // Override to support rearranging the table view.
    func tableView(_ tableView: UITableView, moveRowAt fromIndexPath: IndexPath, to: IndexPath) {
        guard fromIndexPath != to else { return }
        let fromPlaylistIndex = groupedPlaylist.convertIndexPathToPlayerIndex(indexPath: fromIndexPath)
        var toPlaylistIndex = groupedPlaylist.convertIndexPathToPlayerIndex(indexPath: to)
        if fromIndexPath.section == 0, to.section == 2 {
            toPlaylistIndex = PlayerIndex(queueType: toPlaylistIndex.queueType, index: toPlaylistIndex.index-1)
        }
        
        // source and target are not in the user queue -> no playlist index change, first next item is counted as has been played
        if fromPlaylistIndex.queueType == .playlist, toPlaylistIndex.queueType == .playlist, groupedPlaylist.isWaitingQueuePlaying, fromPlaylistIndex == toPlaylistIndex {
            if fromPlaylistIndex.index == groupedPlaylist.playIndex {
                player.decrementCurrentIndex()
            } else {
                player.incrementCurrentIndex()
            }
        // source/target are not in the user queue
        } else if fromPlaylistIndex.queueType == .playlist, toPlaylistIndex.queueType == .playlist {
            player.movePlaylistItem(fromIndex: fromPlaylistIndex.index, to: toPlaylistIndex.index)
            // moving item from next directly after current index in the prev section
            if groupedPlaylist.isWaitingQueuePlaying, toPlaylistIndex.index == groupedPlaylist.playIndex+1,
               to.section == 0, fromIndexPath.section != 0 {
                player.incrementCurrentIndex()
            // moving current index from the prev section to next section
            } else if groupedPlaylist.isWaitingQueuePlaying, fromPlaylistIndex.index == groupedPlaylist.playIndex,
               to.section > 0  {
                player.decrementCurrentIndex()
            // moving any prev item to top of next section
            } else if groupedPlaylist.isWaitingQueuePlaying, toPlaylistIndex.index == groupedPlaylist.playIndex,
               to.section > 0  {
                player.decrementCurrentIndex()
            }
        // from user queue to user queue
        } else if fromPlaylistIndex.queueType == .waitingQueue, toPlaylistIndex.queueType == .waitingQueue {
            player.moveWaitingQueueItem(fromIndex: fromPlaylistIndex.index, to: toPlaylistIndex.index)
        // from user queue to context queue
        } else if fromPlaylistIndex.queueType == .waitingQueue {
            player.addToPlaylist(playable: player.waitingQueue.playables[fromPlaylistIndex.index])
            player.movePlaylistItem(fromIndex: player.playlist.songCount-1, to: toPlaylistIndex.index)
            player.removeFromWaitingQueue(at: fromPlaylistIndex.index)
            if groupedPlaylist.isWaitingQueuePlaying, toPlaylistIndex.index == groupedPlaylist.playIndex + 1, to.section == 0 {
                player.incrementCurrentIndex()
            }
        // from context queue to user queue
        } else if toPlaylistIndex.queueType == .waitingQueue {
            player.addToWaitingQueue(playable: player.playlist.playables[fromPlaylistIndex.index])
            player.moveWaitingQueueItem(fromIndex: player.waitingQueue.songCount-1, to: toPlaylistIndex.index)
            player.removeFromPlaylist(at: fromPlaylistIndex.index)
        }
        
        groupedPlaylist = PopupPlaylistGrouper(player: player)
        
        if fromIndexPath.section == 1 || to.section == 1 {
            refreshWaitingQueueSectionHeader()
        }
    }
    
    func refreshWaitingQueueSectionHeader() {
        if let sectionView = tableView.headerView(forSection: 1) {
            refreshSectionHeaderView(view: sectionView, forSection: 1)
        }
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
        
        alert.addAction(UIAlertAction(title: "Clear Player", style: .default, handler: { _ in
            self.appDelegate.player.clearQueues()
            self.reloadData()
            self.playerView.refreshPlayer()
        }))
        alert.addAction(UIAlertAction(title: "Clear Waiting Queue", style: .default, handler: { _ in
            self.appDelegate.player.clearWaitingQueue()
            self.reloadData()
            self.playerView.refreshPlayer()
        }))
        if appDelegate.persistentStorage.settings.isOnlineMode {
            alert.addAction(UIAlertAction(title: "Add all songs to playlist", style: .default, handler: { _ in
                let selectPlaylistVC = PlaylistSelectorVC.instantiateFromAppStoryboard()
                selectPlaylistVC.itemsToAdd = self.appDelegate.player.playlist.playables.filterSongs()
                let selectPlaylistNav = UINavigationController(rootViewController: selectPlaylistVC)
                self.present(selectPlaylistNav, animated: true, completion: nil)
            }))
        }
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
    
    func didArtworkChange() {
    }
    
    func closePopupPlayerAndDisplayInLibraryTab(vc: UIViewController) {
        guard let hostingTabBarVC = hostingTabBarVC else { return }
        hostingTabBarVC.closePopup(animated: true, completion: { () in
            if let hostingTabViewControllers = hostingTabBarVC.viewControllers,
               hostingTabViewControllers.count > 0,
               let libraryTabNavVC = hostingTabViewControllers[0] as? UINavigationController {
                libraryTabNavVC.pushViewController(vc, animated: false)
                hostingTabBarVC.selectedIndex = 0
            }
        })
    }

}
