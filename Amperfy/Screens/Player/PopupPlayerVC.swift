//
//  PopupPlayerVC.swift
//  Amperfy
//
//  Created by Maximilian Bauer on 09.03.19.
//  Copyright (c) 2019 Maximilian Bauer. All rights reserved.
//
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program.  If not, see <http://www.gnu.org/licenses/>.
//

import UIKit
import AmperfyKit
import PromiseKit

class PopupPlayerVC: UIViewController, UIScrollViewDelegate {

    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var controlPlaceholderView: UIView!
    @IBOutlet weak var backgroundImage: UIImageView!
    
    @IBOutlet weak var controlPlaceholderHeightConstraint: NSLayoutConstraint!
    private let safetyMarginOnBottom = 20.0
    
    var appDelegate: AppDelegate!
    var player: PlayerFacade!
    var controlView: PlayerControlView?
    var hostingTabBarVC: TabBarVC?
    var nextViewSizeDueToDeviceRotation: CGSize?
    var isBackgroundBlurConfigured = false
    
    var contextPrevQueueSectionHeader: ContextQueuePrevSectionHeader?
    var userQueueSectionHeader: UserQueueSectionHeader?
    var contextNextQueueSectionHeader: ContextQueueNextSectionHeader?
    var activeDisplayedSectionHeader = Set<PlayerSectionCategory>()
    lazy var clearEmptySectionFooter = {
        let view = UIView()
        view.backgroundColor = .clear
        view.isHidden = true
        return view
    }()
    
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
        
        controlPlaceholderHeightConstraint.constant = PlayerControlView.frameHeight + safetyMarginOnBottom
        if let createdPlayerControlView = ViewBuilder<PlayerControlView>.createFromNib(withinFixedFrame: CGRect(x: 0, y: 0, width: controlPlaceholderView.bounds.size.width, height: controlPlaceholderView.bounds.size.height)) {
            controlView = createdPlayerControlView
            createdPlayerControlView.prepare(toWorkOnRootView: self)
            controlPlaceholderView.addSubview(createdPlayerControlView)
        }
        
        self.setupTableView()
        
