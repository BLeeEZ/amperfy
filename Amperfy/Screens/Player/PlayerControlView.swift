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

  func prepare(toWorkOnRootView: PopupPlayerVC?) {
    rootView = toWorkOnRootView

    playerHandler = PlayerUIHandler(player: player, style: .popupPlayer)

    playButton.imageView?.tintColor = .label
    previousButton.tintColor = .label
    nextButton.tintColor = .label
    skipBackwardButton.tintColor = .label
    skipForwardButton.tintColor = .label
    airplayButton.tintColor = .label
    playerModeButton.tintColor = .label
    volumeButton.tintColor = .label
    optionsButton.imageView?.tintColor = .label
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
          audioInfoLabel: self.audioInfoLabel,
          playTypeIcon: self.playTypeIcon,
          liveLabel: self.liveLabel
        )
      }
    )
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
    playerHandler?.refreshDisplayPlaylistButton(displayPlaylistButton: displayPlaylistButton)
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
      audioInfoLabel: audioInfoLabel,
      playTypeIcon: playTypeIcon,
      liveLabel: liveLabel
    )
    playerHandler?.refreshPrevNextButtons(previousButton: previousButton, nextButton: nextButton)
    playerHandler?.refreshDisplayPlaylistButton(displayPlaylistButton: displayPlaylistButton)
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
    if player.currentlyPlaying != nil || player.prevQueueCount > 0 || player
      .userQueueCount > 0 || player.nextQueueCount > 0 {
      let clearPlayer = UIAction(title: "Clear Player", image: .clear, handler: { _ in
        self.player.clearQueues()
      })
      menuActions.append(clearPlayer)
    }
    if player.userQueueCount > 0 {
      let clearUserQueue = UIAction(title: "Clear User Queue", image: .playlistX, handler: { _ in
        self.rootView?.clearUserQueue()
      })
      menuActions.append(clearUserQueue)
    }

    menuActions.append(appDelegate.createSleepTimerMenu(refreshCB: nil))
    menuActions.append(createPlaybackRateMenu())

    if rootView?.largeCurrentlyPlayingView?.isLyricsButtonAllowedToDisplay ?? false {
      if !appDelegate.storage.settings.user.isPlayerLyricsDisplayed ||
        appDelegate.storage.settings.user.playerDisplayStyle != .large {
        let showLyricsAction = UIAction(title: "Show Lyrics", image: .lyrics, handler: { _ in
          if !self.appDelegate.storage.settings.user.isPlayerLyricsDisplayed {
            self.appDelegate.storage.settings.user.isPlayerLyricsDisplayed.toggle()
            self.appDelegate.storage.settings.user.isPlayerVisualizerDisplayed = false
            self.rootView?.largeCurrentlyPlayingView?.display(element: .lyrics)
          }
          if self.appDelegate.storage.settings.user.playerDisplayStyle != .large {
            self.displayPlaylistPressed()
          }
        })
        menuActions.append(showLyricsAction)
      } else {
        let hideLyricsAction = UIAction(title: "Hide Lyrics", image: .lyrics, handler: { _ in
          self.appDelegate.storage.settings.user.isPlayerLyricsDisplayed.toggle()
          self.rootView?.largeCurrentlyPlayingView?.display(element: .artwork)
        })
        menuActions.append(hideLyricsAction)
      }
    }

    if !appDelegate.storage.settings.user.isPlayerVisualizerDisplayed ||
      appDelegate.storage.settings.user.playerDisplayStyle != .large {
      let showVisualizerAction = UIAction(
        title: "Show Audio Visualizer",
        image: .audioVisualizer,
        handler: { _ in
          if !self.appDelegate.storage.settings.user.isPlayerVisualizerDisplayed {
            self.appDelegate.storage.settings.user.isPlayerVisualizerDisplayed = true
            self.appDelegate.storage.settings.user.isPlayerLyricsDisplayed = false
            self.rootView?.largeCurrentlyPlayingView?.display(element: .visualizer)
          }
          if self.appDelegate.storage.settings.user.playerDisplayStyle != .large {
            self.displayPlaylistPressed()
          }
        }
      )
      menuActions.append(showVisualizerAction)
    } else {
      let hideVisualizerAction = UIAction(
        title: "Hide Audio Visualizer",
        image: .audioVisualizer,
        handler: { _ in
          self.appDelegate.storage.settings.user.isPlayerVisualizerDisplayed = false
          self.rootView?.largeCurrentlyPlayingView?.display(element: .artwork)
        }
      )
      menuActions.append(hideVisualizerAction)

      // Add visualizer type selector submenu
      menuActions.append(createVisualizerTypeMenu())
    }

    switch player.playerMode {
    case .music:
      if player.currentlyPlaying != nil || player.prevQueueCount > 0 || player.nextQueueCount > 0,
         appDelegate.storage.settings.user.isOnlineMode {
        let addContextToPlaylist = UIAction(
          title: "Add Context Queue to Playlist",
          image: .playlistPlus,
          handler: { _ in
            var itemsToAdd = self.player.getAllPrevQueueItems().filterSongs()
            if let currentlyPlaying = self.player.currentlyPlaying,
               let currentSong = currentlyPlaying.asSong {
              itemsToAdd.append(currentSong)
            }
            itemsToAdd.append(contentsOf: self.player.getAllNextQueueItems().filterSongs())
            // allow add to playlist only if all songs belong to the same account
            guard let firstItemAccount = itemsToAdd.first?.account,
                  itemsToAdd.count == itemsToAdd.filter({ $0.account == firstItemAccount }).count
            else { return }
            let selectPlaylistVC = AppStoryboard.Main
              .segueToPlaylistSelector(account: firstItemAccount, itemsToAdd: itemsToAdd)
            let selectPlaylistNav = UINavigationController(rootViewController: selectPlaylistVC)
            self.rootView?.present(selectPlaylistNav, animated: true, completion: nil)
          }
        )
        menuActions.append(addContextToPlaylist)
      }
    case .podcast: break
    }

    switch appDelegate.storage.settings.user.playerDisplayStyle {
    case .compact:
      let scrollToCurrentlyPlaying = UIAction(
        title: "Scroll to currently playing",
        image: .squareArrow,
        handler: { _ in
          self.rootView?.scrollToCurrentlyPlayingRow()
        }
      )
      menuActions.append(scrollToCurrentlyPlaying)
    case .large: break
    }

    let playerInfo = UIAction(title: "Player Info", image: .info, handler: { _ in
      guard let rootView = self.rootView else { return }
      let detailVC = PlainDetailsVC()
      detailVC.display(player: self.player, on: rootView)
      rootView.present(detailVC, animated: true)
    })
    menuActions.append(playerInfo)
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
