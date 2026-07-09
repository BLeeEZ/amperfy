//
//  SavedQueueManagerTest.swift
//  AmperfyKitTests
//
//  Created by Amperfy Contributors on 08.06.26.
//  Copyright (c) 2026 Maximilian Bauer. All rights reserved.
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

@testable import AmperfyKit
import XCTest

@MainActor
class SavedQueueManagerTest: XCTestCase {
  var cdHelper: CoreDataHelper!
  var library: LibraryStorage!
  var account: Account!
  var playerData: PlayerData!
  var queueHandler: PlayQueueHandler!
  var storage: PersistentStorage!
  var mockCoreDataManager: MOCK_CoreDataManager!
  var eventLogger: EventLogger!
  var manager: SavedQueueManager!

  override func setUp() async throws {
    cdHelper = CoreDataHelper()
    library = cdHelper.createSeededStorage()
    account = library.getAccount(info: TestAccountInfo.create1())
    mockCoreDataManager = MOCK_CoreDataManager(persistentContainer: cdHelper.persistentContainer)
    storage = PersistentStorage(coreDataManager: mockCoreDataManager)
    eventLogger = EventLogger(storage: storage)
    playerData = library.getPlayerData()
    queueHandler = PlayQueueHandler(playerData: playerData)
    storage.settings.accounts.switchActiveAccount(account.info)
    var userSettings = storage.settings.user
    userSettings.savedQueuesLimit = 20
    storage.settings.user = userSettings
    manager = SavedQueueManager(
      library: library,
      queueHandler: queueHandler,
      playerData: playerData,
      settings: storage.settings,
      eventLogger: eventLogger
    )
  }

  override func tearDown() {}

  func appendSongs(count: Int) -> [Song] {
    var result = [Song]()
    for i in 0 ..< count {
      let song = library.getSong(for: account, id: cdHelper.seeder.songs[i].id)!
      playerData.appendContextQueue(playables: [song])
      result.append(song)
    }
    return result
  }

  func testSnapshotCapturesPlayedOrderIntoPlaylists() {
    let songs = appendSongs(count: 3)
    let userSong = library.getSong(for: account, id: cdHelper.seeder.songs[4].id)!
    playerData.appendUserQueue(playables: [userSong])
    playerData.setCurrentIndex(1)
    queueHandler.setContextName("Album A")
    manager.snapshotIfNeeded(reason: .contextReplace)

    let queues = manager.list()
    XCTAssertEqual(queues.count, 1)
    let saved = queues[0]
    XCTAssertEqual(saved.contextPlaylist.playables.map { $0.id }, songs.map { $0.id })
    XCTAssertEqual(saved.userQueuePlaylist.playables.map { $0.id }, [userSong.id])
    XCTAssertEqual(saved.currentIndex, 1)
    XCTAssertEqual(saved.name, "Album A Queue")
  }

  func testSnapshotOfIdenticalQueueUpdatesInPlaceNoDuplicate() {
    _ = appendSongs(count: 3)
    playerData.setCurrentIndex(0)
    manager.snapshotIfNeeded(reason: .contextReplace)
    playerData.setCurrentIndex(2)
    manager.snapshotIfNeeded(reason: .contextReplace)

    let queues = manager.list()
    XCTAssertEqual(queues.count, 1)
    XCTAssertEqual(queues[0].currentIndex, 2)
  }

  func testSnapshotSkipsWhenPlayerEmpty() {
    manager.snapshotIfNeeded(reason: .playerClear)
    XCTAssertTrue(manager.list().isEmpty)
  }

  func testSnapshotWithShuffleCapturesShuffledOrder() {
    let songs = appendSongs(count: 5)
    playerData.setCurrentIndex(0)
    playerData.setShuffle(true)
    // Arrange the shuffled queue deterministically (reverse of the plain
    // order) so the playing order provably differs from the context order.
    let playingOrder: [String] = songs.reversed().map { $0.id }
    let active = playerData.activeQueue
    for (destIndex, id) in playingOrder.enumerated() {
      let curIndex = active.playables.firstIndex { $0.id == id }!
      active.movePlaylistItem(fromIndex: curIndex, to: destIndex)
    }
    playerData.setCurrentIndex(2)
    manager.snapshotIfNeeded(reason: .contextReplace)

    let queues = manager.list()
    XCTAssertEqual(queues.count, 1)
    let saved = queues[0]
    XCTAssertEqual(saved.contextPlaylist.playables.map { $0.id }, playingOrder)
    XCTAssertEqual(saved.currentIndex, 2)
    XCTAssertTrue(saved.isShuffle)
  }

  func testMixedAccountQueueSnapshotsAndListsGlobally() {
    let account2 = library.getAccount(info: TestAccountInfo.create2())
    let song1 = library.getSong(for: account, id: cdHelper.seeder.songs[0].id)!
    let song2 = library.getSong(for: account2, id: "acc2Song")!
    playerData.appendContextQueue(playables: [song1, song2])
    manager.snapshotIfNeeded(reason: .contextReplace)

    let queues = manager.list()
    XCTAssertEqual(queues.count, 1)
    XCTAssertEqual(
      queues[0].contextPlaylist.playables.map { $0.id },
      [song1.id, song2.id]
    )
    XCTAssertEqual(queues[0].songCount, 2)
  }

