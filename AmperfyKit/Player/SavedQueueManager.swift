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

// MARK: - SavedQueueError

public enum SavedQueueError: Error {
  case allSongsUnavailable
  case noActiveAccount
  case noSongsForActiveAccount
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

    // Capture the queue as it plays: with shuffle active the shuffled queue
    // is what the user hears and what currentIndex refers to. The plain
    // context order can't reproduce that and would resume in a different
    // order.
    let contextPlayables = playerData.activeMusicQueue.playables
    let userPlayables = playerData.userQueuePlaylist.playables
    guard !(contextPlayables.isEmpty && userPlayables.isEmpty) else { return }

    let currentIndex = playerData.currentIndex
    let contextName = queueHandler.contextName

    // Match on content. Toggling between two saved queues should refresh the
    // existing rows in place, not produce a new duplicate every round trip.
    if let existing = library.getSavedQueues().first(where: { saved in
      hasSameContent(saved, context: contextPlayables, user: userPlayables)
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

    let saved = library.createSavedQueue()
    saved.name = makeName(contextName: contextName, at: Date())
    saved.contextPlaylist.append(playables: contextPlayables)
    saved.userQueuePlaylist.append(playables: userPlayables)
    saved.currentIndex = currentIndex
    saved.isShuffle = playerData.isShuffle
    saved.repeatMode = playerData.repeatMode
    saved.isUserQueuePlaying = playerData.isUserQueuePlaying
    saved.lastUsedAt = Date()
    library.saveContext()

    enforceLimit()
    postListChanged()
  }

  private func hasSameContent(
    _ saved: SavedQueue,
    context: [AbstractPlayable],
    user: [AbstractPlayable]
  )
    -> Bool {
    saved.contextPlaylist.playables.map { $0.playableManagedObject.objectID }
      == context.map { $0.playableManagedObject.objectID }
      && saved.userQueuePlaylist.playables.map { $0.playableManagedObject.objectID }
      == user.map { $0.playableManagedObject.objectID }
  }

  // MARK: - List

  public func list() -> [SavedQueue] {
    let queues = library.getSavedQueues()
    // Deleted songs cascade out of the playlists; a queue whose songs are all
    // gone has nothing left to restore and is dropped here. Check the actual
    // items (playables.isEmpty), NOT the stored songCount: the logout purge
    // runs as an NSBatchDeleteRequest that bypasses willSave, leaving the
    // playlists' stored songCount stale (see Global Constraints).
    var survivors = [SavedQueue]()
    var didDelete = false
    for queue in queues {
      if queue.playables.isEmpty {
        library.deleteSavedQueue(queue)
        didDelete = true
      } else {
        survivors.append(queue)
      }
    }
    if didDelete { library.saveContext() }
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

  public func deleteEmptySavedQueues() {
    let empty = library.getSavedQueues().filter { $0.playables.isEmpty }
    guard !empty.isEmpty else { return }
    for queue in empty { library.deleteSavedQueue(queue) }
    library.saveContext()
    postListChanged()
  }

  // MARK: - Eviction

  public func enforceLimit() {
    let limit = settings.user.savedQueuesLimit
    let queues = library.getSavedQueues()
    guard queues.count > limit else { return }
    for queue in queues.dropFirst(limit) {
      library.deleteSavedQueue(queue)
    }
    library.saveContext()
  }

  // MARK: - Restore

  @discardableResult
  public func restore(_ savedQueue: SavedQueue) async -> Bool {
    let resolvedContext = savedQueue.contextPlaylist.playables
    let resolvedUser = savedQueue.userQueuePlaylist.playables

    if resolvedContext.isEmpty, resolvedUser.isEmpty {
      eventLogger.report(topic: "Restore Queue", error: SavedQueueError.allSongsUnavailable)
      return false
    }

    // Saved queues are always music queues; switch over before snapshotting
    // so a music queue lingering behind an active podcast session is still
    // captured before being replaced.
    playerData.setPlayerMode(.music)
    snapshotIfNeeded(reason: .restoreOverwrite)

    // Songs deleted from the library cascade out of the saved playlists, so
    // the stored index can point past the end; clamp it. An index of -1 is
    // valid: it marks a user queue item playing before the first context item.
    var adjustedIndex = min(savedQueue.currentIndex, resolvedContext.count - 1)
    adjustedIndex = max(0, adjustedIndex)

    // Clear only the music queues; the podcast queue must survive a restore.
    playerData.clearUserQueue()
    playerData.setUserQueuePlaying(false)
    queueHandler.clearContextQueue()
    // Apply the flags while the queues are empty: setShuffle(true) on a
    // filled queue would generate a fresh random permutation, but the saved
    // context playlist already holds the order that was playing.
    playerData.setShuffle(savedQueue.isShuffle)
    playerData.setRepeatMode(savedQueue.repeatMode)

    queueHandler.appendContextQueue(playables: resolvedContext)
    queueHandler.setContextName(savedQueue.name)
    queueHandler.setCurrentIndex(adjustedIndex)

    if !resolvedUser.isEmpty {
      queueHandler.appendUserQueue(playables: resolvedUser)
      playerData.setUserQueuePlaying(savedQueue.isUserQueuePlaying)
      if savedQueue.isUserQueuePlaying, savedQueue.currentIndex < 0 {
        queueHandler.setCurrentIndex(-1)
      }
    }

    savedQueue.lastUsedAt = Date()
    library.saveContext()
    postListChanged()
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
      throw SavedQueueError.noActiveAccount
    }
    let account = library.getAccount(info: accountInfo)

    // A server playlist belongs to one account; a saved queue may mix songs
    // from several. Keep the active account's songs and tell the user how
    // many were skipped.
    let all = savedQueue.playables
    let ordered = all.filter { $0.account == account }
    guard !ordered.isEmpty else {
      throw SavedQueueError.noSongsForActiveAccount
    }

    let playlist = library.createPlaylist(account: account)
    playlist.name = name
    playlist.append(playables: ordered)
    library.saveContext()

    let skipped = all.count - ordered.count
    if skipped > 0 {
      eventLogger.info(
        topic: "Save as Playlist",
        message: "\(skipped) songs belonging to other accounts were skipped."
      )
    }

    if let syncer = librarySyncer {
      try await syncer.syncUpload(playlistToUpdateName: playlist)
      let songs = ordered.compactMap { $0.asSong }
      if !songs.isEmpty {
        try await syncer.syncUpload(playlistToAddSongs: playlist, songs: songs)
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
