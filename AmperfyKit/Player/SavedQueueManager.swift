//
//  SavedQueueManager.swift
//  AmperfyKit
//
//  Created by Maximilian Bauer on 18.11.21.
//  Copyright (c) 2021 Maximilian Bauer. All rights reserved.
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

// MARK: - SavedQueueSnapshotReason

public enum SavedQueueSnapshotReason {
  case contextReplace
  case restoreOverwrite
  case playerClear
}

// MARK: - SavedQueueRestoreError

public enum SavedQueueRestoreError: Error {
  case allSongsUnavailable
  case noActiveAccount
}

// MARK: - SavedQueueManager

@MainActor
public class SavedQueueManager {
  private let library: LibraryStorage
  private let queueHandler: PlayQueueHandler
  private let playerData: PlayerData
  private let settings: AmperfySettings
  private let eventLogger: EventLogger

  public init(
    library: LibraryStorage,
    queueHandler: PlayQueueHandler,
    playerData: PlayerData,
    settings: AmperfySettings,
    eventLogger: EventLogger
  ) {
    self.library = library
    self.queueHandler = queueHandler
    self.playerData = playerData
    self.settings = settings
    self.eventLogger = eventLogger
  }

  // MARK: - Snapshot

  public func snapshotIfNeeded(reason: SavedQueueSnapshotReason) {
    guard playerData.playerMode == .music else { return }
    guard let accountInfo = settings.accounts.active else { return }
    let account = library.getAccount(info: accountInfo)

    // Capture the queue as it plays: with shuffle active the shuffled queue
    // is what the user hears and what currentIndex refers to. The plain
    // context order can't reproduce that and would resume in a different
    // order.
    let contextIds = playerData.activeMusicQueue.playables.map { $0.id }
    let userIds = playerData.userQueuePlaylist.playables.map { $0.id }
    guard !(contextIds.isEmpty && userIds.isEmpty) else { return }

    let currentIndex = playerData.currentIndex
    let contextName = queueHandler.contextName

    // Match on song-id arrays. Toggling between two saved queues should
    // refresh the existing rows in place, not produce a new duplicate every
    // round trip.
    if let existing = library.getSavedQueues(for: account).first(where: { saved in
      saved.contextSongIds == contextIds && saved.userQueueSongIds == userIds
    }) {
      existing.currentIndex = currentIndex
      existing.isShuffle = playerData.isShuffle
      existing.repeatMode = playerData.repeatMode
      existing.isUserQueuePlaying = playerData.isUserQueuePlaying
      existing.lastUsedAt = Date()
      library.saveContext()
      postListChanged()
      return
    }

    let saved = library.createSavedQueue(account: account)
    saved.name = makeName(contextName: contextName, at: Date())
    saved.contextSongIds = contextIds
    saved.userQueueSongIds = userIds
    saved.currentIndex = currentIndex
    saved.isShuffle = playerData.isShuffle
    saved.repeatMode = playerData.repeatMode
    saved.isUserQueuePlaying = playerData.isUserQueuePlaying
    saved.songCount = contextIds.count + userIds.count
    library.saveContext()

    enforceLimit(for: account)
    postListChanged()
  }

  // MARK: - List

  public func list(forAccount account: Account) -> [SavedQueue] {
    let queues = library.getSavedQueues(for: account)
    var survivors = [SavedQueue]()
    for queue in queues {
      let allIds = Set(queue.contextSongIds + queue.userQueueSongIds)
      if library.isAnySongAvailable(for: account, ids: allIds) {
        survivors.append(queue)
      } else {
        library.deleteSavedQueue(queue)
      }
    }
    if survivors.count != queues.count { library.saveContext() }
    return survivors
  }

  // MARK: - Rename

