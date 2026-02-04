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

import AmperfyKit
import CoreMedia
import UIKit

// MARK: - PopupPlayerVC

class PopupPlayerVC: UIViewController, UIScrollViewDelegate {
  @IBOutlet
  weak var tableView: UITableView!
  @IBOutlet
  weak var largePlayerPlaceholderView: UIView!
  @IBOutlet
  weak var controlPlaceholderView: UIView!
  @IBOutlet
  weak var backgroundImage: UIImageView!
  @IBOutlet
  weak var closeButtonPlaceholderView: UIView!

  @IBOutlet
  weak var controlPlaceholderHeightConstraint: NSLayoutConstraint!
  private let safetyMarginOnBottom = 20.0
  internal var artworkGradientColors = [UIColor]()
  
  // Track song ID to ensure gradient is only calculated once per song
  var lastGradientSongID: String?

  lazy var tableViewKeyCommandsController = TableViewKeyCommandsController(
    tableView: tableView,
    overrideFirstLastIndexPath: IndexPath(
      row: 0,
      section: PlayerSectionCategory.currentlyPlaying.rawValue
    )
  )

  var player: PlayerFacade!
  var playerHandler: PlayerUIHandler?
  var controlView: PlayerControlView?
  var largeCurrentlyPlayingView: LargeCurrentlyPlayingPlayerView?
  var accountNotificationHandler: AccountNotificationHandler?
  
  /// Tracks whether the player has been "primed" this session to work around
  /// a bug where the first play after app restart doesn't produce audio
  private static var hasPlayerBeenPrimedThisSession = false

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

    tableView.delegate = self
    tableView.dataSource = self
    tableView.dragDelegate = self
    tableView.dropDelegate = self
    tableView.dragInteractionEnabled = true

    player = appDelegate.player
    player.addNotifier(notifier: self)
    playerHandler = PlayerUIHandler(player: player, style: .popupPlayer)

    // Use lower blur alpha on iPad to ensure gradient colors are visible
    if UIDevice.current.userInterfaceIdiom == .pad {
      backgroundImage.setBackgroundBlur(style: .prominent, alpha: 0.9)
    } else {
      backgroundImage.setBackgroundBlur(style: .prominent)
    }

    controlPlaceholderHeightConstraint.constant = PlayerControlView
      .frameHeight + safetyMarginOnBottom
    if let createdPlayerControlView = ViewCreator<PlayerControlView>
      .createFromNib(withinFixedFrame: CGRect(
        x: 0,
        y: 0,
        width: controlPlaceholderView.bounds.size.width,
        height: controlPlaceholderView.bounds.size.height
      )) {
      controlView = createdPlayerControlView
      createdPlayerControlView.prepare(toWorkOnRootView: self)
      controlPlaceholderView.addSubview(createdPlayerControlView)
    }
    if let createdLargeCurrentlyPlayingView = ViewCreator<LargeCurrentlyPlayingPlayerView>
      .createFromNib(withinFixedFrame: CGRect(
        x: 0,
        y: 0,
        width: largePlayerPlaceholderView.bounds.size.width,
        height: largePlayerPlaceholderView.bounds.size.height
      )) {
      largeCurrentlyPlayingView = createdLargeCurrentlyPlayingView
      createdLargeCurrentlyPlayingView.prepare(toWorkOnRootView: self)
      largePlayerPlaceholderView.addSubview(createdLargeCurrentlyPlayingView)
    }

    setupTableView()
    fetchSongInfoAndUpdateViews()

    if let sectionView = ViewCreator<ContextQueuePrevSectionHeader>
      .createFromNib(withinFixedFrame: CGRect(
        x: 0,
        y: 0,
        width: view.bounds.size.width,
        height: ContextQueuePrevSectionHeader.frameHeight
      )) {
      contextPrevQueueSectionHeader = sectionView
      contextPrevQueueSectionHeader?.display(name: "Previous")
    }
    if let sectionView = ViewCreator<UserQueueSectionHeader>.createFromNib(withinFixedFrame: CGRect(
      x: 0,
      y: 0,
      width: view.bounds.size.width,
      height: UserQueueSectionHeader.frameHeight
    )) {
      userQueueSectionHeader = sectionView
      userQueueSectionHeader?.display(name: "Next from Queue", buttonPressAction: clearUserQueue)
    }
    if let sectionView = ViewCreator<ContextQueueNextSectionHeader>
      .createFromNib(withinFixedFrame: CGRect(
        x: 0,
        y: 0,
        width: view.bounds.size.width,
        height: ContextQueueNextSectionHeader.frameHeight
      )) {
      contextNextQueueSectionHeader = sectionView
      contextNextQueueSectionHeader?.prepare(toWorkOnRootView: self)
    }

