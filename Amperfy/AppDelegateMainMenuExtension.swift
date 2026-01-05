//
//  AppDelegateMainMenuExtension.swift
//  Amperfy
//
//  Created by Maximilian Bauer on 08.08.25.
//  Copyright (c) 2025 Maximilian Bauer. All rights reserved.
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
@preconcurrency import UIKit

extension AppDelegate {
  func configureMainMenu() {
    let config = UIMainMenuSystem.Configuration()
    config.newScenePreference = .removed
    config.documentPreference = .removed
    config.printingPreference = .removed
    config.findingPreference = .included
    config.findingConfiguration.style = .search
    config.toolbarPreference = .included
    config.sidebarPreference = .included
    config.inspectorPreference = .included
    config.textFormattingPreference = .removed

    UIMainMenuSystem.shared.setBuildConfiguration(config) { builder in
      self.buildMainMenu(with: builder)
    }
  }

  public func rebuildMainMenu() {
    UIMenuSystem.main.setNeedsRebuild()
  }

  private func buildMainMenu(with builder: any UIMenuBuilder) {
    guard builder.system == .main else { return }

    #if targetEnvironment(macCatalyst) // ok
      // Add File menu
      let fileMenus = [
        UIMenu(options: .displayInline, children: [
          UIAction(
            title: "Open Player Window",
            image: AmperfyImage.openPlayerWindow.asUIImage,
            attributes: isMainOrMiniPlayerPlayerOpen ? .disabled : []
          ) { _ in
            self.openMainWindow()
          },
          UIKeyCommand(
            title: "Close Player Window",
            image: AmperfyImage.xmark.asUIImage,
            action: #selector(closePlayerWindow),
            input: "W",
            modifierFlags: .command,
            attributes: !isMainOrMiniPlayerPlayerOpen ? .disabled : []
          ),
        ]),
        UIMenu(options: .displayInline, children: [
          UIAction(
            title: "Switch Library/Mini Player",
            image: AmperfyImage.switchPlayerWindow.asUIImage
          ) { _ in
            if self.isShowingMiniPlayer {
              self.closeMiniPlayer()
              // mini player close will automatically (in scene disconnect) open Main again
            } else {
              self.closeMainWindow()
              self.showMiniPlayer()
            }
          },
        ]),
      ]
      builder.insertChild(fileMenus[1], atStartOfMenu: .file)
      builder.insertChild(fileMenus[0], atStartOfMenu: .file)
      let openSettingsMenu = UIMenu(options: .displayInline, children: [
        UIKeyCommand(
          title: "Settings…",
          image: AmperfyImage.settings.asUIImage,
          action: #selector(showSettings),
          input: ",",
          modifierFlags: .command
        ),
      ])
      builder.insertSibling(openSettingsMenu, afterMenu: .about)
    #endif

    // Add media controls
    builder.insertSibling(
      UIMenu(title: "Controls", children: buildControlsMenu()),
      afterMenu: .view
    )

    builder.insertChild(UIMenu(options: .displayInline, children: [
      UIAction(title: "Report an issue on GitHub") { _ in
        if let url = URL(string: "https://github.com/BLeeEZ/amperfy/issues") {
          UIApplication.shared.open(url)
        }
      },
    ]), atStartOfMenu: .help)
  }

  @objc
  private func keyCommandPause() {
    player.pause()
  }

  @objc
  private func keyCommandPlay() {
    player.play()
  }

  @objc
  private func keyCommandStop() {
    player.stop()
  }

  @objc
  private func keyCommandNext() {
    player.playNext()
  }

  @objc
  private func keyCommandPrevious() {
    player.playPreviousOrReplay()
  }

  @objc
  private func keyCommandSkipForward() {
    player.skipForward(interval: player.skipForwardInterval)
  }

  @objc
  private func keyCommandSkipBackward() {
    player.skipBackward(interval: player.skipBackwardInterval)
  }

