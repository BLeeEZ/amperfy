//
//  CommonLibrarySyncer.swift
//  AmperfyKit
//
//  Created by Maximilian Bauer on 15.05.24.
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

import CoreData
import Foundation
import os.log

// MARK: - AlbumSyncCoalescer

/// Coalesces concurrent syncs of the same album. Each album sync opens its own
/// background context and cannot see another sync's unsaved inserts, so two
/// overlapping syncs of one album would both insert every song and the library
/// would appear duplicated (upstream issue #778). A caller that finds a sync of
/// the album in flight awaits it instead of starting a second one.
@MainActor
enum AlbumSyncCoalescer {
  /// Album syncs in flight, keyed by the album's local object ID: unsynced
  /// albums share the empty server id, so the server id cannot be the key.
  /// Static because the proxy creates a new syncer for every call.
  private static var runningSyncs = [NSManagedObjectID: Task<(), Error>]()
  /// Albums claimed by a batched sync. Other batches skip them; a single album
  /// sync waits for the batch and then syncs the album itself, so its caller
  /// still gets that album's own result.
  private static var batchSyncs = [NSManagedObjectID: Task<(), Never>]()
  /// A write that may touch songs of any album, such as a bulk song page. While
  /// it is pending or running, every album sync waits for it.
  private static var exclusiveSync: Task<(), Never>?

  static func sync(
    _ album: Album,
    operation: @escaping @MainActor @Sendable () async throws -> ()
  ) async throws {
    let albumObjectID = album.managedObject.objectID
    while let pendingSync = exclusiveSync ?? batchSyncs[albumObjectID] {
      await pendingSync.value
    }
    if let runningSync = runningSyncs[albumObjectID] {
      return try await runningSync.value
    }
    // The task owns its entry and removes it only once the whole sync,
    // including its Core Data write, has finished. A cancelled caller does not
    // cancel it, because other callers may be awaiting the same sync. The task
    // only starts once this caller suspends below, so the entry is always
    // stored before the task's defer removes it.
    let syncTask = Task { @MainActor in
      defer { Self.runningSyncs[albumObjectID] = nil }
      try await operation()
    }
    runningSyncs[albumObjectID] = syncTask
    try await syncTask.value
  }

  /// Batched variant: one operation syncs several albums at once. Albums with a
  /// sync in flight elsewhere are awaited instead of synced again, so the
  /// operation only receives the albums it claimed.
  static func sync(
    albumObjectIDs: [NSManagedObjectID],
    operation: @escaping @MainActor @Sendable ([NSManagedObjectID]) async -> ()
  ) async {
    while let pendingSync = exclusiveSync {
      await pendingSync.value
    }
    let albumSyncsElsewhere = albumObjectIDs.compactMap { runningSyncs[$0] }
    let batchSyncsElsewhere = albumObjectIDs.compactMap { batchSyncs[$0] }
    let claimedObjectIDs = albumObjectIDs.filter {
      runningSyncs[$0] == nil && batchSyncs[$0] == nil
    }
    if !claimedObjectIDs.isEmpty {
      let syncTask = Task { @MainActor in
        defer { claimedObjectIDs.forEach { Self.batchSyncs[$0] = nil } }
        await operation(claimedObjectIDs)
      }
      claimedObjectIDs.forEach { batchSyncs[$0] = syncTask }
      await syncTask.value
    }
    for albumSync in albumSyncsElsewhere {
      _ = try? await albumSync.value
    }
    for batchSync in batchSyncsElsewhere {
      await batchSync.value
    }
  }

  /// Exclusive variant for a write that may touch songs of any album: it waits
  /// until no album sync is in flight, and album syncs started meanwhile wait
  /// until it has finished.
  static func syncExclusively<Result: Sendable>(
    operation: @escaping @MainActor @Sendable () async throws -> Result
  ) async throws
    -> Result {
    while let pendingSync = exclusiveSync {
      await pendingSync.value
    }
    let syncTask = Task { @MainActor in
      defer { Self.exclusiveSync = nil }
      while let albumSync = runningSyncs.values.first {
        _ = try? await albumSync.value
      }
      while let batchSync = batchSyncs.values.first {
        await batchSync.value
      }
      return try await operation()
    }
    exclusiveSync = Task { @MainActor in _ = try? await syncTask.value }
    return try await syncTask.value
  }
}

// MARK: - CommonLibrarySyncer

@MainActor
class CommonLibrarySyncer {
  static let maxParallelSyncRequests: Int = 4
  static let songSyncBatchSize: Int = 16

  let account: Account
  let accountObjectId: NSManagedObjectID
  let networkMonitor: NetworkMonitorFacade
  let performanceMonitor: ThreadPerformanceMonitor
  let storage: PersistentStorage
  let eventLogger: EventLogger
  let log = OSLog(subsystem: "Amperfy", category: "LibrarySyncer")
  let fileManager = CacheFileManager.shared

