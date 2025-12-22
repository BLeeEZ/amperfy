//
//  MetaManager.swift
//  AmperfyKit
//
//  Created by Maximilian Bauer on 14.12.25.
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

import AudioStreaming
import Foundation
import MediaPlayer
import os.log

public typealias GetLibrarySyncerCallback = (AccountInfo) -> LibrarySyncer
public typealias GetPlayableDownloadManagerCallback = (AccountInfo) -> DownloadManageable
public typealias GetArtworkDownloadManagerCallback = (AccountInfo) -> DownloadManageable
public typealias GetBackendApiCallback = (AccountInfo) -> BackendApi
public typealias GetActiveAccountCallback = () -> Account?

// MARK: - MetaManager

@MainActor
public class MetaManager {
  private let storage: PersistentStorage
  private let networkMonitor: NetworkMonitorFacade
  private let performanceMonitor: ThreadPerformanceMonitor
  private let eventLogger: EventLogger
  private let notificationHandler: EventNotificationHandler
  private let localNotificationManager: LocalNotificationManager

  public let account: Account

  private var settings: AmperfySettings {
    storage.settings
  }

  private var asyncStorage: AsyncCoreDataAccessWrapper {
    storage.async
  }

  private lazy var log = {
    OSLog(subsystem: "Amperfy", category: "MetaManager")
  }()

  public lazy var backendApi: BackendProxy = {
    // create backend API
    let api = BackendProxy(
      networkMonitor: networkMonitor,
      performanceMonitor: performanceMonitor,
      eventLogger: eventLogger,
      settings: storage.settings
    )
    api.initialize()
    api.selectedApi = account.apiType
    if let credentials = settings.accounts.getSetting(account.info).read.loginCredentials {
      api.provideCredentials(credentials: credentials)
    } else {
      os_log("Initializing API without credentials", log: log, type: .info)
    }
    return api
  }()

  public lazy var librarySyncer: LibrarySyncer = {
    LibrarySyncerProxy(backendApi: backendApi, account: account, storage: storage)
  }()

  public lazy var duplicateEntitiesResolver: DuplicateEntitiesResolver = {
    DuplicateEntitiesResolver(account: account, storage: storage)
  }()

  public lazy var playableDownloadDelegate: DownloadManagerDelegate = {
    let artworkExtractor = EmbeddedArtworkExtractor()
    let delegate = PlayableDownloadDelegate(
      backendApi: backendApi,
      artworkExtractor: artworkExtractor,
      networkMonitor: networkMonitor
    )
    return delegate
  }()

  init(
    storage: PersistentStorage,
    account: Account,
    networkMonitor: NetworkMonitorFacade,
    performanceMonitor: ThreadPerformanceMonitor,
    eventLogger: EventLogger,
    notificationHandler: EventNotificationHandler,
    localNotificationManager: LocalNotificationManager
  ) {
    self.storage = storage
    self.account = account
    self.networkMonitor = networkMonitor
    self.performanceMonitor = performanceMonitor
    self.eventLogger = eventLogger
    self.notificationHandler = notificationHandler
    self.localNotificationManager = localNotificationManager
  }

  private var scrobbleSyncer: ScrobbleSyncer?
  internal func createScrobbleSyncer(
    player: PlayerFacade
  )
    -> ScrobbleSyncer {
    if let scrobbleSyncer { return scrobbleSyncer }
    scrobbleSyncer = ScrobbleSyncer(
      player: player,
      networkMonitor: networkMonitor,
      account: account,
      storage: storage,
      librarySyncer: librarySyncer,
      eventLogger: eventLogger
    )
    return scrobbleSyncer!
  }

  public lazy var playableDownloadManager: DownloadManageable = {
    let getDownloadDelegateCB = { @MainActor in
      return self.playableDownloadDelegate
    }
    let requestManager = DownloadRequestManager(
      accountObjectId: account.managedObject.objectID,
      storage: storage.async,
      getDownloadDelegateCB: getDownloadDelegateCB
    )
    let dlManager = DownloadManager(
      name: "PlayableDownloader",
      storage: storage.async,
      requestManager: requestManager,
      getDownloadDelegateCB: getDownloadDelegateCB,
      eventLogger: eventLogger,
      settings: storage.settings,
      networkMonitor: networkMonitor,
      notificationHandler: notificationHandler,
      urlCleanser: backendApi,
      limitCacheSize: true,
      isFailWithPopupError: true
    )

    let configuration = URLSessionConfiguration
      .background(
        withIdentifier: "\(Bundle.main.bundleIdentifier!).\(account.ident).PlayableDownloader.background"
      )
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
    let getDownloadDelegateCB = { @MainActor in
      return self.backendApi.getActiveArtworkDownloadDelegate()
    }
    let requestManager = DownloadRequestManager(
      accountObjectId: account.managedObject.objectID,
      storage: storage.async,
      getDownloadDelegateCB: getDownloadDelegateCB
    )
    requestManager.clearAllDownloadsAsyncIfAllHaveFinished()
    let dlManager = DownloadManager(
      name: "ArtworkDownloader",
      storage: storage.async,
      requestManager: requestManager,
      getDownloadDelegateCB: getDownloadDelegateCB,
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

        guard let accountInfo = await self.settings.accounts.active
        else { return [DownloadElementInfo]() }
        let artworkDownloadSetting = await self.settings.accounts.getSetting(accountInfo).read
          .artworkDownloadSetting
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
      account: self.account,
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
  public lazy var backgroundFetchTriggeredSyncer = {
    BackgroundFetchTriggeredSyncer(
      storage: storage,
      account: account,
      librarySyncer: librarySyncer,
      notificationManager: localNotificationManager,
      playableDownloadManager: playableDownloadManager
    )
  }()

  public func startManagerAfterSync(player: PlayerFacade) {
    os_log("Start background manager after sync", log: self.log, type: .info)
    playableDownloadManager.start()
    artworkDownloadManager.start()
    backgroundLibrarySyncer.start()
    let scrobbler = createScrobbleSyncer(player: player)
    player.addNotifier(notifier: scrobbler)
  }

  public func startManagerForNormalOperation(player: PlayerFacade) {
    os_log("Start background manager for normal operation", log: self.log, type: .info)
    duplicateEntitiesResolver.start()
    artworkDownloadManager.start()
    playableDownloadManager.start()
    backgroundLibrarySyncer.start()
    let scrobbler = createScrobbleSyncer(player: player)
    player.addNotifier(notifier: scrobbler)
    scrobbler.start()
  }

  public func stopManager() {
    os_log("Start meta managers", log: self.log, type: .info)
    scrobbleSyncer?.stop()
    scrobbleSyncer = nil
    backgroundLibrarySyncer.stop()
    artworkDownloadManager.stop()
    playableDownloadManager.stop()
  }
}
