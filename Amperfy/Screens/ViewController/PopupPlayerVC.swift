import UIKit

class PopupPlayerVC: UIViewController, UITableViewDelegate, UITableViewDataSource, UIScrollViewDelegate, UITableViewDragDelegate, UITableViewDropDelegate {

    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var playerPlaceholderView: UIView!
    
    private var playerViewToTableViewConstraint: NSLayoutConstraint?
    
    var appDelegate: AppDelegate!
    var player: PlayerFacade!
    var playerView: PlayerView?
    var hostingTabBarVC: TabBarVC?
    var backgroundColorGradient: PopupAnimatedGradientLayer?
    let backgroundGradientDelayTime: UInt32 = 2
    var sectionViews = [PopupPlayerSectionHeader]()
    var nextViewSizeDueToDeviceRotation: CGSize?

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
        backgroundColorGradient = PopupAnimatedGradientLayer(view: view)
        backgroundColorGradient?.changeBackground(withStyleAndRandomColor: self.traitCollection.userInterfaceStyle)
        
        if let createdPlayerView = ViewBuilder<PlayerView>.createFromNib(withinFixedFrame: CGRect(x: 0, y: 0, width: playerPlaceholderView.bounds.size.width, height: playerPlaceholderView.bounds.size.height)) {
            playerView = createdPlayerView
            createdPlayerView.prepare(toWorkOnRootView: self)
            playerPlaceholderView.addSubview(createdPlayerView)
        }
        
        tableView.register(nibName: PlayableTableCell.typeName)
        tableView.rowHeight = PlayableTableCell.rowHeight
        tableView.backgroundColor = UIColor.clear
        
        for queueType in PlayerQueueType.allCases {
            if let sectionView = ViewBuilder<PopupPlayerSectionHeader>.createFromNib(withinFixedFrame: CGRect(x: 0, y: 0, width: view.bounds.size.width, height: LibraryElementDetailTableHeaderView.frameHeight)) {
                sectionView.display(type: queueType)
                sectionViews.append(sectionView)
            }
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        appDelegate.userStatistics.visited(.popupPlayer)
        reloadData()
        adjustConstraintsForCompactPlayer()
        self.playerView?.viewWillAppear(animated)
    }
    