  var isSyncAllowed: Bool { networkMonitor.isConnectedToNetwork }

  var accountInfo: AccountInfo {
    account.info
  }

  init(
    account: Account,
    networkMonitor: NetworkMonitorFacade,
    performanceMonitor: ThreadPerformanceMonitor,
    storage: PersistentStorage,
    eventLogger: EventLogger
  ) {
    self.account = account
    self.accountObjectId = account.managedObject.objectID
    self.networkMonitor = networkMonitor
    self.performanceMonitor = performanceMonitor
    self.storage = storage
    self.eventLogger = eventLogger
  }

  func createCachedItemRepresentationsInCoreData(statusNotifyier: SyncCallbacks?) async throws {
    let accountInfo = account.info
    try await storage.async.perform { asyncCompanion in
      let cachedArtworks = self.fileManager.getCachedArtworks(for: accountInfo)
      let cachedEmbeddedArtworks = self.fileManager.getCachedEmbeddedArtworks(for: accountInfo)
      let cachedLyrics = self.fileManager.getCachedLyrics(for: accountInfo)
      let cachedSongs = self.fileManager.getCachedSongs(for: accountInfo)
      let cachedEpisodes = self.fileManager.getCachedEpisodes(for: accountInfo)

      let accountAsync = asyncCompanion.library.getAccount(managedObjectId: self.accountObjectId)
      let totalCount = cachedArtworks.count + cachedEmbeddedArtworks.count + cachedLyrics
        .count + cachedSongs.count + cachedEpisodes.count
      guard totalCount > 0 else {
        // nothing to do
        return
      }
      statusNotifyier?.notifySyncStarted(ofType: .cache, totalCount: totalCount)
      for cachedArtwork in cachedArtworks {
        let artwork = asyncCompanion.library.getArtwork(
          for: accountAsync,
          remoteInfo: ArtworkRemoteInfo(
            id: cachedArtwork.id,
            type: cachedArtwork.type
          )
        ) ?? asyncCompanion.library.createArtwork(account: accountAsync)
        artwork.id = cachedArtwork.id
        artwork.type = cachedArtwork.type
        artwork.relFilePath = cachedArtwork.relFilePath
        artwork.status = .CustomImage
        statusNotifyier?.notifyParsedObject(ofType: .cache)
      }
      for cachedSong in cachedSongs {
        let song = asyncCompanion.library.createSong(account: accountAsync)
        song.id = cachedSong.id
        song.relFilePath = cachedSong.relFilePath
        song.contentTypeTranscoded = cachedSong.mimeType
        statusNotifyier?.notifyParsedObject(ofType: .cache)
      }
      for cachedEpisode in cachedEpisodes {
        let episode = asyncCompanion.library.createPodcastEpisode(account: accountAsync)
        episode.id = cachedEpisode.id
        episode.relFilePath = cachedEpisode.relFilePath
        episode.contentTypeTranscoded = cachedEpisode.mimeType
        statusNotifyier?.notifyParsedObject(ofType: .cache)
      }
      // match embedded artworks after songs/episods so that owner are already created
      for cachedEmbeddedArtwork in cachedEmbeddedArtworks {
        if cachedEmbeddedArtwork.isSong,
           let song = asyncCompanion.library.getSong(
             for: accountAsync,
             id: cachedEmbeddedArtwork.id
           ) {
          let embeddedArtwork = asyncCompanion.library.createEmbeddedArtwork(account: accountAsync)
          embeddedArtwork.relFilePath = cachedEmbeddedArtwork.relFilePath
          embeddedArtwork.owner = song
        } else if !cachedEmbeddedArtwork.isSong,
                  let episode = asyncCompanion.library
                  .getPodcastEpisode(for: accountAsync, id: cachedEmbeddedArtwork.id) {
          let embeddedArtwork = asyncCompanion.library.createEmbeddedArtwork(account: accountAsync)
          embeddedArtwork.relFilePath = cachedEmbeddedArtwork.relFilePath
          embeddedArtwork.owner = episode
        }
        statusNotifyier?.notifyParsedObject(ofType: .cache)
      }
      // match lyrics after songs/episods so that owner are already created
      for cachedLyric in cachedLyrics {
        if cachedLyric.isSong {
          var song = asyncCompanion.library.getSong(for: accountAsync, id: cachedLyric.id)
          if song == nil {
            song = asyncCompanion.library.createSong(account: accountAsync)
            song?.id = cachedLyric.id
          }
          song?.lyricsRelFilePath = cachedLyric.relFilePath
        } else if !cachedLyric.isSong,
                  let _ = asyncCompanion.library.getPodcastEpisode(
                    for: accountAsync,
                    id: cachedLyric.id
                  ) {
          // not supported
        }
        statusNotifyier?.notifyParsedObject(ofType: .cache)
      }
    }
  }

