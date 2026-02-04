//
//  PlayerControlView.swift
//  Amperfy
//
//  Created by Maximilian Bauer on 07.02.24.
//  Copyright (c) 2024 Maximilian Bauer. All rights reserved.
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
import MarqueeLabel
import MediaPlayer
import UIKit

// MARK: - PlayerControlView

class PlayerControlView: UIView {
  static let frameHeight: CGFloat = 175
  static private let margin = UIEdgeInsets(
    top: 0,
    left: UIView.defaultMarginX,
    bottom: 20,
    right: UIView.defaultMarginX
  )

  private var player: PlayerFacade!
  private var rootView: PopupPlayerVC?
  private var playerHandler: PlayerUIHandler?
  #if targetEnvironment(macCatalyst) // ok
    var airplayVolume: MPVolumeView?
  #endif

  @IBOutlet
  weak var playButton: UIButton!
  @IBOutlet
  weak var previousButton: UIButton!
  @IBOutlet
  weak var nextButton: UIButton!
  @IBOutlet
  weak var skipBackwardButton: UIButton!
  @IBOutlet
  weak var skipForwardButton: UIButton!

  @IBOutlet
  weak var timeSlider: UISlider!
  @IBOutlet
  weak var elapsedTimeLabel: UILabel!
  @IBOutlet
  weak var remainingTimeLabel: UILabel!
  @IBOutlet
  weak var totalTimeLabel: UILabel!
  @IBOutlet
  weak var liveLabel: UILabel!
  @IBOutlet
  weak var audioInfoLabel: UILabel!
  @IBOutlet
  weak var playTypeIcon: UIImageView!

  @IBOutlet
  weak var optionsStackView: UIStackView!
  @IBOutlet
  weak var playerModeButton: UIButton!
  @IBOutlet
  weak var airplayButton: UIButton!
  @IBOutlet
  weak var displayPlaylistButton: UIButton!
  @IBOutlet
  weak var volumeButton: UIButton!
  @IBOutlet
  weak var optionsButton: UIButton!

  required init?(coder aDecoder: NSCoder) {
    #if targetEnvironment(macCatalyst) // ok
      self.airplayVolume = MPVolumeView(frame: .zero)
      airplayVolume!.showsVolumeSlider = false
      airplayVolume!.isHidden = true
    #endif

    super.init(coder: aDecoder)
    self.layoutMargins = Self.margin
    self.player = appDelegate.player
    player.addNotifier(notifier: self)

    #if targetEnvironment(macCatalyst) // ok
      addSubview(airplayVolume!)
    #endif
  }

  private var infoButton: UIButton!
  private var themeColor: UIColor = .customDarkLabel
  
  func prepare(toWorkOnRootView: PopupPlayerVC?) {
    rootView = toWorkOnRootView

    playerHandler = PlayerUIHandler(player: player, style: .popupPlayer)

    // Get theme color from account settings
    themeColor = appDelegate.storage.settings.accounts.activeSetting.read.themePreference.asColor

    playButton.imageView?.tintColor = .customDarkLabel
    previousButton.tintColor = .customDarkLabel
    nextButton.tintColor = .customDarkLabel
    skipBackwardButton.tintColor = .customDarkLabel
    skipForwardButton.tintColor = .customDarkLabel
    playerModeButton.tintColor = .customDarkLabel
    
    // Use theme color for the 4 bottom-right buttons
    airplayButton.tintColor = themeColor
    displayPlaylistButton.tintColor = themeColor
    optionsButton.tintColor = themeColor
    
    // Hide volume button and replace with info button
    volumeButton.isHidden = true
    setupInfoButton(themeColor: themeColor)
    
    refreshPlayer()
    playerHandler?.refreshPlayerOptions(
      optionsButton: optionsButton,
      menuCreateCB: createPlayerOptionsMenu
    )

    registerForTraitChanges(
      [UITraitUserInterfaceStyle.self, UITraitHorizontalSizeClass.self],
      handler: { (self: Self, previousTraitCollection: UITraitCollection) in
        self.playerHandler?.refreshTimeInfo(
          timeSlider: self.timeSlider,
          elapsedTimeLabel: self.elapsedTimeLabel,
          remainingTimeLabel: self.remainingTimeLabel,
          totalTimeLabel: self.totalTimeLabel,
          audioInfoLabel: self.audioInfoLabel,
          playTypeIcon: self.playTypeIcon,
          liveLabel: self.liveLabel
        )
      }
    )
  }
  