    // Detecet device (iPad) rotation
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        nextViewSizeDueToDeviceRotation = size
        backgroundColorGradient?.gradientLayer.adjustTo(size: size)
        playerView?.renderAnimation(animationDuration: TimeInterval(0.0))
    }
    
    override func didRotate(from fromInterfaceOrientation: UIInterfaceOrientation) {
        nextViewSizeDueToDeviceRotation = nil
    }

    func reloadData() {
        tableView.reloadData()
    }

    func convertCellViewToPlayerIndex(cell: PlayableTableCell) -> PlayerIndex? {
        guard let indexPath = tableView.indexPath(for: cell),
              let playerIndex = PlayerIndex.create(from: indexPath) else { return nil }
        return playerIndex
    }
    
    func changeBackgroundGradient(forPlayable playable: AbstractPlayable) {
        var customColor: UIColor?
        let artwork = playable.image

        guard let playerView = playerView else { return }
        if playerView.lastDisplayedPlayable != playable {
            DispatchQueue.global().async {
                if artwork != Artwork.defaultImage {
                    customColor = artwork.averageColor()
                }
                sleep(self.backgroundGradientDelayTime)
                DispatchQueue.main.async {
                    if playerView.lastDisplayedPlayable == playable {
                        if let customColor = customColor {
                            self.backgroundColorGradient?.changeBackground(style: self.traitCollection.userInterfaceStyle, customColor: customColor)
                        } else {
                            self.backgroundColorGradient?.changeBackground(withStyleAndRandomColor: self.traitCollection.userInterfaceStyle)
                        }
                    }
                }
            }
        }
    }
    
    // handle dark/light mode change
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        backgroundColorGradient?.applyStyleChange(traitCollection.userInterfaceStyle)
    }
    
    func scrollToNextPlayingRow() {
        if player.waitingQueue.count > 0 {
            tableView.scrollToRow(at: IndexPath(row: 0, section: 1), at: .top, animated: true)
        } else if player.nextQueue.count > 0 {
            tableView.scrollToRow(at: IndexPath(row: 0, section: 2), at: .top, animated: true)
        } else if player.prevQueue.count > 0 {
            tableView.scrollToRow(at: IndexPath(row: player.prevQueue.count-1, section: 0), at: .top, animated: true)
        }
    }
    
    // MARK: - PopupPlayer frame height animation
    
    var frameSizeWithRotationAdjusment: CGSize {
        return nextViewSizeDueToDeviceRotation ?? view.frame.size
    }

    var availableFrameHeightForLargePlayer: CGFloat {
        guard let playerView = playerView else { return 0.0 }
        let playerOriginPoint = playerView.convert(playerView.frame.origin, to: self.view)
        return frameSizeWithRotationAdjusment.height - playerOriginPoint.y
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
        return nil
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        refreshWaitingQueueSectionHeader()
        return sectionViews[section]
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        if section == 1, player.waitingQueue.isEmpty {
            return CGFloat.leastNormalMagnitude
        }
        return PopupPlayerSectionHeader.frameHeight
    }
    
     func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
         if section == 1, player.waitingQueue.isEmpty {
             return CGFloat.leastNormalMagnitude
         }
         return CommonScreenOperations.tableSectionHeightFooter
    }

    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch(section) {
        case 0: return player.prevQueue.count
        case 1: return player.waitingQueue.count
        case 2: return player.nextQueue.count
        default: return 0
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell: PlayableTableCell = self.tableView.dequeueCell(for: tableView, at: indexPath)
        guard let playerIndex = PlayerIndex.create(from: indexPath) else { return cell }
        let playable = player.getPlayable(at: playerIndex)
        cell.backgroundColor = UIColor.clear
        cell.display(
            playable: playable,
            playContextCb: {(_) in PlayContext(playables: [])},
            rootView: self,
            playerIndexCb: convertCellViewToPlayerIndex)
        return cell
    }

    // Override to support editing the table view.
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            guard let playerIndex = PlayerIndex.create(from: indexPath) else { return }
            player.removePlayable(at: playerIndex)
            tableView.deleteRows(at: [indexPath], with: .fade)
            if indexPath.section == 1 {
                refreshWaitingQueueSectionHeader()
            }
        }
    }
    
    // Override to support rearranging the table view.
    func tableView(_ tableView: UITableView, moveRowAt fromIndexPath: IndexPath, to: IndexPath) {
        guard fromIndexPath != to,
            let fromPlayerIndex = PlayerIndex.create(from: fromIndexPath),
            let toPlayerIndex = PlayerIndex.create(from: to)
        else { return }
        player.movePlayable(from: fromPlayerIndex, to: toPlayerIndex)
        if fromIndexPath.section == 1 || to.section == 1 {
            refreshWaitingQueueSectionHeader()
        }
    }
    
    func refreshWaitingQueueSectionHeader() {
        let waitingQueueSectionView = sectionViews[1]
        waitingQueueSectionView.hide()
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
            self.playerView?.refreshPlayer()
        }))
        if appDelegate.persistentStorage.settings.isOnlineMode {
            alert.addAction(UIAlertAction(title: "Add all songs to playlist", style: .default, handler: { _ in
                let selectPlaylistVC = PlaylistSelectorVC.instantiateFromAppStoryboard()
                var itemsToAdd = self.appDelegate.player.prevQueue.filterSongs()
                if let currentlyPlaying = self.appDelegate.player.currentlyPlaying, currentlyPlaying.isSong {
                    itemsToAdd.append(currentlyPlaying)
                }
                itemsToAdd.append(contentsOf: self.appDelegate.player.nextQueue.filterSongs())
                selectPlaylistVC.itemsToAdd = itemsToAdd
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

    func didStartPlaying() {
        self.reloadData()
    }
    
    func didPause() {
    }
    
    func didStopPlaying() {
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