  func testEnforceLimitEvictsOldestBeyondLimit() {
    var userSettings = storage.settings.user
    userSettings.savedQueuesLimit = 3
    storage.settings.user = userSettings
    // Re-create manager with updated settings so it reads the new limit.
    manager = SavedQueueManager(
      library: library,
      queueHandler: queueHandler,
      playerData: playerData,
      settings: storage.settings,
      eventLogger: eventLogger
    )
    let song = library.getSong(for: account, id: cdHelper.seeder.songs[0].id)!
    for i in 0 ..< 5 {
      let saved = library.createSavedQueue()
      saved.name = "queue-\(i)"
      saved.contextPlaylist.append(playables: [song])
      saved.lastUsedAt = Date(timeIntervalSinceReferenceDate: Double(i))
      library.saveContext()
    }
    manager.enforceLimit()

    let remaining = library.getSavedQueues()
    XCTAssertEqual(remaining.count, 3)
    // Most-recently used (lastUsedAt = 4) survives, least-recently used
    // (0, 1) evicted.
    XCTAssertEqual(remaining.map { $0.name }.sorted(), ["queue-2", "queue-3", "queue-4"])
  }

  func testListDropsQueuesEmptiedBySongDeletion() {
    let song = library.getSong(for: account, id: cdHelper.seeder.songs[0].id)!
    playerData.appendContextQueue(playables: [song])
    manager.snapshotIfNeeded(reason: .contextReplace)
    XCTAssertEqual(manager.list().count, 1)

    // No deleteSong API exists; delete the MO directly (see the plan's
    // Global Constraints).
    cdHelper.persistentContainer.viewContext.delete(song.playableManagedObject)
    library.saveContext()

    XCTAssertTrue(manager.list().isEmpty)
    XCTAssertTrue(library.getSavedQueues().isEmpty)
  }

  func testRestoreAppliesQueuesFlagsAndIndex() async {
    let songs = appendSongs(count: 3)
    let userSong = library.getSong(for: account, id: cdHelper.seeder.songs[4].id)!
    playerData.appendUserQueue(playables: [userSong])
    playerData.setCurrentIndex(1)
    playerData.setRepeatMode(.all)
    manager.snapshotIfNeeded(reason: .contextReplace)
    let saved = manager.list()[0]

    playerData.removeAllItems()
    playerData.setRepeatMode(.off)

    let ok = await manager.restore(saved)
    XCTAssertTrue(ok)
    XCTAssertEqual(playerData.contextQueue.playables.map { $0.id }, songs.map { $0.id })
    XCTAssertEqual(playerData.currentIndex, 1)
    XCTAssertEqual(playerData.repeatMode, .all)
    XCTAssertEqual(playerData.userQueuePlaylist.playables.map { $0.id }, [userSong.id])
    XCTAssertFalse(playerData.isUserQueuePlaying)
  }

  func testRestoreShuffledQueueRestoresPlayingOrderShuffleAndIndex() async {
    let songs = appendSongs(count: 5)
    playerData.setCurrentIndex(0)
    playerData.setShuffle(true)
    // Same deterministic reorder as the snapshot test: playing order is the
    // reverse of the plain context order.
    let playingOrder: [String] = songs.reversed().map { $0.id }
    let active = playerData.activeQueue
    for (destIndex, id) in playingOrder.enumerated() {
      let curIndex = active.playables.firstIndex { $0.id == id }!
      active.movePlaylistItem(fromIndex: curIndex, to: destIndex)
    }
    playerData.setCurrentIndex(2)
    manager.snapshotIfNeeded(reason: .contextReplace)
    let saved = manager.list()[0]

    playerData.setShuffle(false)
    playerData.removeAllItems()

    let ok = await manager.restore(saved)
    XCTAssertTrue(ok)
    XCTAssertTrue(playerData.isShuffle)
    XCTAssertEqual(playerData.activeQueue.playables.map { $0.id }, playingOrder)
    XCTAssertEqual(playerData.currentIndex, 2)
    XCTAssertEqual(playerData.currentItem?.id, playingOrder[2])
  }

  func testRestoreClampsIndexAfterSongDeletion() async {
    let songs = appendSongs(count: 3)
    playerData.setCurrentIndex(2)
    manager.snapshotIfNeeded(reason: .contextReplace)
    let saved = manager.list()[0]

    playerData.removeAllItems()
    // No deleteSong API exists; delete the MO directly (see the plan's
    // Global Constraints). The song cascades out of the saved playlist.
    cdHelper.persistentContainer.viewContext.delete(songs[2].playableManagedObject)
    library.saveContext()

    let ok = await manager.restore(saved)
    XCTAssertTrue(ok)
    XCTAssertEqual(playerData.contextQueue.playables.count, 2)
    XCTAssertEqual(playerData.currentIndex, 1)
  }