        if let sectionView = ViewBuilder<ContextQueuePrevSectionHeader>.createFromNib(withinFixedFrame: CGRect(x: 0, y: 0, width: view.bounds.size.width, height: ContextQueuePrevSectionHeader.frameHeight)) {
            contextPrevQueueSectionHeader = sectionView
            contextPrevQueueSectionHeader?.display(name: "Previous")
        }
        if let sectionView = ViewBuilder<UserQueueSectionHeader>.createFromNib(withinFixedFrame: CGRect(x: 0, y: 0, width: view.bounds.size.width, height: UserQueueSectionHeader.frameHeight)) {
            userQueueSectionHeader = sectionView
            userQueueSectionHeader?.display(name: "Next from Queue", buttonPressAction: clearUserQueue)
        }
        if let sectionView = ViewBuilder<ContextQueueNextSectionHeader>.createFromNib(withinFixedFrame: CGRect(x: 0, y: 0, width: view.bounds.size.width, height: ContextQueueNextSectionHeader.frameHeight)) {
            contextNextQueueSectionHeader = sectionView
            contextNextQueueSectionHeader?.prepare(toWorkOnRootView: self)
        }
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        if !isBackgroundBlurConfigured {
            isBackgroundBlurConfigured = true
            let blurEffect = UIBlurEffect(style: .systemThinMaterial)
            let blurEffectView = UIVisualEffectView(effect: blurEffect)
            // BlurEffect rect is a square to avoid rerendering during iPad device rotation
            blurEffectView.frame = CGRect(x: 0, y: 0, width: max(self.view.frame.width, self.view.frame.height), height: max(self.view.frame.width, self.view.frame.height))
            self.backgroundImage.insertSubview(blurEffectView, at: 0)
        }
        refreshCellMasks()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        appDelegate.userStatistics.visited(.popupPlayer)
        reloadData()
        self.controlView?.refreshView()
        scrollToCurrentlyPlayingRow()
    }
    
    // Detecet device (iPad) rotation
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        nextViewSizeDueToDeviceRotation = size
    }
    
    override func didRotate(from fromInterfaceOrientation: UIInterfaceOrientation) {
        nextViewSizeDueToDeviceRotation = nil
    }
    
    func subtitleColor(style: UIUserInterfaceStyle) -> UIColor {
        if let artwork = player.currentlyPlaying?.image(setting: appDelegate.storage.settings.artworkDisplayPreference), artwork != player.currentlyPlaying?.defaultImage {
            let customColor: UIColor!
            if traitCollection.userInterfaceStyle == .dark {
                customColor = artwork.averageColor().getWithLightness(of: 0.8)
            } else {
                customColor = artwork.averageColor().getWithLightness(of: 0.2)
            }
            return customColor
        } else {
            return .labelColor
        }
    }
    
    func scrollToCurrentlyPlayingRow() {
        return tableView.scrollToRow(at: IndexPath(row: 0, section: PlayerSectionCategory.currentlyPlaying.rawValue), at: .top, animated: false);
    }
    
    func reloadData() {
        tableView.reloadData()
        scrollToCurrentlyPlayingRow()
        refresh()
    }
    
    func refresh() {
        refreshUserQueueSectionHeader()
        refreshCellMasks()
    }
    
    func changeBackgroundGradient(forPlayable playable: AbstractPlayable) {
        let artwork = playable.image(setting: appDelegate.storage.settings.artworkDisplayPreference)
        backgroundImage.image = artwork
    }
    
    func getPlayerButtonConfiguration(isSelected: Bool) -> UIButton.Configuration {
        var config = UIButton.Configuration.tinted()
        if isSelected {
            config.background.strokeColor = .label
            config.background.strokeWidth = 1.0
            config.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(scale: .medium)
        }
        config.buttonSize = .small
        config.baseForegroundColor = !isSelected ? .label : .systemBackground
        config.baseBackgroundColor = !isSelected ? .clear : .label
        config.cornerStyle = .medium
        return config
    }
    
    // handle dark/light mode change
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        let subtitleColor = self.subtitleColor(style: traitCollection.userInterfaceStyle)
        tableView.visibleCells.forEach {
            ($0 as? PlayableTableCell)?.updateSubtitleColor(color: subtitleColor)
        }
    }
    
    var frameSizeWithRotationAdjusment: CGSize {
        return nextViewSizeDueToDeviceRotation ?? view.frame.size
    }
    
    func refreshUserQueueSectionHeader() {
        guard let userQueueSectionView = userQueueSectionHeader else { return }
        if player.userQueue.isEmpty {
            userQueueSectionView.hide()
        } else {
            userQueueSectionView.display(name: PlayerQueueType.user.description, buttonPressAction: self.clearUserQueue)
        }
    }

    // MARK: - UIScrollViewDelegate
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        refreshCellMasks()
    }
    
    func refreshCellMasks() {
        guard let topSection = Array(activeDisplayedSectionHeader).sorted(by: { $0.rawValue < $1.rawValue }).first
        else { return }

        let topSectionHeight = self.tableView(tableView, heightForHeaderInSection: topSection.rawValue)
        let scrollOffset = tableView.contentOffset.y
        
        for cell in tableView.visibleCells {
            let hiddenFrameHeight = scrollOffset + topSectionHeight - cell.frame.origin.y
            if (hiddenFrameHeight >= 0 || hiddenFrameHeight <= cell.frame.size.height) {
                if let customCell = cell as? PlayableTableCell {
                    customCell.maskCell(fromTop: hiddenFrameHeight)
                }
            }
        }
    }
    
    func displayCurrentlyPlayingDetailInfo() {
        appDelegate.userStatistics.usedAction(.playerOptions)
        guard let playable = self.player.currentlyPlaying else { return }
        let detailVC = LibraryEntityDetailVC()
        detailVC.display(container: playable, on: self, playContextCb: nil)
        self.present(detailVC, animated: true)
    }

}

extension PopupPlayerVC: MusicPlayable {
    func didStartPlaying() {
        self.reloadData()
    }
    
    func didStopPlaying() {
        self.reloadData()
    }

    func didPlaylistChange() {
        self.reloadData()
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
    
    func didPause() {}
    func didElapsedTimeChange() {}
    func didArtworkChange() {}
    func didShuffleChange() {}
    func didRepeatChange() {}
    func didPlaybackRateChange() {}
}
