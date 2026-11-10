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

import CoreData
import Foundation
import os.log

// MARK: - BackgroundLibrarySyncer

public final class BackgroundLibrarySyncer: AbstractBackgroundLibrarySyncer, Sendable {
  private let storage: AsyncCoreDataAccessWrapper
  private let settings: AmperfySettings
  private let networkMonitor: NetworkMonitorFacade
  private let librarySyncer: LibrarySyncer
  @MainActor
  private let playableDownloadManager: DownloadManageable
  @MainActor
  private let autoDownloadLibrarySyncer: AutoDownloadLibrarySyncer
  private let eventLogger: EventLogger

  private static let albumSyncPageSize: Int = 500

  private let log = OSLog(subsystem: "Amperfy", category: "BackgroundLibrarySyncer")
  private let isRunning = Atomic<Bool>(wrappedValue: false)
  private let isCurrentlyActive = Atomic<Bool>(wrappedValue: false)
  private let backgroundTask = Atomic<Task<(), Never>?>(wrappedValue: nil)

  @MainActor
  init(
    storage: AsyncCoreDataAccessWrapper,
    settings: AmperfySettings,
    networkMonitor: NetworkMonitorFacade,
    librarySyncer: LibrarySyncer,
    playableDownloadManager: DownloadManageable,
    autoDownloadLibrarySyncer: AutoDownloadLibrarySyncer,
    eventLogger: EventLogger
  ) {
    self.storage = storage
    self.settings = settings
    self.networkMonitor = networkMonitor
    self.librarySyncer = librarySyncer
    self.playableDownloadManager = playableDownloadManager
    self.autoDownloadLibrarySyncer = autoDownloadLibrarySyncer
    self.eventLogger = eventLogger
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
        notifyLibrarySongsSynced()
      }

      let hasAlbumsToSync = !(await self.nextUnsyncedAlbumTargets()).isEmpty
      if hasAlbumsToSync, self.isRunning.wrappedValue, self.settings.user.isOnlineMode,
         self.networkMonitor.isConnectedToNetwork {
        _ = try? await self.librarySyncer.syncAllSongs {
          !self.isRunning.wrappedValue || !self.settings.user.isOnlineMode
            || !self.networkMonitor.isConnectedToNetwork
        }
      }

      // Albums whose songs could not be synced stay unsynced and are tried again in a later run.
      // Within a run, the failed albums of a round that made progress are skipped
      var failedAlbumIDs = Set<NSManagedObjectID>()
      var isRetryAfterNoProgress = false
      while self.isRunning.wrappedValue, self.settings.user.isOnlineMode,
            self.networkMonitor.isConnectedToNetwork {
        let targets = await self.nextUnsyncedAlbumTargets(excluding: failedAlbumIDs)
        guard !targets.isEmpty else { break }
        await self.librarySyncer.syncSongsInBackground(targets: targets) {
          !self.isRunning.wrappedValue || !self.settings.user.isOnlineMode
            || !self.networkMonitor.isConnectedToNetwork
        }
        let unsyncedAlbumIDs = await self.unsyncedAlbumIDs(among: targets)
        if unsyncedAlbumIDs.count < targets.count {
          failedAlbumIDs.formUnion(unsyncedAlbumIDs)
          isRetryAfterNoProgress = false
        } else {
          // Not a single album could be synced (e.g. the server is down): the same albums are
          // tried once more after a pause, so a short outage does not end the run
          guard !isRetryAfterNoProgress else {
            os_log("Album songs sync made no progress", log: self.log, type: .info)
            break
          }
          isRetryAfterNoProgress = true
          await self.waitBeforeRetry()
        }
      }

      // stop() resets isRunning before the loop ends: only a natural end notifies
      if self.isRunning.wrappedValue {
        self.notifyLibrarySongsSynced()
      }
      self.isRunning.wrappedValue = false
      self.isCurrentlyActive.wrappedValue = false
      os_log("stopped", log: self.log, type: .info)
    }
  }

  @MainActor
  private func nextUnsyncedAlbumTargets(
    excluding excludedAlbumIDs: Set<NSManagedObjectID> = Set()
  ) async
    -> [AlbumSyncTarget] {
    (try? await storage.performAndGet { asyncCompanion in
      asyncCompanion.library
        .getAlbumWithoutSyncedSongs(
          fetchLimit: Self.albumSyncPageSize,
          excluding: excludedAlbumIDs
        )
        .map { AlbumSyncTarget(objectID: $0.managedObject.objectID, id: $0.id) }
    }) ?? []
  }

  @MainActor
  private func unsyncedAlbumIDs(among targets: [AlbumSyncTarget]) async -> Set<NSManagedObjectID> {
    let targetIDs = targets.map(\.objectID)
    // A failed check counts as a round without progress
    return (try? await storage.performAndGet { asyncCompanion in
      try asyncCompanion.library.getAlbumObjectIDsWithoutSyncedSongs(among: targetIDs)
    }) ?? Set(targetIDs)
  }

  /// Waits about a minute, in steps that end early when the sync has to stop
  private func waitBeforeRetry() async {
    for _ in 0 ..< 6 {
      try? await Task.sleep(nanoseconds: 10_000_000_000)
      guard isRunning.wrappedValue, settings.user.isOnlineMode,
            networkMonitor.isConnectedToNetwork
      else { return }
    }
  }

  private func notifyLibrarySongsSynced() {
    Task { @MainActor in
      NotificationCenter.default.post(name: .librarySongsSynced, object: nil)
    }
  }
}