  @objc
  private func keyCommandGoToCurrent() {
    let playable = player.currentlyPlaying
    guard let album = playable?.asSong?.album, let account = playable?.account else { return }
    appDelegate.userStatistics.usedAction(.alertGoToAlbum)
    let albumDetailVC = AppStoryboard.Main.segueToAlbumDetail(
      account: account,
      album: album,
      songToScrollTo: playable?.asSong
    )
    displayInLibraryTab(vc: albumDetailVC)
  }

  @objc
  private func keyCommandShuffleOn() {
    guard !player.isShuffle else { return }
    player.toggleShuffle()
  }

  @objc
  private func keyCommandShuffleOff() {
    guard player.isShuffle else { return }
    player.toggleShuffle()
  }

  private func buildControlsMenu() -> [UIMenuElement] {
    let isPlaying = player.isPlaying
    let isShuffle = player.isShuffle
    let isSkipAvailable = isPlaying && player.isSkipAvailable
    let hasAlbum = player.currentlyPlaying?.asSong?.album != nil

    let section1 = [
      UIKeyCommand(
        title: isPlaying ? (player.isStopInsteadOfPause ? "Stop Radio" : "Pause") : "Play",
        image: isPlaying ? (player.isStopInsteadOfPause ? .stop : .pause) : .play,
        action: isPlaying ? #selector(keyCommandPause) : #selector(keyCommandPlay),
        input: " "
      ),
      UIKeyCommand(
        title: (isPlaying && player.isStopInsteadOfPause) ? "Stop Player" : "Stop",
        image: .stop,
        action: #selector(keyCommandStop),
        input: ".",
        modifierFlags: .command,
        attributes: []
      ),
      UIKeyCommand(
        title: "Next Track",
        image: .forwardMenu,
        action: #selector(keyCommandNext),
        input: UIKeyCommand.inputRightArrow,
        modifierFlags: .command,
        attributes: []
      ),
      UIKeyCommand(
        title: "Previous Track",
        image: .backwardMenu,
        action: #selector(keyCommandPrevious),
        input: UIKeyCommand.inputLeftArrow,
        modifierFlags: .command,
        attributes: []
      ),
      UIKeyCommand(
        title: "Skip Forward: " + Int(player.skipForwardInterval).description + " sec.",
        image: player.skipForwardIcon,
        action: #selector(keyCommandSkipForward),
        input: UIKeyCommand.inputRightArrow,
        modifierFlags: [.shift, .command],
        attributes: isSkipAvailable ? [] : [.disabled]
      ),
      UIKeyCommand(
        title: "Skip Backward: " + Int(player.skipBackwardInterval).description + " sec.",
        image: player.skipBackwardIcon,
        action: #selector(keyCommandSkipBackward),
        input: UIKeyCommand.inputLeftArrow,
        modifierFlags: [.shift, .command],
        attributes: isSkipAvailable ? [] : [.disabled]
      ),
      UIKeyCommand(
        title: "Go to Current Song",
        image: .currentSongMenu,
        action: #selector(keyCommandGoToCurrent),
        input: "L",
        modifierFlags: [.command],
        attributes: hasAlbum ? [] : [.disabled]
      ),
    ]

    var section2 = [
      UIMenu(
        title: "Playback Rate",
        image: .playbackRate,
        children: PlaybackRate.allCases.map { rate in
          UIAction(
            title: rate.description,
            state: rate == self.player.playbackRate ? .on : .off
          ) { _ in
            self.player.setPlaybackRate(rate)
          }
        }
      ),
    ]

    if appDelegate.player.playerMode == .music {
      let repeatMenu = UIMenu(
        title: "Repeat",
        image: .repeatMenu,
        children: RepeatMode.allCases.map { mode in
          UIAction(
            title: mode.description,
            state: mode == self.player.repeatMode ? .on : .off
          ) { _ in
            self.player.setRepeatMode(mode)
          }
        }
      )
      section2.insert(repeatMenu, at: 0)
    }
    if appDelegate.player.playerMode == .music,
       appDelegate.storage.settings.user.isPlayerShuffleButtonEnabled {
      let shuffleMenu = UIMenu(title: "Shuffle", image: .shuffleMenu, children: [
        UIAction(title: "On", state: isShuffle ? .on : .off) { [weak self] _ in
          self?.keyCommandShuffleOn()
        },
        UIAction(title: "Off", state: !isShuffle ? .on : .off) { [weak self] _ in
          self?.keyCommandShuffleOff()
        },
      ])
      section2.insert(shuffleMenu, at: 0)
    }

    let section3 = [
      createSleepTimerMenu(refreshCB: {
        self.rebuildMainMenu()
      }),
    ]

    let section4 = [
      UIAction(
        title: "Switch Music/Podcast mode",
        image: player.playerMode == .music ? .musicalNotes : .podcast
      ) { _ in
        self.player.setPlayerMode(self.player.playerMode.nextMode)
      },
    ]

    let sections: [[UIMenuElement]] = [section1, section2, section3, section4]

    return sections.reduce([]) { result, section in
      result + [UIMenu(options: .displayInline)] + section
    }
  }

