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

  func testSnapshot_EmptyQueue_NoRowWritten() {
    manager.snapshotIfNeeded(reason: .contextReplace)
    XCTAssertEqual(library.getSavedQueues(for: account).count, 0)
  }

  func testSnapshot_ContextOnly_RoundTrip() async {
    let songs = appendSongs(count: 3)
    playerData.setCurrentIndex(1)
    queueHandler.setContextName("Album A")
    manager.snapshotIfNeeded(reason: .contextReplace)

    let queues = library.getSavedQueues(for: account)
    XCTAssertEqual(queues.count, 1)
    let saved = queues[0]
    XCTAssertEqual(saved.contextSongIds, songs.map { $0.id })
    XCTAssertEqual(saved.currentIndex, 1)
    XCTAssertEqual(saved.name, "Album A Queue")
  }

  func testRestore_BasicRoundTrip() async {
    let songs = appendSongs(count: 3)
    playerData.setCurrentIndex(1)
    queueHandler.setContextName("Album A")
    manager.snapshotIfNeeded(reason: .contextReplace)

    playerData.removeAllItems()
    XCTAssertEqual(playerData.contextQueue.playables.count, 0)

    let queues = library.getSavedQueues(for: account)
    await manager.restore(queues[0])

    XCTAssertEqual(playerData.contextQueue.playables.count, 3)
    XCTAssertEqual(playerData.currentIndex, 1)
    XCTAssertEqual(playerData.contextQueue.playables[0].id, songs[0].id)
  }

  func testRestore_AllSongsMissing_NoMutation() async {
    let saved = library.createSavedQueue(account: account)
    saved.contextSongIds = ["nonexistent-id-1", "nonexistent-id-2"]
    saved.currentIndex = 0
    library.saveContext()

    _ = appendSongs(count: 2)
    let queueCountBefore = playerData.contextQueue.playables.count
    await manager.restore(saved)
    XCTAssertEqual(playerData.contextQueue.playables.count, queueCountBefore)
  }

  func testDeleteAll_RemovesQueuesForAccountOnly() throws {
    let secondInfo = TestAccountInfo.create2()
    let secondAccount = library.getAccount(info: secondInfo)

    let q1 = library.createSavedQueue(account: account)
    q1.contextSongIds = [cdHelper.seeder.songs[0].id]
    let q2 = library.createSavedQueue(account: secondAccount)
    q2.contextSongIds = [cdHelper.seeder.songs[0].id]
    library.saveContext()

    manager.deleteAll(for: account)

    XCTAssertEqual(library.getSavedQueues(for: account).count, 0)
    XCTAssertEqual(library.getSavedQueues(for: secondAccount).count, 1)
  }

  func testEviction_OverLimit_FIFODeletesOldest() {
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
    for i in 0 ..< 5 {
      let saved = library.createSavedQueue(account: account)
      saved.name = "queue-\(i)"
      saved.contextSongIds = [cdHelper.seeder.songs[0].id]
      saved.managedObject.createdAt = Date(timeIntervalSinceReferenceDate: Double(i))
      library.saveContext()
    }
    manager.enforceLimit(for: account)
    let remaining = library.getSavedQueues(for: account)
    XCTAssertEqual(remaining.count, 3)
    // Most-recent (createdAt = 4) survives, oldest (0, 1) evicted.
    XCTAssertEqual(remaining.map { $0.name }.sorted(), ["queue-2", "queue-3", "queue-4"])
  }
}