  public func rename(_ savedQueue: SavedQueue, to name: String) {
    let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return }
    savedQueue.name = trimmed
    library.saveContext()
    postListChanged()
  }

  // MARK: - Delete

  public func delete(_ savedQueue: SavedQueue) {
    library.deleteSavedQueue(savedQueue)
    library.saveContext()
    postListChanged()
  }

  public func deleteAll(for account: Account) {
    library.deleteAllSavedQueues(for: account)
    library.saveContext()
    postListChanged()
  }

  // MARK: - Eviction

  public func enforceLimit(for account: Account) {
    let limit = settings.user.savedQueuesLimit
    let queues = library.getSavedQueues(for: account)
    guard queues.count > limit else { return }
    let toDrop = queues.dropFirst(limit)
    for queue in toDrop {
      library.deleteSavedQueue(queue)
    }
    library.saveContext()
  }

  // MARK: - Restore

  @discardableResult
  public func restore(_ savedQueue: SavedQueue) async -> Bool {
    guard let accountInfo = settings.accounts.active else {
      eventLogger.report(
        topic: "Restore Queue",
        error: SavedQueueRestoreError.noActiveAccount
      )
      return false
    }
    let account = library.getAccount(info: accountInfo)

    let contextIds = savedQueue.contextSongIds
    let userIds = savedQueue.userQueueSongIds
    let allIds = Set(contextIds + userIds)
    let resolvedSongs = library.getSongs(for: account, ids: allIds)
    let songById = Dictionary(
      uniqueKeysWithValues: resolvedSongs.map { ($0.id, $0) }
    )
    let resolvedContext = contextIds.compactMap { songById[$0] }
    let resolvedUser = userIds.compactMap { songById[$0] }

    if resolvedContext.isEmpty, resolvedUser.isEmpty {
      eventLogger.report(
        topic: "Restore Queue",
        error: SavedQueueRestoreError.allSongsUnavailable
      )
      return false
    }

    // Saved queues are always music queues; switch over before snapshotting
    // so a music queue lingering behind an active podcast session is still
    // captured before being replaced.
    playerData.setPlayerMode(.music)
    snapshotIfNeeded(reason: .restoreOverwrite)

    // Adjust currentIndex by counting surviving items up to the saved index.
    // An index of -1 is valid: it marks a user queue item playing before the
    // first context item.
    let savedIndex = savedQueue.currentIndex
    var adjustedIndex = 0
    for i in 0 ..< min(max(0, savedIndex), contextIds.count) {
      if songById[contextIds[i]] != nil { adjustedIndex += 1 }
    }
    if adjustedIndex >= resolvedContext.count {
      adjustedIndex = max(0, resolvedContext.count - 1)
    }

    // Clear only the music queues; the podcast queue must survive a restore.
    playerData.clearUserQueue()
    playerData.setUserQueuePlaying(false)
    queueHandler.clearContextQueue()
    // Apply the flags while the queues are empty: setShuffle(true) on a
    // filled queue would generate a fresh random permutation, but
    // contextSongIds already hold the order that was playing.
    playerData.setShuffle(savedQueue.isShuffle)
    playerData.setRepeatMode(savedQueue.repeatMode)

    queueHandler.appendContextQueue(playables: resolvedContext.map { $0 as AbstractPlayable })
    queueHandler.setContextName(savedQueue.name)
    queueHandler.setCurrentIndex(adjustedIndex)

    if !resolvedUser.isEmpty {
      queueHandler.appendUserQueue(playables: resolvedUser.map { $0 as AbstractPlayable })
      playerData.setUserQueuePlaying(savedQueue.isUserQueuePlaying)
      if savedQueue.isUserQueuePlaying, savedIndex < 0 {
        queueHandler.setCurrentIndex(-1)
      }
    }

    savedQueue.lastUsedAt = Date()
    library.saveContext()
    postListChanged()

    let totalSaved = contextIds.count + userIds.count
    let totalResolved = resolvedContext.count + resolvedUser.count
    let dropped = totalSaved - totalResolved
    if dropped > 0 {
      eventLogger.info(
        topic: "Restore Queue",
        message: "Restored \(totalResolved) of \(totalSaved) songs (\(dropped) no longer available)."
      )
    }
    return true
  }

  // MARK: - Save as Playlist

  public func saveAsPlaylist(
    _ savedQueue: SavedQueue,
    name: String,
    librarySyncer: LibrarySyncer?
  ) async throws
    -> Playlist {
    guard let accountInfo = settings.accounts.active else {
      throw SavedQueueRestoreError.allSongsUnavailable
    }
    let account = library.getAccount(info: accountInfo)

    let allIds = Set(savedQueue.contextSongIds + savedQueue.userQueueSongIds)
    let resolvedSongs = library.getSongs(for: account, ids: allIds)
    let byId = Dictionary(uniqueKeysWithValues: resolvedSongs.map { ($0.id, $0) })
    let ordered = (savedQueue.contextSongIds + savedQueue.userQueueSongIds)
      .compactMap { byId[$0] }

    let playlist = library.createPlaylist(account: account)
    playlist.name = name
    playlist.append(playables: ordered.map { $0 as AbstractPlayable })
    library.saveContext()

    if let syncer = librarySyncer {
      try await syncer.syncUpload(playlistToUpdateName: playlist)
      if !ordered.isEmpty {
        try await syncer.syncUpload(playlistToAddSongs: playlist, songs: ordered)
      }
    }
    return playlist
  }

  // MARK: - Naming

  private func makeName(contextName: String, at date: Date) -> String {
    if !contextName.isEmpty {
      return "\(contextName) Queue"
    }
    let formatted = DateFormatter.localizedString(
      from: date,
      dateStyle: .medium,
      timeStyle: .short
    )
    return "Queue from \(formatted)"
  }

  // MARK: - Helpers

  private func postListChanged() {
    NotificationCenter.default.post(
      name: .savedQueueListChanged,
      object: nil
    )
  }
}

extension Notification.Name {
  public static let savedQueueListChanged = Notification.Name("savedQueueListChanged")
}