  @MainActor
  func waitWhileThermalStateCritical(
    previousWaitCount: Int,
    isCancelled: @escaping @Sendable () -> Bool
  ) async
    -> (isCancelled: Bool, waitCount: Int) {
    var waitCount = previousWaitCount
    guard ProcessInfo.processInfo.thermalState == .critical, waitCount < 6 else {
      return (false, waitCount)
    }
    os_log("Album songs sync paused: critical thermal state", log: log, type: .info)
    while ProcessInfo.processInfo.thermalState == .critical, waitCount < 6 {
      waitCount += 1
      try? await Task.sleep(nanoseconds: 10_000_000_000)
      guard !isCancelled() else { return (true, waitCount) }
    }
    return (false, waitCount)
  }

  @MainActor
  func syncAlbumSongsBatched<Payload: Sendable>(
    targets: [AlbumSyncTarget],
    batchSize: Int,
    maxParallelFetches: Int,
    isCancelled: @escaping @Sendable () -> Bool,
    fetch: @escaping @MainActor @Sendable (String) async throws -> Payload,
    write: @escaping @Sendable (CoreDataCompanion, NSManagedObjectID, Payload) throws -> (),
    classifyNotAvailable: @escaping @Sendable (Error) -> Bool
  ) async {
    var index = 0
    var lastParallelFetches = maxParallelFetches
    var criticalThermalWaits = 0
    while index < targets.count {
      guard !isCancelled() else { return }
      let thermalWait = await waitWhileThermalStateCritical(
        previousWaitCount: criticalThermalWaits,
        isCancelled: isCancelled
      )
      criticalThermalWaits = thermalWait.waitCount
      guard !thermalWait.isCancelled else { return }
      let thermalState = ProcessInfo.processInfo.thermalState
      let isLowPower = ProcessInfo.processInfo.isLowPowerModeEnabled
      let isThermalThrottled = thermalState == .serious || thermalState == .critical
      let parallelFetches = isLowPower || thermalState == .critical
        ? 1 : (isThermalThrottled ? 2 : maxParallelFetches)
      if parallelFetches != lastParallelFetches {
        os_log(
          "Album songs sync parallel fetches: %i (thermal throttled: %s, low power: %s)",
          log: log,
          type: .info,
          parallelFetches,
          isThermalThrottled ? "yes" : "no",
          isLowPower ? "yes" : "no"
        )
        lastParallelFetches = parallelFetches
      }
      let batch = Array(targets[index ..< min(index + batchSize, targets.count)])
      index += batchSize

      await AlbumSyncCoalescer.sync(albumObjectIDs: batch.map(\.objectID)) { claimedObjectIDs in
        let claimedTargets = batch.filter { claimedObjectIDs.contains($0.objectID) }
        var results = [(NSManagedObjectID, AlbumSongsFetchResult<Payload>)]()
        var iterator = claimedTargets.makeIterator()
        await withTaskGroup(of: (NSManagedObjectID, AlbumSongsFetchResult<Payload>).self) { group in
          for _ in 0 ..< parallelFetches {
            guard let target = iterator.next() else { break }
            group.addTask { @MainActor @Sendable in
              do {
                return (target.objectID, .fetched(try await fetch(target.id)))
              } catch {
                self.eventLogger.report(
                  topic: "Album Background Sync",
                  error: error,
                  displayPopup: false
                )
                return (target.objectID, classifyNotAvailable(error) ? .notAvailable : .failed)
              }
            }
          }
          while let result = await group.next() {
            results.append(result)
            guard let target = iterator.next() else { continue }
            group.addTask { @MainActor @Sendable in
              do {
                return (target.objectID, .fetched(try await fetch(target.id)))
              } catch {
                self.eventLogger.report(
                  topic: "Album Background Sync",
                  error: error,
                  displayPopup: false
                )
                return (target.objectID, classifyNotAvailable(error) ? .notAvailable : .failed)
              }
            }
          }
        }

        let batchResults = results
        guard !isCancelled() else { return }
        try? await self.storage.async.perform { asyncCompanion in
          for (objectID, result) in batchResults {
            guard let albumMO = try? asyncCompanion.context
              .existingObject(with: objectID) as? AlbumMO
            else { continue }
            let albumAsync = Album(managedObject: albumMO)
            switch result {
            case let .fetched(payload):
              do {
                try write(asyncCompanion, objectID, payload)
              } catch {
                if classifyNotAvailable(error) {
                  albumAsync.markAsRemoteDeleted()
                } else {
                  albumAsync.isSongsMetaDataSynced = true
                }
              }
            case .notAvailable:
              albumAsync.markAsRemoteDeleted()
            case .failed:
              albumAsync.isSongsMetaDataSynced = true
            }
          }
        }
      }
    }
  }
}

// MARK: - AlbumSongsFetchResult

enum AlbumSongsFetchResult<Payload: Sendable>: Sendable {
  case fetched(Payload)
  case notAvailable
  case failed
}
