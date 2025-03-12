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

  public lazy var threadPerformanceMonitor: ThreadPerformanceMonitor = {
    ThreadPerformanceObserver.shared
  }()

  public lazy var coreDataManager = {
    CoreDataPersistentManager()
  }()

  public lazy var storage = {
    PersistentStorage(coreDataManager: coreDataManager)
  }()

  public var settings: PersistentStorage.Settings {
    storage.settings
  }

  public var asyncStorage: AsyncCoreDataAccessWrapper {
    storage.async
  }

  @MainActor
  public lazy var librarySyncer: LibrarySyncer = {
    LibrarySyncerProxy(backendApi: backendApi, storage: storage)
  }()

  @MainActor
  public lazy var duplicateEntitiesResolver = {
    DuplicateEntitiesResolver(storage: storage)
  }()

  @MainActor
  public lazy var eventLogger = {
    EventLogger(storage: storage)
  }()

  public lazy var backendApi: BackendProxy = {
    let api = BackendProxy(
      networkMonitor: networkMonitor,
      performanceMonitor: threadPerformanceMonitor,
      eventLogger: eventLogger,
      settings: storage.settings
    )
    api.initialize()
    return api
  }()

  public lazy var notificationHandler: EventNotificationHandler = {
    EventNotificationHandler()
  }()

  public private(set) var scrobbleSyncer: ScrobbleSyncer?
  @MainActor
  public lazy var player: PlayerFacade = {
    createPlayer()
  }()

  @MainActor
  private func createPlayer() -> PlayerFacade {
    let audioSessionHandler = AudioSessionHandler()
    let backendAudioPlayer = BackendAudioPlayer(
      createAVPlayerCB: { AVQueuePlayer() },
      audioSessionHandler: audioSessionHandler,
      eventLogger: eventLogger,
      backendApi: backendApi,
      networkMonitor: networkMonitor,
      playableDownloader: playableDownloadManager,
      cacheProxy: storage.main.library,
      userStatistics: userStatistics
    )
    networkMonitor.connectionTypeChangedCB = { isWiFiConnected in
      Task { @MainActor in
        backendAudioPlayer.setStreamingMaxBitrates(to: StreamingMaxBitrates(
          wifi: self.storage.settings.streamingMaxBitrateWifiPreference,
          cellular: self.storage.settings.streamingMaxBitrateCellularPreference
        ))
      }
    }
    let playerData = storage.main.library.getPlayerData()
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
    backendAudioPlayer.volume = storage.settings.playerVolume

    let playerDownloadPreparationHandler = PlayerDownloadPreparationHandler(
      playerStatus: playerData,
      queueHandler: queueHandler,
      playableDownloadManager: playableDownloadManager
    )
    curPlayer.addNotifier(notifier: playerDownloadPreparationHandler)
    scrobbleSyncer = ScrobbleSyncer(
      musicPlayer: curPlayer,
      backendAudioPlayer: backendAudioPlayer,
      networkMonitor: networkMonitor,
      storage: storage,
      librarySyncer: librarySyncer,
      eventLogger: eventLogger
    )
    curPlayer.addNotifier(notifier: scrobbleSyncer!)

    let facadeImpl = PlayerFacadeImpl(
      playerStatus: playerData,
      queueHandler: queueHandler,
      musicPlayer: curPlayer,
      library: storage.main.library,
      playableDownloadManager: playableDownloadManager,
      backendAudioPlayer: backendAudioPlayer,
      userStatistics: userStatistics
    )
    facadeImpl.isOfflineMode = storage.settings.isOfflineMode

    let nowPlayingInfoCenterHandler = NowPlayingInfoCenterHandler(
      musicPlayer: curPlayer,
      backendAudioPlayer: backendAudioPlayer,
      nowPlayingInfoCenter: MPNowPlayingInfoCenter.default(),
      storage: storage
    )
    curPlayer.addNotifier(notifier: nowPlayingInfoCenterHandler)
    let remoteCommandCenterHandler = RemoteCommandCenterHandler(
      musicPlayer: facadeImpl,
      backendAudioPlayer: backendAudioPlayer,
      librarySyncer: librarySyncer,
      eventLogger: eventLogger,
      remoteCommandCenter: MPRemoteCommandCenter.shared()
    )
    remoteCommandCenterHandler.configureRemoteCommands()
    curPlayer.addNotifier(notifier: remoteCommandCenterHandler)
    let notificationAdapter = PlayerNotificationAdapter(notificationHandler: notificationHandler)
    curPlayer.addNotifier(notifier: notificationAdapter)

    return facadeImpl
  }

  public lazy var playableDownloadManager: DownloadManageable = {
    let artworkExtractor = EmbeddedArtworkExtractor()
    let dlDelegate = PlayableDownloadDelegate(
      backendApi: backendApi,
      artworkExtractor: artworkExtractor,
      networkMonitor: networkMonitor
    )
    let requestManager = DownloadRequestManager(
      storage: storage.async,
      downloadDelegate: dlDelegate
    )
    let dlManager = DownloadManager(
      name: "PlayableDownloader",
      storage: storage.async,
      requestManager: requestManager,
      downloadDelegate: dlDelegate,
      eventLogger: eventLogger,
      settings: storage.settings,
      networkMonitor: networkMonitor,
      notificationHandler: notificationHandler,
      urlCleanser: backendApi,
      limitCacheSize: true,
      isFailWithPopupError: true
    )

    let configuration = URLSessionConfiguration
      .background(withIdentifier: "\(Bundle.main.bundleIdentifier!).PlayableDownloader.background")
    let urlSession = URLSession(
      configuration: configuration,
      delegate: dlManager,
      delegateQueue: nil
    )
    dlManager.initialize(
      urlSession: urlSession,
      validationCB: nil
    )

    return dlManager
  }()

  public lazy var artworkDownloadManager: DownloadManageable = {
    createArtworkDownloadManager()
  }()

  private func createArtworkDownloadManager() -> DownloadManageable {
    let dlDelegate = backendApi.createArtworkArtworkDownloadDelegate()
    let requestManager = DownloadRequestManager(
      storage: storage.async,
      downloadDelegate: dlDelegate
    )
    requestManager.clearAllDownloadsAsyncIfAllHaveFinished()
    let dlManager = DownloadManager(
      name: "ArtworkDownloader",
      storage: storage.async,
      requestManager: requestManager,
      downloadDelegate: dlDelegate,
      eventLogger: eventLogger,
      settings: storage.settings,
      networkMonitor: networkMonitor,
      notificationHandler: notificationHandler,
      urlCleanser: backendApi,
      limitCacheSize: false,
      isFailWithPopupError: false
    )

    let validationCB: PreDownloadIsValidCB =
      { (downloadInfos: [DownloadElementInfo]) -> [DownloadElementInfo] in
        let artworkDownloadInfos = downloadInfos.filter { $0.type == .artwork }

        let artworkDownloadSetting = await self.settings.artworkDownloadSetting
        guard artworkDownloadSetting != .never else { return [DownloadElementInfo]() }
        guard artworkDownloadSetting != .updateOncePerSession else { return artworkDownloadInfos }

        let dlInfos = try? await self.asyncStorage.performAndGet { asyncCompanion in
          var validDls = [DownloadElementInfo]()
          for dlInfo in artworkDownloadInfos {
            guard dlInfo.type == .artwork else { continue }
            let artwork = Artwork(
              managedObject: asyncCompanion.context
                .object(with: dlInfo.objectId) as! ArtworkMO
            )

            switch artworkDownloadSetting {
            case .onlyOnce:
              switch artwork.status {
              case .FetchError, .NotChecked:
                validDls.append(dlInfo)
              case .CustomImage, .IsDefaultImage:
                continue
              }
            case .never, .updateOncePerSession:
              continue // already handled above
            }
          }
          return validDls
        }
        return dlInfos ?? [DownloadElementInfo]()
      }

    let configuration = URLSessionConfiguration.default
    let urlSession = URLSession(
      configuration: configuration,
      delegate: dlManager,
      delegateQueue: nil
    )
    dlManager.initialize(
      urlSession: urlSession,
      validationCB: validationCB
    )

    return dlManager
  }

  @MainActor
  public lazy var backgroundLibrarySyncer = {
    let autoSyncer = AutoDownloadLibrarySyncer(
      storage: self.storage,
      librarySyncer: self.librarySyncer,
      playableDownloadManager: self.playableDownloadManager
    )
    return BackgroundLibrarySyncer(
      storage: storage.async,
      mainStorage: storage.main,
      settings: storage.settings,
      networkMonitor: networkMonitor,
      librarySyncer: librarySyncer,
      playableDownloadManager: playableDownloadManager, autoDownloadLibrarySyncer: autoSyncer,
      eventLogger: eventLogger
    )
  }()

  @MainActor
  public lazy var libraryUpdater = {
    LibraryUpdater(storage: storage, backendApi: backendApi)
  }()

  public lazy var userStatistics = {
    storage.main.library.getUserStatistics(appVersion: Self.version)
  }()

  @MainActor
  public lazy var localNotificationManager = {
    LocalNotificationManager(userStatistics: userStatistics, storage: storage)
  }()

  @MainActor
  public lazy var backgroundFetchTriggeredSyncer = {
    BackgroundFetchTriggeredSyncer(
      storage: storage,
      librarySyncer: librarySyncer,
      notificationManager: localNotificationManager,
      playableDownloadManager: playableDownloadManager
    )
  }()

  @MainActor
  public func reinit() {
    let playerData = storage.main.library.getPlayerData()
    let queueHandler = PlayQueueHandler(playerData: playerData)
    player.reinit(playerStatus: playerData, queueHandler: queueHandler)
  }
}
