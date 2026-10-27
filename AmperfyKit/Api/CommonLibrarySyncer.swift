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

  static func sync(
    _ album: Album,
    operation: @escaping @MainActor @Sendable () async throws -> ()
  ) async throws {
    let albumObjectID = album.managedObject.objectID
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
}

// MARK: - CommonLibrarySyncer

@MainActor
class CommonLibrarySyncer {
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
}
