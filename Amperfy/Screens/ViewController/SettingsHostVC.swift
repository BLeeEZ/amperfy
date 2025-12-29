//
//  SettingsHostVC.swift
//  Amperfy
//
//  Created by Maximilian Bauer on 14.09.22.
//  Copyright (c) 2022 Maximilian Bauer. All rights reserved.
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
import Combine
import Foundation
import SwiftUI
import UIKit

class SettingsHostVC: UIViewController {
  lazy var settings: Settings = {
    Settings()
  }()

  var changesAgent: [AnyCancellable] = []
  private var isForOwnWindow = false
  private var accountNotificationHandler: AccountNotificationHandler?

  override var sceneTitle: String { windowSettingsTitle }

  init(isForOwnWindow: Bool) {
    super.init(nibName: nil, bundle: nil)
    self.accountNotificationHandler = AccountNotificationHandler(
      storage: appDelegate.storage,
      notificationHandler: appDelegate.notificationHandler
    )
    accountNotificationHandler?.registerCallbackForActiveAccountChange { [weak self] accountInfo in
      guard let self else { return }
      settings.activeAccountInfo = accountInfo
      refreshAccountSettings(accountInfo: accountInfo)
    }

    self.isForOwnWindow = isForOwnWindow

    var settingsRootView: AnyView? = nil
    if isForOwnWindow {
      settingsRootView = AnyView(
        SettingsTabView()
          .environmentObject(settings)
          .environment(\.managedObjectContext, appDelegate.storage.main.context)
      )
    } else {
      settingsRootView = AnyView(
        SettingsView()
          .environmentObject(settings)
          .environment(\.managedObjectContext, appDelegate.storage.main.context)
      )
    }

    let hostingVC = UIHostingController(
      rootView: settingsRootView
    )
    view.backgroundColor = .clear
    hostingVC.view.frame = view.bounds
    hostingVC.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    hostingVC.view.backgroundColor = .clear

    hostingVC.willMove(toParent: self)
    addChild(hostingVC)
    view.addSubview(hostingVC.view)
    hostingVC.didMove(toParent: self)
  }

  required init?(coder: NSCoder) {
    super.init(coder: coder)
  }