  func testRestoreFailsWhenAllSongsGone() async {
    let songs = appendSongs(count: 1)
    manager.snapshotIfNeeded(reason: .contextReplace)
    let saved = library.getSavedQueues()[0]

    playerData.removeAllItems()
    cdHelper.persistentContainer.viewContext.delete(songs[0].playableManagedObject)
    library.saveContext()

    let ok = await manager.restore(saved)
    XCTAssertFalse(ok)
    XCTAssertTrue(playerData.contextQueue.playables.isEmpty)
  }

  func testRestoreOverwriteSnapshotsCurrentQueueFirst() async {
    let songD = library.getSong(for: account, id: cdHelper.seeder.songs[3].id)!
    let songE = library.getSong(for: account, id: cdHelper.seeder.songs[4].id)!
    let target = library.createSavedQueue()
    target.name = "Target"
    target.contextPlaylist.append(playables: [songD, songE].map { $0 as AbstractPlayable })
    library.saveContext()

    _ = appendSongs(count: 3)
    playerData.setCurrentIndex(1)

    let ok = await manager.restore(target)
    XCTAssertTrue(ok)
    // The queue that was playing got snapshotted before being replaced.
    XCTAssertEqual(manager.list().count, 2)
    XCTAssertEqual(
      playerData.contextQueue.playables.map { $0.id },
      [songD.id, songE.id]
    )
  }

  func testRestoreUserQueuePlayingNegativeIndex() async {
    let songs = appendSongs(count: 3)
    let userSong = library.getSong(for: account, id: cdHelper.seeder.songs[4].id)!
    playerData.appendUserQueue(playables: [userSong])
    playerData.setUserQueuePlaying(true)
    playerData.setCurrentIndex(-1)
    manager.snapshotIfNeeded(reason: .contextReplace)
    let saved = manager.list()[0]

    playerData.removeAllItems()

    let ok = await manager.restore(saved)
    XCTAssertTrue(ok)
    XCTAssertTrue(playerData.isUserQueuePlaying)
    XCTAssertEqual(playerData.currentIndex, -1)
    XCTAssertEqual(playerData.currentItem?.id, userSong.id)
    XCTAssertEqual(playerData.contextQueue.playables.map { $0.id }, songs.map { $0.id })
  }

  func testRestoreDoesNotTouchPodcastQueue() async {
    let songs = appendSongs(count: 3)
    manager.snapshotIfNeeded(reason: .contextReplace)
    let saved = manager.list()[0]
    playerData.clearContextQueue()

    playerData.appendPodcastQueue(playables: [songs[0]])
    XCTAssertEqual(playerData.podcastQueue.playables.count, 1)

    let ok = await manager.restore(saved)
    XCTAssertTrue(ok)
    XCTAssertEqual(playerData.playerMode, .music)
    XCTAssertEqual(playerData.contextQueue.playables.count, 3)
    XCTAssertEqual(playerData.podcastQueue.playables.count, 1)
  }

  func testSaveAsPlaylistFiltersToActiveAccount() async throws {
    let account2 = library.getAccount(info: TestAccountInfo.create2())
    let songA = library.getSong(for: account, id: cdHelper.seeder.songs[0].id)!
    let songB = library.getSong(for: account, id: cdHelper.seeder.songs[1].id)!
    let foreignSong = library.getSong(for: account2, id: "acc2Song")!
    let saved = library.createSavedQueue()
    saved.contextPlaylist
      .append(playables: [songA, foreignSong, songB].map { $0 as AbstractPlayable })
    library.saveContext()

    let playlist = try await manager.saveAsPlaylist(saved, name: "Mixed", librarySyncer: nil)
    XCTAssertEqual(playlist.playables.map { $0.id }, [songA.id, songB.id])
    XCTAssertEqual(playlist.account, account)
    XCTAssertEqual(playlist.name, "Mixed")
  }

  func testSaveAsPlaylistThrowsWhenNoSongsForActiveAccount() async {
    let account2 = library.getAccount(info: TestAccountInfo.create2())
    let foreignSong = library.getSong(for: account2, id: "acc2Song")!
    let saved = library.createSavedQueue()
    saved.contextPlaylist.append(playables: [foreignSong].map { $0 as AbstractPlayable })
    library.saveContext()

    do {
      _ = try await manager.saveAsPlaylist(saved, name: "Foreign", librarySyncer: nil)
      XCTFail("saveAsPlaylist should throw when no songs belong to the active account")
    } catch let error as SavedQueueError {
      guard case .noSongsForActiveAccount = error else {
        XCTFail("expected .noSongsForActiveAccount, got \(error)")
        return
      }
    } catch {
      XCTFail("unexpected error: \(error)")
    }
  }

  func testRenameTrimsAndKeepsCurrentNameOnEmptyInput() {
    let song = library.getSong(for: account, id: cdHelper.seeder.songs[0].id)!
    let saved = library.createSavedQueue()
    saved.name = "Old Name"
    saved.contextPlaylist.append(playables: [song])
    library.saveContext()

    manager.rename(saved, to: "  New Name  ")
    XCTAssertEqual(saved.name, "New Name")

    manager.rename(saved, to: "   ")
    XCTAssertEqual(saved.name, "New Name")
  }
}
