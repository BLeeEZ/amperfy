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
    @IBOutlet weak var largePlayerPlaceholderView: UIView!
    @IBOutlet weak var controlPlaceholderView: UIView!
    @IBOutlet weak var backgroundImage: UIImageView!
    
    @IBOutlet weak var controlPlaceholderHeightConstraint: NSLayoutConstraint!
    private let safetyMarginOnBottom = 20.0
    
    lazy var tableViewKeyCommandsController = TableViewKeyCommandsController(tableView: tableView, overrideFirstLastIndexPath: IndexPath(row: 0, section: PlayerSectionCategory.currentlyPlaying.rawValue))
    
    var player: PlayerFacade!
    var controlView: PlayerControlView?
    var largeCurrentlyPlayingView: LargeCurrentlyPlayingPlayerView?
    var hostingSplitVC: SplitVC?
    
    var currentlyPlayingTableCell: CurrentlyPlayingTableCell?
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
            
        player = appDelegate.player
        player.addNotifier(notifier: self)
        
        self.backgroundImage.setBackgroundBlur(style: .prominent)
        refreshCurrentlyPlayingPopupItem()
        
        controlPlaceholderHeightConstraint.constant = PlayerControlView.frameHeight + safetyMarginOnBottom
        if let createdPlayerControlView = ViewBuilder<PlayerControlView>.createFromNib(withinFixedFrame: CGRect(x: 0, y: 0, width: controlPlaceholderView.bounds.size.width, height: controlPlaceholderView.bounds.size.height)) {
            controlView = createdPlayerControlView
            createdPlayerControlView.prepare(toWorkOnRootView: self)
            controlPlaceholderView.addSubview(createdPlayerControlView)
        }
        if let createdLargeCurrentlyPlayingView = ViewBuilder<LargeCurrentlyPlayingPlayerView>.createFromNib(withinFixedFrame: CGRect(x: 0, y: 0, width: largePlayerPlaceholderView.bounds.size.width, height: largePlayerPlaceholderView.bounds.size.height)) {
            largeCurrentlyPlayingView = createdLargeCurrentlyPlayingView
            createdLargeCurrentlyPlayingView.prepare(toWorkOnRootView: self)
            largePlayerPlaceholderView.addSubview(createdLargeCurrentlyPlayingView)
        }
        
        self.setupTableView()
        self.fetchSongInfoAndUpdateViews()
        
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
        adjustLaoutMargins()
        refreshCellMasks()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        appDelegate.userStatistics.visited(.popupPlayer)
        self.becomeFirstResponder()
        adjustLaoutMargins()
        changeDisplayStyle(to: appDelegate.storage.settings.playerDisplayStyle, animated: false)
        reloadData()
        scrollToCurrentlyPlayingRow()
        self.controlView?.refreshView()
        refresh()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        self.resignFirstResponder()
    }
    
    func fetchSongInfoAndUpdateViews() {
        guard self.appDelegate.storage.settings.isOnlineMode,
              let song = player.currentlyPlaying?.asSong
        else { return }

        firstly {
            self.appDelegate.librarySyncer.sync(song: song)
        }.done {
            self.refreshCurrentlyPlayingInfoView()
        }.catch { error in
            self.appDelegate.eventLogger.report(topic: "Song Info", error: error)
        }
    }
    
    func reloadData() {
        tableView.reloadData()
        scrollToCurrentlyPlayingRow()
    }
    
    func scrollToCurrentlyPlayingRow() {
        return tableView.scrollToRow(at: IndexPath(row: 0, section: PlayerSectionCategory.currentlyPlaying.rawValue), at: .top, animated: false);
    }

    func favoritePressed() {
        switch player.playerMode {
        case .music:
            guard let playableInfo = player.currentlyPlaying else { return }
            firstly {
                playableInfo.remoteToggleFavorite(syncer: self.appDelegate.librarySyncer)
            }.catch { error in
                self.appDelegate.eventLogger.report(topic: "Toggle Favorite", error: error)
            }.finally {
                self.refresh()
            }
        case .podcast:
            guard let podcastEpisode = player.currentlyPlaying?.asPodcastEpisode
            else { return }
            let descriptionVC = PodcastDescriptionVC()
            descriptionVC.display(podcastEpisode: podcastEpisode, on: self)
            present(descriptionVC, animated: true)
        }
    }
    
    func displayArtistDetail() {
        if let song = player.currentlyPlaying?.asSong, let artist = song.artist {
            let artistDetailVC = ArtistDetailVC.instantiateFromAppStoryboard()
            artistDetailVC.artist = artist
            closePopupPlayerAndDisplayInLibraryTab(vc: artistDetailVC)
        }
    }
    
    func displayAlbumDetail() {
        if let song = player.currentlyPlaying?.asSong, let album = song.album {
            let albumDetailVC = AlbumDetailVC.instantiateFromAppStoryboard()
            albumDetailVC.album = album
            albumDetailVC.songToScrollTo = song
            closePopupPlayerAndDisplayInLibraryTab(vc: albumDetailVC)
        }
    }
    
    func displayPodcastDetail() {
        if let podcastEpisode = player.currentlyPlaying?.asPodcastEpisode, let podcast = podcastEpisode.podcast {
            let podcastDetailVC = PodcastDetailVC.instantiateFromAppStoryboard()
            podcastDetailVC.podcast = podcast
            podcastDetailVC.episodeToScrollTo = podcastEpisode
            closePopupPlayerAndDisplayInLibraryTab(vc: podcastDetailVC)
        }
    }
    
    func closePopupPlayer() {
        guard let hostingSplitVC = hostingSplitVC else { return }
        hostingSplitVC.visualizePopupPlayer(direction: .close, animated: true)
    }
    
    func closePopupPlayerAndDisplayInLibraryTab(vc: UIViewController) {
        guard let hostingSplitVC = hostingSplitVC else { return }
        hostingSplitVC.visualizePopupPlayer(direction: .close, animated: true, completion: { () in
            hostingSplitVC.push(vc: vc)
        })
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

}

extension PopupPlayerVC: MusicPlayable {
    func didStartPlaying() {
        self.reloadData()
        refresh()
    }
    
    func didStopPlaying() {
        self.reloadData()
        refresh()
    }

    func didPlaylistChange() {
        self.reloadData()
        refresh()
    }
    
    func didPause() {}
    func didElapsedTimeChange() {}
    func didArtworkChange() {
        self.refreshCurrentlyPlayingArtworks()
    }
    func didShuffleChange() {}
    func didRepeatChange() {}
    func didPlaybackRateChange() {}
}
