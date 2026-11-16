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
import Synchronization

// MARK: - BackgroundSyncRunState

/// Run state of the background library sync, only changed under the syncer's lock.
///
/// Each run owns a generation. stop() ends the current one, and start() after a stop begins a new
/// one, so the old run ends at its next check even if it already passed a check before the stop,
/// and its end can't end the new run.
struct BackgroundSyncRunState: Sendable {
  /// Generation of the run that should go on, nil if none should
  private(set) var current: Int?
  /// start() was called while the current run was going
  private(set) var isStartRequested = false
  private var lastGeneration = 0

  /// Returns the generation of the run to start, nil if the current run goes on
  mutating func start() -> Int? {
    guard current == nil else {
      isStartRequested = true
      return nil
    }
    lastGeneration += 1
    current = lastGeneration
    isStartRequested = false
    return lastGeneration
  }

  mutating func stop() {
    current = nil
    isStartRequested = false
  }

  func isCurrent(_ runGeneration: Int) -> Bool {
    current == runGeneration
  }

  /// Called when a run ends. `isCompleted` is false if it ended early (offline mode, no network).
  /// Returns the generation of a new run to start: a start() during a run that ended early may
  /// have come after the run's last check (e.g. when going online again), it starts a new run.
  mutating func finishRun(_ runGeneration: Int, isCompleted: Bool) -> Int? {
    guard current == runGeneration else { return nil }
    let isRestartNeeded = !isCompleted && isStartRequested
    current = nil
    isStartRequested = false
    return isRestartNeeded ? start() : nil
  }
}

// MARK: - BackgroundLibrarySyncer

public final class BackgroundLibrarySyncer: AbstractBackgroundLibrarySyncer, Sendable {
  private let storage: AsyncCoreDataAccessWrapper
  private let accountObjectId: NSManagedObjectID
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
  private struct LockedState: Sendable {
    var run = BackgroundSyncRunState()
    var task: Task<(), Never>?
  }

  /// Run state and task change together, so two runs never overlap
  private let state = Mutex(LockedState())

  @MainActor
  init(
    storage: AsyncCoreDataAccessWrapper,
    account: Account,
    settings: AmperfySettings,
    networkMonitor: NetworkMonitorFacade,
    librarySyncer: LibrarySyncer,
    playableDownloadManager: DownloadManageable,
    autoDownloadLibrarySyncer: AutoDownloadLibrarySyncer,
    eventLogger: EventLogger
  ) {
    self.storage = storage
    self.accountObjectId = account.managedObject.objectID
    self.settings = settings
    self.networkMonitor = networkMonitor
    self.librarySyncer = librarySyncer
    self.playableDownloadManager = playableDownloadManager
    self.autoDownloadLibrarySyncer = autoDownloadLibrarySyncer
    self.eventLogger = eventLogger
  }

  /// A run is requested. A stopped run may still be finishing its current step.
  var isActive: Bool { state.withLock { $0.run.current != nil } }

  public func start() {
    state.withLock { state in
      guard let runGeneration = state.run.start() else { return }
      startRun(runGeneration, state: &state)
    }
  }

  /// Must be called under the lock. A stopped run may still be finishing: the new run waits for
  /// it, so two runs never overlap.
  private func startRun(_ runGeneration: Int, state: inout LockedState) {
    let previousTask = state.task
    state.task = Task {
      await previousTask?.value
      await self.syncAlbumSongs(runGeneration: runGeneration)
    }
  }

  public func stop() {
    state.withLock { $0.run.stop() }
  }

  /// The run has to end: it was stopped or replaced, the app is in offline mode or there is no
  /// network
  private func shouldStop(_ runGeneration: Int) -> Bool {
    !state.withLock { $0.run.isCurrent(runGeneration) } || !settings.user.isOnlineMode ||
      !networkMonitor.isConnectedToNetwork
  }

  private func syncAlbumSongs(runGeneration: Int) async {
    let isRunEnded = { @Sendable in self.shouldStop(runGeneration) }
    os_log("start", log: self.log, type: .info)

    if !isRunEnded() {
      do {
        try await autoDownloadLibrarySyncer
          .syncNewestLibraryElements(offset: 0, count: AmperKit.newestElementsFetchCount)
      } catch {
        await eventLogger.report(
          topic: "Latest Library Elements Background Sync",
          error: error,
          displayPopup: false
        )
      }
      notifyLibrarySongsSynced()
    }

    if !isRunEnded(), !(await nextUnsyncedAlbumTargets()).isEmpty, !isRunEnded() {
      _ = try? await librarySyncer.syncAllSongs(isCancelled: isRunEnded)
    }

    let isCompleted = await syncUnsyncedAlbums(isRunEnded: isRunEnded)
    // songs may have been synced, also by a run that ended early
    notifyLibrarySongsSynced()
    state.withLock { state in
      guard let nextGeneration = state.run.finishRun(runGeneration, isCompleted: isCompleted)
      else { return }
      self.startRun(nextGeneration, state: &state)
    }
    os_log("stopped", log: self.log, type: .info)
  }

  /// Syncs the songs of the albums without synced songs. Returns false if it ended because the
  /// run has to stop.
  private func syncUnsyncedAlbums(isRunEnded: @escaping @Sendable () -> Bool) async -> Bool {
    // Albums whose songs could not be synced stay unsynced and are tried again in a later run.
    // Within a run, the failed albums of a round that made progress are skipped
    var failedAlbumIDs = Set<NSManagedObjectID>()
    var isRetryAfterNoProgress = false
    while !isRunEnded() {
      let targets = await nextUnsyncedAlbumTargets(excluding: failedAlbumIDs)
      guard !targets.isEmpty else { return true }
      await librarySyncer.syncSongsInBackground(
        targets: targets,
        isCancelled: isRunEnded
      )
      let unsyncedAlbumIDs = await unsyncedAlbumIDs(among: targets)
      if unsyncedAlbumIDs.count < targets.count {
        failedAlbumIDs.formUnion(unsyncedAlbumIDs)
        isRetryAfterNoProgress = false
      } else {
        // Not a single album could be synced (e.g. the server is down): the same albums are
        // tried once more after a pause, so a short outage does not end the run
        guard !isRetryAfterNoProgress else {
          os_log("Album songs sync made no progress", log: self.log, type: .info)
          return true
        }
        isRetryAfterNoProgress = true
        await waitBeforeRetry(until: isRunEnded)
      }
    }
    return false
  }

  @MainActor
  private func nextUnsyncedAlbumTargets(
    excluding excludedAlbumIDs: Set<NSManagedObjectID> = Set()
  ) async
    -> [AlbumSyncTarget] {
    (try? await storage.performAndGet { asyncCompanion in
      asyncCompanion.library
        .getAlbumWithoutSyncedSongs(
          for: asyncCompanion.library.getAccount(managedObjectId: self.accountObjectId),
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

  /// Waits about a minute, in steps that end early when the run has ended
  private func waitBeforeRetry(until isRunEnded: () -> Bool) async {
    for _ in 0 ..< 6 {
      try? await Task.sleep(nanoseconds: 10_000_000_000)
      guard !isRunEnded() else { return }
    }
  }

  private func notifyLibrarySongsSynced() {
    Task { @MainActor in
      NotificationCenter.default.post(name: .librarySongsSynced, object: nil)
    }
  }
}
