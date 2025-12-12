//
//  BackgroundLibrarySyncer.swift
//  AmperfyKit
//
//  Created by Maximilian Bauer on 12.04.22.
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

import Foundation
import os.log

// MARK: - BackgroundSyncOperation

public class BackgroundSyncOperation: AsyncOperation, @unchecked Sendable {
  private let completeBlock: VoidAsyncClosure

  public init(completeBlock: @escaping VoidAsyncClosure) {
    self.completeBlock = completeBlock
  }

  override public func main() {
    Task {
      await self.completeBlock()
      finish()
    }
  }
}

// MARK: - BackgroundLibrarySyncer

public final class BackgroundLibrarySyncer: AbstractBackgroundLibrarySyncer, Sendable {
  private let storage: AsyncCoreDataAccessWrapper
  @MainActor
  private let mainStorage: CoreDataCompanion
  private let settings: AmperfySettings
  private let networkMonitor: NetworkMonitorFacade
  private let librarySyncer: LibrarySyncer
  @MainActor
  private let playableDownloadManager: DownloadManageable
  @MainActor
  private let autoDownloadLibrarySyncer: AutoDownloadLibrarySyncer
  private let eventLogger: EventLogger

  private let log = OSLog(subsystem: "Amperfy", category: "BackgroundLibrarySyncer")
  private let isRunning = Atomic<Bool>(wrappedValue: false)
  private let isCurrentlyActive = Atomic<Bool>(wrappedValue: false)
  private let backgroundTask = Atomic<Task<(), Never>?>(wrappedValue: nil)
  private let taskQueue: OperationQueue

  @MainActor
  init(
    storage: AsyncCoreDataAccessWrapper,
    mainStorage: CoreDataCompanion,
    settings: AmperfySettings,
    networkMonitor: NetworkMonitorFacade,
    librarySyncer: LibrarySyncer,
    playableDownloadManager: DownloadManageable,
    autoDownloadLibrarySyncer: AutoDownloadLibrarySyncer,
    eventLogger: EventLogger
  ) {
    self.storage = storage
    self.mainStorage = mainStorage
    self.settings = settings
    self.networkMonitor = networkMonitor
    self.librarySyncer = librarySyncer
    self.playableDownloadManager = playableDownloadManager
    self.autoDownloadLibrarySyncer = autoDownloadLibrarySyncer
    self.eventLogger = eventLogger
    self.taskQueue = OperationQueue()
    taskQueue.maxConcurrentOperationCount = 1
  }

  var isActive: Bool { isCurrentlyActive.wrappedValue }

  public func start() {
    isRunning.wrappedValue = true
    if !isCurrentlyActive.wrappedValue {
      isCurrentlyActive.wrappedValue = true
      syncAlbumSongsInBackground()
    }
  }

  public func stop() {
    isRunning.wrappedValue = false
    taskQueue.cancelAllOperations()
    addOperationsEndMessage()
  }

  private func syncAlbumSongsInBackground() {
    backgroundTask.wrappedValue = Task {
      os_log("start", log: self.log, type: .info)

      if self.isRunning.wrappedValue, self.settings.user.isOnlineMode,
         self.networkMonitor.isConnectedToNetwork {
        do {
          try await autoDownloadLibrarySyncer
            .syncNewestLibraryElements(offset: 0, count: AmperKit.newestElementsFetchCount)
        } catch {
          await self.eventLogger.report(
            topic: "Latest Library Elements Background Sync",
            error: error,
            displayPopup: false
          )
        }
      }

      try? await storage.perform { asyncCompanion in
        let albumsToSync = asyncCompanion.library.getAlbumWithoutSyncedSongs()

        for albumToSync in albumsToSync {
          let albumObjectID = albumToSync.managedObject.objectID
          let asyncOperation = BackgroundSyncOperation {
            guard !Task.isCancelled, self.isRunning.wrappedValue, self.settings.user.isOnlineMode,
                  self.networkMonitor.isConnectedToNetwork else { return }
            let albumMO = self.mainStorage.context.object(with: albumObjectID) as! AlbumMO
            let album = Album(managedObject: albumMO)
            do {
              try await self.librarySyncer.sync(album: album)
            } catch {
              self.eventLogger.report(
                topic: "Album Background Sync",
                error: error,
                displayPopup: false
              )
              album.isSongsMetaDataSynced = true
            }
          }
          self.taskQueue.addOperation(asyncOperation)
        }
      }

      addOperationsEndMessage()
    }
  }

  func addOperationsEndMessage() {
    taskQueue.addBarrierBlock {
      self.isRunning.wrappedValue = false
      os_log("stopped", log: self.log, type: .info)
    }
  }
}