  @objc
  func closePlayerWindow(sender: Any) {
    if isMainWindowOpen {
      closeMainWindow()
    } else if isShowingMiniPlayer {
      closeMiniPlayer()
    }
    rebuildMainMenu()
  }

  @objc
  func showSettings(sender: Any) {
    let settingsActivity = NSUserActivity(activityType: settingsWindowActivityType)
    UIApplication.shared.requestSceneSessionActivation(
      settingsSceneSession,
      userActivity: settingsActivity,
      options: nil,
      errorHandler: nil
    )
  }

  var isShowingMiniPlayer: Bool {
    UIApplication.shared.connectedScenes.contains(where: { $0.session == miniPlayerSceneSession })
  }

  @objc
  func showMiniPlayer(sender: Any? = nil) {
    let miniPlayerActivity = NSUserActivity(activityType: miniPlayerWindowActivityType)
    UIApplication.shared.requestSceneSessionActivation(
      miniPlayerSceneSession,
      userActivity: miniPlayerActivity,
      options: nil,
      errorHandler: nil
    )
  }

  func closeMiniPlayer() {
    UIApplication.shared.connectedScenes
      .filter { $0.session == miniPlayerSceneSession }
      .forEach {
        let options = UIWindowSceneDestructionRequestOptions()
        options.windowDismissalAnimation = .standard
        UIApplication.shared.requestSceneSessionDestruction(
          $0.session,
          options: options,
          errorHandler: nil
        )
      }
  }

  func createSleepTimerMenu(refreshCB: VoidFunctionCallback?) -> UIMenuElement {
    if let timer = sleepTimer {
      let actionTitle = "Turn Off (Pause at: \(timer.fireDate.asShortHrMinString))"
      let deactivate = UIAction(title: actionTitle, image: nil, handler: { _ in
        self.sleepTimer?.invalidate()
        self.sleepTimer = nil
        refreshCB?()
      })
      return UIMenu(
        title: "Sleep Timer",
        subtitle: "Pause at: \(timer.fireDate.asShortHrMinString)",
        image: .sleep,
        children: [deactivate]
      )
    } else if player.isShouldPauseAfterFinishedPlaying {
      let actionTitle = "Turn Off (Pause at end of \(player.playerMode.playableName))"
      let deactivate = UIAction(title: actionTitle, image: nil, handler: { _ in
        self.player.isShouldPauseAfterFinishedPlaying = false
        refreshCB?()
      })
      return UIMenu(
        title: "Sleep Timer",
        subtitle: "Pause at end of \(player.playerMode.playableName)",
        children: [deactivate]
      )
    } else {
      let endOfTrack = UIAction(title: "End of Song or Podcast Episode", image: nil, handler: { _ in
        self.player.isShouldPauseAfterFinishedPlaying = true
        refreshCB?()
      })
      let sleep5 = UIAction(title: "5 Minutes", image: nil, handler: { _ in
        self.activateSleepTimer(timeInterval: TimeInterval(5 * 60))
        refreshCB?()
      })
      let sleep10 = UIAction(title: "10 Minutes", image: nil, handler: { _ in
        self.activateSleepTimer(timeInterval: TimeInterval(10 * 60))
        refreshCB?()
      })
      let sleep15 = UIAction(title: "15 Minutes", image: nil, handler: { _ in
        self.activateSleepTimer(timeInterval: TimeInterval(15 * 60))
        refreshCB?()
      })
      let sleep30 = UIAction(title: "30 Minutes", image: nil, handler: { _ in
        self.activateSleepTimer(timeInterval: TimeInterval(30 * 60))
        refreshCB?()
      })
      let sleep45 = UIAction(title: "45 Minutes", image: nil, handler: { _ in
        self.activateSleepTimer(timeInterval: TimeInterval(45 * 60))
        refreshCB?()
      })
      let sleep60 = UIAction(title: "1 Hour", image: nil, handler: { _ in
        self.activateSleepTimer(timeInterval: TimeInterval(60 * 60))
        refreshCB?()
      })
      let sleep120 = UIAction(title: "2 Hours", image: nil, handler: { _ in
        self.activateSleepTimer(timeInterval: TimeInterval(2 * 60 * 60))
        refreshCB?()
      })
      let sleep240 = UIAction(title: "4 Hours", image: nil, handler: { _ in
        self.activateSleepTimer(timeInterval: TimeInterval(4 * 60 * 60))
        refreshCB?()
      })
      return UIMenu(
        title: "Sleep Timer",
        image: .sleep,
        children: [
          endOfTrack,
          sleep5,
          sleep10,
          sleep15,
          sleep30,
          sleep45,
          sleep60,
          sleep120,
          sleep240,
        ]
      )
    }
  }