  private func setupInfoButton(themeColor: UIColor) {
    infoButton = UIButton(type: .system)
    infoButton.translatesAutoresizingMaskIntoConstraints = false
    
    let config = UIImage.SymbolConfiguration(pointSize: 20, weight: .regular)
    let infoImage = UIImage(systemName: "info.circle", withConfiguration: config)
    infoButton.setImage(infoImage, for: .normal)
    infoButton.tintColor = themeColor
    infoButton.contentEdgeInsets = UIEdgeInsets(top: 2, left: 2, bottom: 2, right: 2)
    
    infoButton.addTarget(self, action: #selector(infoButtonPressed), for: .touchUpInside)
    
    // Insert info button at the same position as volume button in the stack view
    if let volumeIndex = optionsStackView.arrangedSubviews.firstIndex(of: volumeButton) {
      optionsStackView.insertArrangedSubview(infoButton, at: volumeIndex)
    }
    
    NSLayoutConstraint.activate([
      infoButton.widthAnchor.constraint(equalToConstant: 28),
      infoButton.heightAnchor.constraint(equalToConstant: 28),
    ])
  }
  
  @objc
  private func infoButtonPressed() {
    guard let playable = player.currentlyPlaying else { return }
    let metadataVC = SongMetadataVC()
    metadataVC.playable = playable
    
    metadataVC.modalPresentationStyle = .popover
    metadataVC.preferredContentSize = CGSize(width: 320, height: 480)
    
    if let popover = metadataVC.popoverPresentationController {
      popover.sourceView = infoButton
      popover.sourceRect = infoButton.bounds
      popover.permittedArrowDirections = .down
      popover.delegate = metadataVC
      popover.backgroundColor = .clear
    }
    
    rootView?.present(metadataVC, animated: true)
  }

  @IBAction
  func swipeHandler(_ gestureRecognizer: UISwipeGestureRecognizer) {
    if gestureRecognizer.state == .ended {
      rootView?.closePopupPlayer()
    }
  }

  @IBAction
  func playButtonPushed(_ sender: Any) {
    playerHandler?.playButtonPushed()
    playerHandler?.refreshPlayButton(playButton)
  }

  @IBAction
  func previousButtonPushed(_ sender: Any) {
    playerHandler?.previousButtonPushed()
  }

  @IBAction
  func nextButtonPushed(_ sender: Any) {
    playerHandler?.nextButtonPushed()
  }

  @IBAction
  func skipBackwardButtonPushed(_ sender: Any) {
    playerHandler?.skipBackwardButtonPushed()
  }

  @IBAction
  func skipForwardButtonPushed(_ sender: Any) {
    playerHandler?.skipForwardButtonPushed()
  }

  @IBAction
  func timeSliderChanged(_ sender: Any) {
    playerHandler?.timeSliderChanged(timeSlider: timeSlider)
  }

  @IBAction
  func timeSliderIsChanging(_ sender: Any) {
    playerHandler?.timeSliderIsChanging(
      timeSlider: timeSlider,
      elapsedTimeLabel: elapsedTimeLabel,
      remainingTimeLabel: remainingTimeLabel
    )
  }

  @IBAction
  func airplayButtonPushed(_ sender: UIButton) {
    #if targetEnvironment(macCatalyst) // ok
      playerHandler?.airplayButtonPushed(
        rootView: self,
        airplayButton: airplayButton,
        airplayVolume: airplayVolume
      )
    #else
      playerHandler?.airplayButtonPushed(rootView: self, airplayButton: airplayButton)
    #endif
  }

  @IBAction
  func volumeButtonPressed(_ sender: Any) {
    showVolumeSliderMenu()
  }

  func showVolumeSliderMenu() {
    let popoverContentController = SliderMenuPopover()
    let sliderMenuView = popoverContentController.sliderMenuView
    sliderMenuView.frame = CGRect(x: 0, y: 0, width: 250, height: 50)

    sliderMenuView.slider.minimumValue = 0
    sliderMenuView.slider.maximumValue = 100
    sliderMenuView.slider.value = appDelegate.player.volume * 100

    sliderMenuView.sliderValueChangedCB = {
      self.appDelegate.player.volume = Float(sliderMenuView.slider.value) / 100.0
    }

    popoverContentController.modalPresentationStyle = .popover
    popoverContentController.preferredContentSize = sliderMenuView.frame.size

    if let popoverPresentationController = popoverContentController.popoverPresentationController {
      popoverPresentationController.permittedArrowDirections = .down
      popoverPresentationController.delegate = popoverContentController
      popoverPresentationController.sourceView = volumeButton
      rootView?.present(
        popoverContentController,
        animated: true,
        completion: nil
      )
    }
  }

  @IBAction
  func displayPlaylistPressed() {
    rootView?.switchDisplayStyleOptionPersistent()
    playerHandler?.refreshDisplayPlaylistButton(displayPlaylistButton: displayPlaylistButton, themeColor: themeColor)
    playerHandler?.refreshPlayerOptions(
      optionsButton: optionsButton,
      menuCreateCB: createPlayerOptionsMenu
    )
  }

  @IBAction
  func playerModeChangePressed(_ sender: Any) {
    switch player.playerMode {
    case .music:
      appDelegate.player.setPlayerMode(.podcast)
    case .podcast:
      appDelegate.player.setPlayerMode(.music)
    }
    refreshPlayerModeChangeButton()
  }

  func refreshView() {
    refreshPlayer()
  }

  func refreshPlayer() {
    playerHandler?.refreshSkipButtons(
      skipBackwardButton: skipBackwardButton,
      skipForwardButton: skipForwardButton
    )
    playerHandler?.refreshPlayButton(playButton)
    playerHandler?.refreshTimeInfo(
      timeSlider: timeSlider,
      elapsedTimeLabel: elapsedTimeLabel,
      remainingTimeLabel: remainingTimeLabel,
      totalTimeLabel: totalTimeLabel,
      audioInfoLabel: audioInfoLabel,
      playTypeIcon: playTypeIcon,
      liveLabel: liveLabel
    )
    playerHandler?.refreshPrevNextButtons(previousButton: previousButton, nextButton: nextButton)
    playerHandler?.refreshDisplayPlaylistButton(displayPlaylistButton: displayPlaylistButton, themeColor: themeColor)
    refreshPlayerModeChangeButton()
  }

  func createPlaybackRateMenu() -> UIMenuElement {
    let playerPlaybackRate = player.playbackRate
    let availablePlaybackRates: [UIAction] = PlaybackRate.allCases.compactMap { playbackRate in
      UIAction(
        title: playbackRate.description,
        image: playbackRate == playerPlaybackRate ? .check : nil,
        handler: { _ in
          self.player.setPlaybackRate(playbackRate)
        }
      )
    }
    return UIMenu(
      title: "Playback Rate",
      subtitle: playerPlaybackRate.description,
      image: .playbackRate,
      children: availablePlaybackRates
    )
  }

  func createVisualizerTypeMenu() -> UIMenuElement {
    let currentType = appDelegate.storage.settings.user.selectedVisualizerType
    let availableTypes: [UIAction] = VisualizerType.allCases.reversed()
      .compactMap { visualizerType in
        UIAction(
          title: visualizerType.displayName,
          image: UIImage(systemName: visualizerType.iconName),
          state: visualizerType == currentType ? .on : .off,
          handler: { _ in
            self.appDelegate.storage.settings.user.selectedVisualizerType = visualizerType
            self.rootView?.largeCurrentlyPlayingView?.showVisualizer()
          }
        )
      }
    return UIMenu(
      title: "Visualizer Style",
      subtitle: currentType.displayName,
      image: .sparkles,
      children: availableTypes
    )
  }

  func createPlayerOptionsMenu() -> [UIMenuElement] {
    var menuActions = [UIMenuElement]()
    
    // Build in REVERSE order since iOS displays menus upside down
    
    // Section 4 (last visually): Clear Queue, Delete Cache
    var queueActions = [UIMenuElement]()
    
    // Delete Cache (will appear second)
    if let currentlyPlaying = player.currentlyPlaying,
       currentlyPlaying.isCached, let account = currentlyPlaying.account {
      let deleteCacheAction = UIAction(title: "Delete Cache", image: .trash, attributes: .destructive, handler: { _ in
        let alert = UIAlertController(
          title: nil,
          message: "Are you sure to delete the cached file of \"\(currentlyPlaying.displayString)\" from this device?",
          preferredStyle: .actionSheet
        )
        alert.addAction(UIAlertAction(title: "Delete", style: .destructive, handler: { _ in
          self.appDelegate.getMeta(account.info).playableDownloadManager
            .removeFinishedDownload(for: [currentlyPlaying])
          self.appDelegate.storage.main.library.deleteCache(of: [currentlyPlaying])
          self.appDelegate.storage.main.saveContext()
        }))
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        self.rootView?.present(alert, animated: true)
      })
      queueActions.append(deleteCacheAction)
    }
    
    // Clear Queue (will appear first)
    let totalQueueCount = player.prevQueueCount + (player.currentlyPlaying != nil ? 1 : 0) + player.userQueueCount + player.nextQueueCount
    if totalQueueCount > 0 {
      let clearQueue = UIAction(title: "Clear Queue", image: .clear, handler: { _ in
        let itemText = totalQueueCount == 1 ? "item" : "items"
        let alert = UIAlertController(
          title: nil,
          message: "Should the current queue with \(totalQueueCount) \(itemText) really be cleared?",
          preferredStyle: .actionSheet
        )
        alert.addAction(UIAlertAction(title: "Clear Queue", style: .destructive, handler: { _ in
          self.player.clearQueues()
        }))
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        self.rootView?.present(alert, animated: true)
      })
      queueActions.append(clearQueue)
    }
    
    if !queueActions.isEmpty {
      menuActions.append(UIMenu(options: .displayInline, children: queueActions))
    }
    
    // Section 3: Sleep Timer, Playback Rate
    var timerActions = [UIMenuElement]()
    timerActions.append(createPlaybackRateMenu())
    timerActions.append(appDelegate.createSleepTimerMenu(refreshCB: nil))
    menuActions.append(UIMenu(options: .displayInline, children: timerActions))
    
    // Section 2: Show Artist, Show Album
    var navigationActions = [UIMenuElement]()
    
    if let currentlyPlaying = player.currentlyPlaying {
      // Show Album (will appear second)
      if let song = currentlyPlaying.asSong, let album = song.album, let account = song.account {
        let showAlbumAction = UIAction(title: "Show Album", image: .album, handler: { _ in
          let albumDetailVC = AppStoryboard.Main.segueToAlbumDetail(
            account: account,
            album: album,
            songToScrollTo: song
          )
          self.rootView?.closePopupPlayerAndDisplayInLibraryTab(vc: albumDetailVC)
        })
        navigationActions.append(showAlbumAction)
      }
      
      // Show Artist (will appear first)
      if let song = currentlyPlaying.asSong, let artist = song.artist, let account = song.account {
        let showArtistAction = UIAction(title: "Show Artist", image: .artist, handler: { _ in
          let artistDetailVC = AppStoryboard.Main.segueToArtistDetail(
            account: account,
            artist: artist
          )
          self.rootView?.closePopupPlayerAndDisplayInLibraryTab(vc: artistDetailVC)
        })
        navigationActions.append(showArtistAction)
      }
    }
    
    if !navigationActions.isEmpty {
      menuActions.append(UIMenu(options: .displayInline, children: navigationActions))
    }
    
    // Section 1 (first visually): Add to Playlist, Add Queue to Playlist
    var playlistActions = [UIMenuElement]()
    
    // Add Queue to Playlist (will appear second)
    if player.playerMode == .music,
       player.currentlyPlaying != nil || player.prevQueueCount > 0 || player.nextQueueCount > 0,
       appDelegate.storage.settings.user.isOnlineMode {
      let addQueueToPlaylist = UIAction(title: "Add Queue to Playlist", image: .playlistPlus, handler: { _ in
        var itemsToAdd = self.player.getAllPrevQueueItems().filterSongs()
        if let currentlyPlaying = self.player.currentlyPlaying,
           let currentSong = currentlyPlaying.asSong {
          itemsToAdd.append(currentSong)
        }
        itemsToAdd.append(contentsOf: self.player.getAllNextQueueItems().filterSongs())
        guard let firstItemAccount = itemsToAdd.first?.account,
              itemsToAdd.count == itemsToAdd.filter({ $0.account == firstItemAccount }).count
        else { return }
        let selectPlaylistVC = AppStoryboard.Main
          .segueToPlaylistSelector(account: firstItemAccount, itemsToAdd: itemsToAdd)
        let selectPlaylistNav = UINavigationController(rootViewController: selectPlaylistVC)
        self.rootView?.present(selectPlaylistNav, animated: true, completion: nil)
      })
      playlistActions.append(addQueueToPlaylist)
    }
    
    // Add to Playlist (will appear first)
    if let currentlyPlaying = player.currentlyPlaying,
       currentlyPlaying.isSong, appDelegate.storage.settings.user.isOnlineMode,
       let account = currentlyPlaying.account {
      let addToPlaylistAction = UIAction(title: "Add to Playlist", image: .playlistPlus, handler: { _ in
        let selectPlaylistVC = AppStoryboard.Main
          .segueToPlaylistSelector(account: account, itemsToAdd: [currentlyPlaying].filterSongs())
        let selectPlaylistNav = UINavigationController(rootViewController: selectPlaylistVC)
        self.rootView?.present(selectPlaylistNav, animated: true)
      })
      playlistActions.append(addToPlaylistAction)
    }
    
    if !playlistActions.isEmpty {
      menuActions.append(UIMenu(options: .displayInline, children: playlistActions))
    }

    return menuActions
  }

  func refreshPlayerModeChangeButton() {
    playerModeButton.isHidden = appDelegate.player.podcastItemCount == 0 && appDelegate.player
      .playerMode != .podcast
    switch player.playerMode {
    case .music:
      playerModeButton.setImage(UIImage.musicalNotes, for: .normal)
    case .podcast:
      playerModeButton.setImage(UIImage.podcast, for: .normal)
    }
    optionsStackView.layoutIfNeeded()
  }
}

// MARK: MusicPlayable

extension PlayerControlView: MusicPlayable {
  func didStartPlayingFromBeginning() {}

  func didStartPlaying() {
    refreshPlayer()
  }

  func didPause() {
    refreshPlayer()
  }

  func didStopPlaying() {
    refreshPlayer()
    playerHandler?.refreshSkipButtons(
      skipBackwardButton: skipBackwardButton,
      skipForwardButton: skipForwardButton
    )
  }

  func didElapsedTimeChange() {
    playerHandler?.refreshTimeInfo(
      timeSlider: timeSlider,
      elapsedTimeLabel: elapsedTimeLabel,
      remainingTimeLabel: remainingTimeLabel,
      totalTimeLabel: totalTimeLabel,
      audioInfoLabel: audioInfoLabel,
      playTypeIcon: playTypeIcon,
      liveLabel: liveLabel
    )
  }

  func didPlaylistChange() {
    refreshPlayer()
  }

  func didArtworkChange() {}

  func didShuffleChange() {}

  func didRepeatChange() {}

  func didPlaybackRateChange() {}
}
