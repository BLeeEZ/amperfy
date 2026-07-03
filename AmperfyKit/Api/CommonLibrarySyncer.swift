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
      if ProcessInfo.processInfo.thermalState == .critical, criticalThermalWaits < 6 {
        os_log("Album songs sync paused: critical thermal state", log: log, type: .info)
        while ProcessInfo.processInfo.thermalState == .critical, criticalThermalWaits < 6 {
          criticalThermalWaits += 1
          try? await Task.sleep(nanoseconds: 10_000_000_000)
          guard !isCancelled() else { return }
        }
      }
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

      var results = [(NSManagedObjectID, AlbumSongsFetchResult<Payload>)]()
      var iterator = batch.makeIterator()
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
      try? await storage.async.perform { asyncCompanion in
        for (objectID, result) in batchResults {
          guard let albumMO = try? asyncCompanion.context.existingObject(with: objectID) as? AlbumMO
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

// MARK: - AlbumSongsFetchResult

enum AlbumSongsFetchResult<Payload: Sendable>: Sendable {
  case fetched(Payload)
  case notAvailable
  case failed
}
