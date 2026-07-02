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
      }

      while self.isRunning.wrappedValue, self.settings.user.isOnlineMode,
            self.networkMonitor.isConnectedToNetwork {
        let targets = await self.nextUnsyncedAlbumTargets()
        guard !targets.isEmpty else { break }
        await self.librarySyncer.syncSongsInBackground(targets: targets) {
          !self.isRunning.wrappedValue || !self.settings.user.isOnlineMode
            || !self.networkMonitor.isConnectedToNetwork
        }
      }

      self.isRunning.wrappedValue = false
      self.isCurrentlyActive.wrappedValue = false
      os_log("stopped", log: self.log, type: .info)
    }
  }

  @MainActor
  private func nextUnsyncedAlbumTargets() async -> [AlbumSyncTarget] {
    (try? await storage.performAndGet { asyncCompanion in
      asyncCompanion.library.getAlbumWithoutSyncedSongs(fetchLimit: Self.albumSyncPageSize)
        .map { AlbumSyncTarget(objectID: $0.managedObject.objectID, id: $0.id) }
    }) ?? []
  }
}