  private func activateSleepTimer(timeInterval: TimeInterval) {
    appDelegate.sleepTimer?.invalidate()
    appDelegate.sleepTimer = Timer
      .scheduledTimer(withTimeInterval: timeInterval, repeats: false) { _ in
        Task { @MainActor in
          self.appDelegate.player.pause()
          self.appDelegate.eventLogger.info(
            topic: "Sleep Timer",
            message: "Sleep Timer paused playback."
          )
          self.appDelegate.sleepTimer?.invalidate()
          self.appDelegate.sleepTimer = nil
        }
      }
  }

  var isMainOrMiniPlayerPlayerOpen: Bool {
    isMainWindowOpen || isShowingMiniPlayer
  }

  var isMainWindowOpen: Bool {
    !UIApplication.shared.connectedScenes
      .flatMap { ($0 as? UIWindowScene)?.windows ?? [] }
      .filter { ($0.rootViewController as? MainSceneHostingViewController) != nil }
      .isEmpty
  }

  func closeMainWindow() {
    // Close all main sessions (this might be more than one with multiple tabs open)
    UIApplication.shared.connectedScenes
      .flatMap { ($0 as? UIWindowScene)?.windows ?? [] }
      .filter { ($0.rootViewController as? MainSceneHostingViewController) != nil }
      .compactMap { $0.windowScene?.session }
      .forEach {
        let options = UIWindowSceneDestructionRequestOptions()
        options.windowDismissalAnimation = .standard
        UIApplication.shared.requestSceneSessionDestruction(
          $0,
          options: options,
          errorHandler: nil
        )
      }
  }

  func openMainWindow() {
    let defaultActivity = NSUserActivity(activityType: defaultWindowActivityType)
    UIApplication.shared.requestSceneSessionActivation(
      nil,
      userActivity: defaultActivity,
      options: nil,
      errorHandler: nil
    )
  }
}

// MARK: - AppDelegate + MusicPlayable

extension AppDelegate: MusicPlayable {
  func didStartPlaying() {
    rebuildMainMenu()
  }

  func didPause() {
    rebuildMainMenu()
  }

  func didStopPlaying() {
    rebuildMainMenu()
  }

  func didShuffleChange() {
    rebuildMainMenu()
  }

  func didRepeatChange() {
    rebuildMainMenu()
  }

  func didPlaybackRateChange() {
    rebuildMainMenu()
  }

  func didStartPlayingFromBeginning() {}
  func didElapsedTimeChange() {}
  func didPlaylistChange() {}
  func didArtworkChange() {}
}