    accountNotificationHandler = AccountNotificationHandler(
      storage: appDelegate.storage,
      notificationHandler: appDelegate.notificationHandler
    )
    accountNotificationHandler?.registerCallbackForAllAccounts { [weak self] accountInfo in
      guard let self else { return }
      appDelegate.notificationHandler.register(
        self,
        selector: #selector(downloadFinishedSuccessful(notification:)),
        name: .downloadFinishedSuccess,
        object: appDelegate.getMeta(accountInfo).artworkDownloadManager
      )
      appDelegate.notificationHandler.register(
        self,
        selector: #selector(downloadFinishedSuccessful(notification:)),
        name: .downloadFinishedSuccess,
        object: appDelegate.getMeta(accountInfo).playableDownloadManager
      )
    }

    registerForTraitChanges(
      [UITraitUserInterfaceStyle.self, UITraitHorizontalSizeClass.self],
      handler: { (self: Self, previousTraitCollection: UITraitCollection) in
        self.refresh()
      }
    )
  }

  override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
    refreshCellMasks()
    controlView?.refreshView()
    applyGradientBackground()
  }

  override func viewIsAppearing(_ animated: Bool) {
    super.viewIsAppearing(animated)
    appDelegate.userStatistics.visited(.popupPlayer)
    becomeFirstResponder()
    changeDisplayStyleVisually(
      to: appDelegate.storage.settings.user.playerDisplayStyle,
      animated: false
    )
    reloadData()
    scrollToCurrentlyPlayingRow()
    controlView?.refreshView()
    refresh()
    
    // Workaround: Prime the player if this is a resume scenario after app restart
    // This must happen before setting artwork scale, and scale is set after priming completes
    primePlayerIfNeeded()
  }
  
  /// Workaround for a bug where the first play after app restart doesn't produce audio.
  /// If we detect a song with saved progress and the player hasn't been used yet,
  /// we simulate a quick play-pause cycle to "prime" the audio system.
  private func primePlayerIfNeeded() {
    // Only do this once per app session
    guard !Self.hasPlayerBeenPrimedThisSession else {
      // No priming needed, just set initial artwork scale
      largeCurrentlyPlayingView?.setInitialArtworkScale()
      return
    }
    
    // Check if there's a song with saved progress (meaning it was playing before app closed)
    guard let currentPlayable = player.currentlyPlaying,
          currentPlayable.playProgress > 0,
          !player.isPlaying else {
      // No priming needed, just set initial artwork scale
      largeCurrentlyPlayingView?.setInitialArtworkScale()
      return
    }
    
    // Mark as primed so we don't do this again
    Self.hasPlayerBeenPrimedThisSession = true
    
    // Disable artwork scale animation during priming
    largeCurrentlyPlayingView?.isArtworkScaleAnimationEnabled = false
    
    // Mute audio during priming to prevent audible blip
    let savedVolume = player.volume
    player.volume = 0
    
    // Simulate play -> wait 200ms -> pause to prime the audio system
    player.play()
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
      guard let self else { return }
      self.player.pause()
      // Restore volume after pausing
      self.player.volume = savedVolume
      self.controlView?.refreshView()
      // Re-enable artwork scale animation and set initial scale
      self.largeCurrentlyPlayingView?.isArtworkScaleAnimationEnabled = true
      self.largeCurrentlyPlayingView?.setInitialArtworkScale()
    }
  }

  override func viewWillDisappear(_ animated: Bool) {
    super.viewWillDisappear(animated)
    resignFirstResponder()
  }

  override func viewWillLayoutSubviews() {
    adjustLayoutMargins()
  }

  func fetchSongInfoAndUpdateViews() {
    // Song sync is now handled centrally by ScrobbleSyncer when song starts
    // This just refreshes the UI
    refreshCurrentlyPlayingInfoView()
  }

  func reloadData() {
    tableView.reloadData()
    scrollToCurrentlyPlayingRow()
  }

  func scrollToCurrentlyPlayingRow() {
    tableView.scrollToRow(
      at: IndexPath(row: 0, section: PlayerSectionCategory.currentlyPlaying.rawValue),
      at: .top,
      animated: false
    )
  }

  func favoritePressed() {
    switch player.playerMode {
    case .music:
      guard let playableInfo = player.currentlyPlaying else { return }
      if playableInfo.isSong, let account = playableInfo.account {
        Task { @MainActor in
          do {
            try await playableInfo
              .remoteToggleFavorite(
                syncer: self.appDelegate.getMeta(account.info)
                  .librarySyncer
              )
          } catch {
            self.appDelegate.eventLogger.report(topic: "Toggle Favorite", error: error)
          }
          self.refresh()
        }
      } else if let radio = playableInfo.asRadio,
                let siteURL = radio.siteURL {
        UIApplication.shared.open(siteURL)
      }
    case .podcast:
      guard let podcastEpisode = player.currentlyPlaying?.asPodcastEpisode
      else { return }
      let plainDetailsVC = PlainDetailsVC()
      plainDetailsVC.display(podcastEpisode: podcastEpisode, on: self)
      present(plainDetailsVC, animated: true)
    }
  }

  func displayArtistDetail() {
    if let song = player.currentlyPlaying?.asSong, let artist = song.artist,
       let account = artist.account {
      let artistDetailVC = AppStoryboard.Main.segueToArtistDetail(account: account, artist: artist)
      closePopupPlayerAndDisplayInLibraryTab(vc: artistDetailVC)
    }
  }

  func displayAlbumDetail() {
    if let song = player.currentlyPlaying?.asSong, let album = song.album,
       let account = album.account {
      let albumDetailVC = AppStoryboard.Main.segueToAlbumDetail(
        account: account,
        album: album,
        songToScrollTo: song
      )
      closePopupPlayerAndDisplayInLibraryTab(vc: albumDetailVC)
    }
  }

  func displayPodcastDetail() {
    if let podcastEpisode = player.currentlyPlaying?.asPodcastEpisode,
       let podcast = podcastEpisode.podcast,
       let account = podcastEpisode.account {
      let podcastDetailVC = AppStoryboard.Main.segueToPodcastDetail(
        account: account,
        podcast: podcast,
        episodeToScrollTo: podcastEpisode
      )
      closePopupPlayerAndDisplayInLibraryTab(vc: podcastDetailVC)
    }
  }

  func closePopupPlayer() {
    guard let hostingSplitVC = AppDelegate.mainWindowHostVC else { return }
    hostingSplitVC.visualizePopupPlayer(direction: .close, animated: true)
  }

  func closePopupPlayerAndDisplayInLibraryTab(vc: UIViewController) {
    guard let hostingSplitVC = AppDelegate.mainWindowHostVC else { return }
    hostingSplitVC.visualizePopupPlayer(direction: .close, animated: true, completion: { () in
      hostingSplitVC.pushNavLibrary(vc: vc)
    })
  }

  func refreshUserQueueSectionHeader() {
    guard let userQueueSectionView = userQueueSectionHeader else { return }
    if player.userQueueCount == 0 {
      userQueueSectionView.hide()
    } else {
      userQueueSectionView.display(
        name: PlayerQueueType.user.description,
        buttonPressAction: clearUserQueue
      )
    }
  }

  func refreshContextQueueSectionHeader() {
    guard let contextNextQueueSectionHeader = contextNextQueueSectionHeader else { return }
    contextNextQueueSectionHeader.refresh()
  }

  // MARK: - UIScrollViewDelegate

  func scrollViewDidScroll(_ scrollView: UIScrollView) {
    refreshCellMasks()
  }

  func refreshCellMasks() {
    guard let topSection = Array(activeDisplayedSectionHeader)
      .sorted(by: { $0.rawValue < $1.rawValue }).first
    else { return }

    let topSectionHeight = tableView(tableView, heightForHeaderInSection: topSection.rawValue)
    let scrollOffset = tableView.contentOffset.y

    for cell in tableView.visibleCells {
      let hiddenFrameHeight = scrollOffset + topSectionHeight - cell.frame.origin.y
      if hiddenFrameHeight >= 0 || hiddenFrameHeight <= cell.frame.size.height {
        if let customCell = cell as? PlayableTableCell {
          customCell.maskCell(fromTop: hiddenFrameHeight)
        }
      }
    }
  }

  func refreshCellsContent() {
    for cell in tableView.visibleCells {
      guard let playableCell = cell as? PlayableTableCell else { continue }
      playableCell.refresh()
    }
  }
}

// MARK: MusicPlayable

extension PopupPlayerVC: MusicPlayable {
  func didStartPlayingFromBeginning() {
    fetchSongInfoAndUpdateViews()
    largeCurrentlyPlayingView?.initializeLyrics()
  }

  func didStartPlaying() {
    reloadData()
    refresh()
    largeCurrentlyPlayingView?.onPlayerPlay()
  }

  func didStopPlaying() {
    reloadData()
    refresh()
  }

  func didPlaylistChange() {
    reloadData()
    refresh()
  }

  func didPause() {
    largeCurrentlyPlayingView?.onPlayerPause()
  }
  func didElapsedTimeChange() {}

  func didLyricsTimeChange(time: CMTime) {
    largeCurrentlyPlayingView?.refreshLyricsTime(time: time)
  }

  func didArtworkChange() {
    refreshCurrentlyPlayingArtworks()
  }

  func didShuffleChange() {}
  func didRepeatChange() {}
  func didPlaybackRateChange() {}
}