  override func viewIsAppearing(_ animated: Bool) {
    super.viewIsAppearing(animated)
    changesAgent = [AnyCancellable]()

    if !isForOwnWindow {
      extendSafeAreaToAccountForMiniPlayer()
    }

    settings.isOfflineMode = appDelegate.storage.settings.user.isOfflineMode
    changesAgent.append(settings.$isOfflineMode.sink(receiveValue: { newValue in
      let hasValueChanged = self.appDelegate.storage.settings.user.isOfflineMode != newValue
      guard hasValueChanged else { return }
      self.appDelegate.switchOnlineOfflineMode(isOfflineMode: newValue)
    }))

    settings.isShowDetailedInfo = appDelegate.storage.settings.user.isShowDetailedInfo
    changesAgent.append(settings.$isShowDetailedInfo.sink(receiveValue: { newValue in
      self.appDelegate.storage.settings.user.isShowDetailedInfo = newValue
    }))

    settings.isShowSongDuration = appDelegate.storage.settings.user.isShowSongDuration
    changesAgent.append(settings.$isShowSongDuration.sink(receiveValue: { newValue in
      self.appDelegate.storage.settings.user.isShowSongDuration = newValue
    }))

    settings.isShowAlbumDuration = appDelegate.storage.settings.user.isShowAlbumDuration
    changesAgent.append(settings.$isShowAlbumDuration.sink(receiveValue: { newValue in
      self.appDelegate.storage.settings.user.isShowAlbumDuration = newValue
    }))

    settings.isShowArtistDuration = appDelegate.storage.settings.user.isShowArtistDuration
    changesAgent.append(settings.$isShowArtistDuration.sink(receiveValue: { newValue in
      self.appDelegate.storage.settings.user.isShowArtistDuration = newValue
    }))

    settings.isPlayerShuffleButtonEnabled = appDelegate.storage.settings.user
      .isPlayerShuffleButtonEnabled
    changesAgent.append(settings.$isPlayerShuffleButtonEnabled.sink(receiveValue: { newValue in
      self.appDelegate.storage.settings.user.isPlayerShuffleButtonEnabled = newValue
    }))

    settings.isShowMusicPlayerSkipButtons = appDelegate.storage.settings.user
      .isShowMusicPlayerSkipButtons
    changesAgent.append(settings.$isShowMusicPlayerSkipButtons.sink(receiveValue: { newValue in
      self.appDelegate.storage.settings.user.isShowMusicPlayerSkipButtons = newValue
    }))

    settings.isLyricsSmoothScrolling = appDelegate.storage.settings.user.isLyricsSmoothScrolling
    changesAgent.append(settings.$isLyricsSmoothScrolling.sink(receiveValue: { newValue in
      self.appDelegate.storage.settings.user.isLyricsSmoothScrolling = newValue
    }))

    settings.screenLockPreventionPreference = appDelegate.storage.settings.user
      .screenLockPreventionPreference
    changesAgent.append(settings.$screenLockPreventionPreference.sink(receiveValue: { newValue in
      self.appDelegate.storage.settings.user.screenLockPreventionPreference = newValue
    }))

    settings.streamingMaxBitrateWifiPreference = appDelegate.storage.settings.user
      .streamingMaxBitrateWifiPreference
    changesAgent.append(settings.$streamingMaxBitrateWifiPreference.sink(receiveValue: { newValue in
      self.appDelegate.storage.settings.user.streamingMaxBitrateWifiPreference = newValue
    }))

    settings.streamingMaxBitrateCellularPreference = appDelegate.storage.settings.user
      .streamingMaxBitrateCellularPreference
    changesAgent
      .append(settings.$streamingMaxBitrateCellularPreference.sink(receiveValue: { newValue in
        self.appDelegate.storage.settings.user.streamingMaxBitrateCellularPreference = newValue
      }))

    settings.streamingFormatCellularPreference = appDelegate.storage.settings.user
      .streamingFormatCellularPreference
    changesAgent.append(settings.$streamingFormatCellularPreference.sink(receiveValue: { newValue in
      self.appDelegate.storage.settings.user.streamingFormatCellularPreference = newValue
    }))

    settings.streamingFormatWifiPreference = appDelegate.storage.settings.user
      .streamingFormatWifiPreference
    changesAgent.append(settings.$streamingFormatWifiPreference.sink(receiveValue: { newValue in
      self.appDelegate.storage.settings.user.streamingFormatWifiPreference = newValue
    }))

    settings.cacheTranscodingFormatPreference = appDelegate.storage.settings.user
      .cacheTranscodingFormatPreference
    changesAgent.append(settings.$cacheTranscodingFormatPreference.sink(receiveValue: { newValue in
      self.appDelegate.storage.settings.user.cacheTranscodingFormatPreference = newValue
    }))

    settings.isPlayerAutoCachePlayedItems = appDelegate.player.isAutoCachePlayedItems
    changesAgent.append(settings.$isPlayerAutoCachePlayedItems.sink(receiveValue: { newValue in
      self.appDelegate.player.isAutoCachePlayedItems = newValue
    }))

    settings.isPlaybackStartOnlyOnPlay = appDelegate.storage.settings.user.isPlaybackStartOnlyOnPlay
    changesAgent.append(settings.$isPlaybackStartOnlyOnPlay.sink(receiveValue: { newValue in
      self.appDelegate.storage.settings.user.isPlaybackStartOnlyOnPlay = newValue
    }))
    settings.isPlayerSongPlaybackResumeEnabled = appDelegate.storage.settings.user
      .isPlayerSongPlaybackResumeEnabled
    changesAgent.append(settings.$isPlayerSongPlaybackResumeEnabled.sink(receiveValue: { newValue in
      self.appDelegate.storage.settings.user.isPlayerSongPlaybackResumeEnabled = newValue
    }))

    settings.swipeActionSettings = appDelegate.storage.settings.user.swipeActionSettings

    settings.isReplayGainEnabled = appDelegate.storage.settings.user.isReplayGainEnabled
    changesAgent.append(settings.$isReplayGainEnabled.sink(receiveValue: { newValue in
      self.appDelegate.storage.settings.user.isReplayGainEnabled = newValue
      self.appDelegate.player.updateReplayGainEnabled(isEnabled: newValue)
    }))

    settings.isEqualizerEnabled = appDelegate.storage.settings.user.isEqualizerEnabled
    changesAgent.append(settings.$isEqualizerEnabled.sink(receiveValue: { newValue in
      self.appDelegate.storage.settings.user.isEqualizerEnabled = newValue
      self.appDelegate.player.updateEqualizerEnabled(isEnabled: newValue)
    }))

    settings.activeEqualizerSetting = appDelegate.storage.settings.user.activeEqualizerSetting
    changesAgent.append(settings.$activeEqualizerSetting.sink(receiveValue: { newValue in
      self.appDelegate.storage.settings.user.activeEqualizerSetting = newValue
      self.appDelegate.player.updateEqualizerSetting(eqSetting: newValue)
    }))

    settings.equalizerSettings = appDelegate.storage.settings.user.equalizerSettings
    changesAgent.append(settings.$equalizerSettings.sink(receiveValue: { newValue in
      self.appDelegate.storage.settings.user.equalizerSettings = newValue
    }))

    changesAgent.append(settings.$swipeActionSettings.sink(receiveValue: { newValue in
      self.appDelegate.storage.settings.user.swipeActionSettings = newValue
    }))

    settings.cacheSizeLimit = appDelegate.storage.settings.user.cacheLimit
    changesAgent.append(settings.$cacheSizeLimit.sink(receiveValue: { newValue in
      self.appDelegate.storage.settings.user.cacheLimit = newValue
    }))

    settings.isHapticsEnabled = appDelegate.storage.settings.user.isHapticsEnabled
    changesAgent.append(settings.$isHapticsEnabled.sink(receiveValue: { newValue in
      self.appDelegate.storage.settings.user.isHapticsEnabled = newValue
    }))

    settings.appearanceMode = appDelegate.storage.settings.user.appearanceMode
    changesAgent.append(settings.$appearanceMode.sink(receiveValue: { newValue in
      self.appDelegate.storage.settings.user.appearanceMode = newValue
      self.appDelegate.setAppAppearanceMode(style: newValue)
    }))

    // following account specific setting sinks are assigned.
    // the correct assignment is done in the account switched callback

    changesAgent.append(settings.$themePreference.sink(receiveValue: { newValue in
      guard let activeAccountInfo = self.settings.activeAccountInfo else { return }
      self.appDelegate.storage.settings.accounts
        .updateSetting(activeAccountInfo) { accountSettings in
          accountSettings.themePreference = newValue
        }
    }))
    changesAgent.append(settings.$isAutoCacheLatestSongs.sink(receiveValue: { newValue in
      guard let activeAccountInfo = self.settings.activeAccountInfo else { return }
      self.appDelegate.storage.settings.accounts
        .updateSetting(activeAccountInfo) { accountSettings in
          accountSettings.isAutoDownloadLatestSongsActive = newValue
        }
    }))
    changesAgent.append(settings.$isAutoCacheLatestPodcastEpisodes.sink(receiveValue: { newValue in
      guard let activeAccountInfo = self.settings.activeAccountInfo else { return }
      self.appDelegate.storage.settings.accounts
        .updateSetting(activeAccountInfo) { accountSettings in
          accountSettings.isAutoDownloadLatestPodcastEpisodesActive = newValue
        }
    }))
    changesAgent.append(settings.$isScrobbleStreamedItems.sink(receiveValue: { newValue in
      guard let activeAccountInfo = self.settings.activeAccountInfo else { return }
      self.appDelegate.storage.settings.accounts
        .updateSetting(activeAccountInfo) { accountSettings in
          accountSettings.isScrobbleStreamedItems = newValue
        }
    }))
  }

  // account is changed via the active account changed callback
  func refreshAccountSettings(accountInfo: AccountInfo?) {
    settings.activeAccountInfo = accountInfo

    settings.themePreference = appDelegate.storage.settings.accounts
      .getSetting(accountInfo).read
      .themePreference

    settings.isAutoCacheLatestSongs = appDelegate.storage.settings.accounts
      .getSetting(accountInfo).read
      .isAutoDownloadLatestSongsActive

    settings.isAutoCacheLatestPodcastEpisodes = appDelegate.storage.settings.accounts
      .getSetting(accountInfo)
      .read
      .isAutoDownloadLatestPodcastEpisodesActive

    settings.isScrobbleStreamedItems = appDelegate.storage.settings.accounts
      .getSetting(accountInfo).read
      .isScrobbleStreamedItems
  }

  @IBSegueAction
  func segueToSwiftUI(_ coder: NSCoder) -> UIViewController? {
    UIHostingController(
      coder: coder,
      rootView:
      SettingsView()
        .environmentObject(settings)
        .environment(\.managedObjectContext, appDelegate.storage.main.context)
    )
  }
}
