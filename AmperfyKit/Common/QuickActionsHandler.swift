//
//  QuickActionsHandler.swift
//  AmperfyKit
//
//  Created by Maximilian Bauer on 19.02.24.
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

import UIKit

// MARK: - QuickActionsHandler

@MainActor
public class QuickActionsHandler {
  private let storage: PersistentStorage
  private let player: PlayerFacade
  private let application: UIApplication
  private let displaySearchTabCB: () -> ()

  private var savedShortCutItem: UIApplicationShortcutItem?

  public init(
    storage: PersistentStorage,
    player: PlayerFacade,
    application: UIApplication,
    displaySearchTabCB: @escaping @MainActor () -> ()
  ) {
    self.storage = storage
    self.player = player
    self.application = application
    self.displaySearchTabCB = displaySearchTabCB
    self.player.addNotifier(notifier: self)
  }

  // List of known shortcut actions.
  enum QuickActionType: String {
    case searchAction = "SearchAction"
    case playMusicAction = "PlayMusicAction"
    case playPodcastAction = "PlayPodcastAction"
    case onlineModeAction = "OnlineModeAction"
    case offlineModeAction = "OfflineModeAction"
  }

  public func savedShortCutItemForLaterUse(savedShortCutItem: UIApplicationShortcutItem) {
    self.savedShortCutItem = savedShortCutItem
  }

  public func handleSavedShortCutItemIfSaved() {
    if let savedShortCutItem = savedShortCutItem {
      _ = handleShortCutItem(shortcutItem: savedShortCutItem)
      self.savedShortCutItem = nil
    }
  }

  public func configureQuickActions() {
    var quickActions = [UIApplicationShortcutItem]()

    guard storage.settings.app.isLibrarySynced else {
      application.shortcutItems = quickActions
      return
    }

    quickActions.append(UIApplicationShortcutItem(
      type: QuickActionType.searchAction.rawValue,
      localizedTitle: "Search",
      localizedSubtitle: nil,
      icon: UIApplicationShortcutIcon(systemImageName: "magnifyingglass"),
      userInfo: nil
    ))

    if let currentMusicItem = player.currentMusicItem {
      let isPlaying = player.isPlaying && player.playerMode == .music
      quickActions.append(UIApplicationShortcutItem(
        type: QuickActionType.playMusicAction.rawValue,
        localizedTitle: isPlaying ? "Pause Song" : "Play Song",
        localizedSubtitle: "\(currentMusicItem.subtitle ?? "Unknown Artist") - \(currentMusicItem.title)",
        icon: UIApplicationShortcutIcon(
          systemImageName: isPlaying ? "pause.circle" :
            "play.circle"
        ),
        userInfo: nil
      ))
    }
    if let currentPodcastItem = player.currentPodcastItem {
      let isPlaying = player.isPlaying && player.playerMode == .podcast
      quickActions.append(UIApplicationShortcutItem(
        type: QuickActionType.playPodcastAction.rawValue,
        localizedTitle: isPlaying ? "Pause Podcast" : "Play Podcast",
        localizedSubtitle: "\(currentPodcastItem.subtitle ?? "Unknown Podcast") - \(currentPodcastItem.title)",
        icon: UIApplicationShortcutIcon(
          systemImageName: isPlaying ? "pause.circle" :
            "play.circle"
        ),
        userInfo: nil
      ))
    }
    if storage.settings.user.isOfflineMode {
      quickActions.append(UIApplicationShortcutItem(
        type: QuickActionType.onlineModeAction.rawValue,
        localizedTitle: "Start in Online Mode",
        localizedSubtitle: nil,
        icon: UIApplicationShortcutIcon(systemImageName: AmperfyImage.onlineMode.systemName),
        userInfo: nil
      ))
    } else {
      quickActions.append(UIApplicationShortcutItem(
        type: QuickActionType.offlineModeAction.rawValue,
        localizedTitle: "Start in Offline Mode",
        localizedSubtitle: nil,
        icon: UIApplicationShortcutIcon(systemImageName: AmperfyImage.offlineMode.systemName),
        userInfo: nil
      ))
    }
    application.shortcutItems = quickActions
  }

  public func handleShortCutItem(shortcutItem: UIApplicationShortcutItem) -> Bool {
    if let actionTypeValue = QuickActionType(rawValue: shortcutItem.type) {
      switch actionTypeValue {
      case .searchAction:
        displaySearchTabCB()
      case .playMusicAction:
        if player.playerMode != .music {
          player.setPlayerMode(.music)
        }
        if player.isPlaying, player.playerMode == .music {
          player.pause()
        } else {
          player.play()
        }
      case .playPodcastAction:
        if player.playerMode != .podcast {
          player.setPlayerMode(.podcast)
        }
        if player.isPlaying, player.playerMode == .podcast {
          player.pause()
        } else {
          player.play()
        }
      case .offlineModeAction:
        storage.settings.user.isOfflineMode = true
      case .onlineModeAction:
        storage.settings.user.isOfflineMode = false
      }
    }
    return true
  }
}

// MARK: MusicPlayable

extension QuickActionsHandler: MusicPlayable {
  public func didStartPlayingFromBeginning() {}
  public func didStartPlaying() {
    configureQuickActions()
  }

  public func didPause() {
    configureQuickActions()
  }

  public func didStopPlaying() {
    configureQuickActions()
  }

  public func didElapsedTimeChange() {}
  public func didPlaylistChange() {}
  public func didArtworkChange() {}
  public func didShuffleChange() {}
  public func didRepeatChange() {}
  public func didPlaybackRateChange() {}
}
