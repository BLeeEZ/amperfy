//
//  AmperfyKit.swift
//  AmperfyKit
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

import AudioStreaming
import Foundation
import MediaPlayer
import os.log

@MainActor
public class AmperKit {
  static let name = "Amperfy"
  static var version: String {
    (Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String) ?? ""
  }

  static var buildNumber: String {
    (Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String) ?? ""
  }

  nonisolated public static let newestElementsFetchCount = 50
  public static let shared = AmperKit()

  public lazy var log = {
    OSLog(subsystem: "Amperfy", category: "AppDelegate")
  }()

  public lazy var networkMonitor: NetworkMonitorFacade = {
    let monitor = NetworkMonitor(notificationHandler: notificationHandler)
    monitor.start()
    return monitor
  }()

  private var metaManager = [AccountInfo: MetaManager]()
  public func getMeta(_ accountInfo: AccountInfo) -> MetaManager {
    if let manager = metaManager[accountInfo] {
      return manager
    } else {
      let account = storage.main.library.getAccount(info: accountInfo)
      let newManager = MetaManager(
        storage: storage,
        account: account,
        networkMonitor: networkMonitor,
        performanceMonitor: threadPerformanceMonitor,
        eventLogger: eventLogger,
        notificationHandler: notificationHandler,
        localNotificationManager: localNotificationManager
      )
      metaManager[accountInfo] = newManager
      return newManager
    }
  }

  public var allActiveMetas: [AccountInfo: MetaManager] {
    metaManager
  }

  public func resetMeta(_ accountInfo: AccountInfo) {
    metaManager[accountInfo] = nil
  }

  public lazy var threadPerformanceMonitor: ThreadPerformanceMonitor = {
    ThreadPerformanceObserver.shared
  }()

  public lazy var coreDataManager = {
    CoreDataPersistentManager()
  }()

  public lazy var storage = {
    PersistentStorage(coreDataManager: coreDataManager)
  }()

  public var settings: AmperfySettings {
    storage.settings
  }

  public var asyncStorage: AsyncCoreDataAccessWrapper {
    storage.async
  }

  @MainActor
  public lazy var account: Account = {
    if let credentials = storage.settings.accounts.activeSettings.read.loginCredentials {
      return storage.main.library.getAccount(info: Account.createInfo(credentials: credentials))
    } else {
      return storage.main.library.getAccount(info: AccountInfo.defaultAccountInfo)
    }
  }()

  @MainActor
  public lazy var eventLogger = {
    EventLogger(storage: storage)
  }()

  public lazy var notificationHandler: EventNotificationHandler = {
    EventNotificationHandler()
  }()

  @MainActor
  public lazy var player: PlayerFacade = {
    createPlayer()
  }()

  @MainActor
  private func createPlayer() -> PlayerFacade {
    let audioSessionHandler = AudioSessionHandler()
    let backendAudioPlayer = BackendAudioPlayer(
      createAudioStreamingPlayerCB: { AudioStreamingPlayer() },
      audioSessionHandler: audioSessionHandler,
      eventLogger: eventLogger,
      backendApi: getMeta(account.info).backendApi,
      networkMonitor: networkMonitor,
      playableDownloader: getMeta(account.info).playableDownloadManager,
      cacheProxy: storage.main.library,
      userStatistics: userStatistics
    )

    backendAudioPlayer.setStreamingMaxBitrates(to: StreamingMaxBitrates(
      wifi: storage.settings.user.streamingMaxBitrateWifiPreference,
      cellular: storage.settings.user.streamingMaxBitrateCellularPreference
    ))
    backendAudioPlayer.setStreamingTranscodings(to: StreamingTranscodings(
      wifi: storage.settings.user.streamingFormatWifiPreference,
      cellular: storage.settings.user.streamingFormatCellularPreference
    ))

    let playerData = storage.main.library.getPlayerData(account: account)
    let queueHandler = PlayQueueHandler(playerData: playerData)
    let curPlayer = AudioPlayer(
      coreData: playerData,
      queueHandler: queueHandler,
      backendAudioPlayer: backendAudioPlayer,
      settings: storage.settings,
      userStatistics: userStatistics
    )
    audioSessionHandler.musicPlayer = curPlayer
    audioSessionHandler.eventLogger = eventLogger
    audioSessionHandler.configureObserverForAudioSessionInterruption()
    backendAudioPlayer.triggerReinsertPlayableCB = curPlayer.play
    backendAudioPlayer.updateEqualizerEnabled(isEnabled: storage.settings.user.isEqualizerEnabled)
    backendAudioPlayer
      .updateEqualizerSetting(eqSetting: storage.settings.user.activeEqualizerSetting)
    backendAudioPlayer.updateReplayGainEnabled(isEnabled: storage.settings.user.isReplayGainEnabled)
    backendAudioPlayer.volume = storage.settings.user.playerVolume

    let playerDownloadPreparationHandler = PlayerDownloadPreparationHandler(
      playerStatus: playerData,
      queueHandler: queueHandler,
      playableDownloadManager: getMeta(account.info).playableDownloadManager
    )
    curPlayer.addNotifier(notifier: playerDownloadPreparationHandler)
    let scrobbleSyncer = getMeta(account.info).createScrobbleSyncer(
      audioPlayer: curPlayer,
      backendAudioPlayer: backendAudioPlayer
    )
    curPlayer.addNotifier(notifier: scrobbleSyncer)

    let facadeImpl = PlayerFacadeImpl(
      playerStatus: playerData,
      queueHandler: queueHandler,
      musicPlayer: curPlayer,
      library: storage.main.library,
      playableDownloadManager: getMeta(account.info).playableDownloadManager,
      backendAudioPlayer: backendAudioPlayer,
      userStatistics: userStatistics
    )
    facadeImpl.isOfflineMode = storage.settings.user.isOfflineMode

    let nowPlayingInfoCenterHandler = getMeta(account.info).createNowPlayingInfoCenterHandler(
      audioPlayer: curPlayer,
      backendAudioPlayer: backendAudioPlayer
    )
    curPlayer.addNotifier(notifier: nowPlayingInfoCenterHandler)
    let remoteCommandCenterHandler = RemoteCommandCenterHandler(
      musicPlayer: facadeImpl,
      backendAudioPlayer: backendAudioPlayer,
      getLibrarySyncerCB: { accountInfo in
        self.getMeta(accountInfo).librarySyncer
      },
      eventLogger: eventLogger,
      remoteCommandCenter: MPRemoteCommandCenter.shared()
    )
    remoteCommandCenterHandler.configureRemoteCommands()
    curPlayer.addNotifier(notifier: remoteCommandCenterHandler)
    let notificationAdapter = PlayerNotificationAdapter(notificationHandler: notificationHandler)
    curPlayer.addNotifier(notifier: notificationAdapter)

    return facadeImpl
  }

  @MainActor
  public lazy var libraryUpdater = {
    LibraryUpdater(storage: storage)
  }()

  public lazy var userStatistics = {
    storage.main.library.getUserStatistics(appVersion: Self.version)
  }()

  @MainActor
  public lazy var localNotificationManager = {
    LocalNotificationManager(userStatistics: userStatistics, storage: storage)
  }()

  @MainActor
  public func reinit() {
    let playerData = storage.main.library.getPlayerData(account: account)
    let queueHandler = PlayQueueHandler(playerData: playerData)
    player.reinit(playerStatus: playerData, queueHandler: queueHandler)
  }
}
