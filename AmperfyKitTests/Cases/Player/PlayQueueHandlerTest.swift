//
//  PlayQueueHandlerTest.swift
//  AmperfyKitTests
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

@testable import AmperfyKit
import XCTest

@MainActor
class PlayQueueHandlerTest: XCTestCase {
  var cdHelper: CoreDataHelper!
  var library: LibraryStorage!
  var account: Account!
  var testQueueHandler: PlayQueueHandler!
  var testPlayer: PlayerData!
  var testNormalPlaylist: Playlist!
  var testShuffledPlaylist: Playlist!
  let fillCount = 5

  override func setUp() async throws {
    cdHelper = CoreDataHelper()
    library = cdHelper.createSeededStorage()
    account = library.getAccount(info: TestAccountInfo.create1())
    testPlayer = library.getPlayerData()
    testPlayer.setShuffle(true)
    testShuffledPlaylist = testPlayer.contextQueue
    testPlayer.setShuffle(false)
    testNormalPlaylist = testPlayer.contextQueue
    testQueueHandler = PlayQueueHandler(playerData: testPlayer)
  }

  override func tearDown() {}

  func prepareNoWaitingQueuePlaying() {
    testPlayer.removeAllItems()
    fillPlayerWithSomeSongsAndWaitingQueue()
    testPlayer.setUserQueuePlaying(false)
  }

  func prepareWithWaitingQueuePlaying() {
    prepareNoWaitingQueuePlaying()
    testPlayer.setUserQueuePlaying(true)
  }

  func fillPlayerWithSomeSongs() {
    for i in 0 ... fillCount - 1 {
      guard let song = library.getSong(for: account, id: cdHelper.seeder.songs[i].id)
      else { XCTFail(); return }
      testPlayer.appendContextQueue(playables: [song])
    }
  }

  func fillPlayerWithSomeSongsAndWaitingQueue() {
    fillPlayerWithSomeSongs()
    for i in 0 ... 3 {
      guard let song = library.getSong(for: account, id: cdHelper.seeder.songs[fillCount + i].id)
      else { XCTFail(); return }
      testPlayer.appendUserQueue(playables: [song])
    }
  }

  func checkCorrectDefaultPlaylist() {
    for i in 0 ... fillCount - 1 {
      checkPlaylistIndexEqualSeedIndex(playlistIndex: i, seedIndex: i)
    }
  }

  func checkPlaylistIndexEqualSeedIndex(playlistIndex: Int, seedIndex: Int) {
    guard let song = library.getSong(for: account, id: cdHelper.seeder.songs[seedIndex].id)
    else { XCTFail(); return }
    XCTAssertEqual(testPlayer.contextQueue.playables[playlistIndex].id, song.id)
  }

  func checkQueueItems(queue: [AbstractPlayable], seedIds: [Int]) {
    XCTAssertEqual(queue.count, seedIds.count)
    if queue.count == seedIds.count, !queue.isEmpty {
      for i in 0 ... queue.count - 1 {
        guard let song = library.getSong(for: account, id: cdHelper.seeder.songs[seedIds[i]].id)
        else { XCTFail(); return }
        let queueId = queue[i].id
        let songId = song.id
        XCTAssertEqual(queueId, songId)
      }
    }
  }

  func checkCurrentlyPlaying(idToBe: Int?) {
    if let idToBe = idToBe {
      guard let song = library.getSong(for: account, id: cdHelper.seeder.songs[idToBe].id)
      else { XCTFail(); return }
      XCTAssertEqual(testQueueHandler.currentlyPlaying?.id, song.id)
    } else {
      XCTAssertNil(testQueueHandler.currentlyPlaying)
    }
  }

  func checkQueueInfoConsistency() {
    /// -------------------
    /// Prev Queue
    /// -------------------
    let prevQueueCount = testQueueHandler.prevQueueCount
    let prevQueueItemsAll = testQueueHandler.getAllPrevQueueItems()
    XCTAssertEqual(prevQueueCount, prevQueueItemsAll.count)
    for (index, item) in prevQueueItemsAll.enumerated() {
      let atItem = testQueueHandler.getPrevQueueItem(at: index)
      XCTAssertEqual(atItem, item)
    }
    var prevRangItemsAll = testQueueHandler.getPrevQueueItems(from: 0, to: nil)
    XCTAssertEqual(prevRangItemsAll, prevQueueItemsAll)

    if prevQueueCount > 0 {
      prevRangItemsAll = testQueueHandler.getPrevQueueItems(from: 0, to: prevQueueCount - 1)
      XCTAssertEqual(prevRangItemsAll, prevQueueItemsAll)
    }
    if prevQueueCount > 1 {
      let prevRangeItemsBeforeEnd1 = testQueueHandler.getPrevQueueItems(
        from: 0,
        to: prevQueueCount - 2
      )
      XCTAssertEqual(prevRangeItemsBeforeEnd1.count, prevQueueCount - 1)
      XCTAssertEqual(prevRangeItemsBeforeEnd1, Array(prevQueueItemsAll[0 ... prevQueueCount - 2]))
      let prevRangeItemsOff1 = testQueueHandler.getPrevQueueItems(from: 1, to: prevQueueCount - 1)
      XCTAssertEqual(prevRangeItemsOff1.count, prevQueueCount - 1)
      XCTAssertEqual(prevRangeItemsOff1, Array(prevQueueItemsAll[1 ... prevQueueCount - 1]))
      XCTAssertEqual(prevRangeItemsOff1[0], prevQueueItemsAll[1])
    }
    if prevQueueCount > 2 {
      let prevRangeItemsMissingStartAndEnd = testQueueHandler.getPrevQueueItems(
        from: 1,
        to: prevQueueCount - 2
      )
      XCTAssertEqual(prevRangeItemsMissingStartAndEnd.count, prevQueueCount - 2)
      XCTAssertEqual(
        prevRangeItemsMissingStartAndEnd,
        Array(prevQueueItemsAll[1 ... prevQueueCount - 2])
      )
      XCTAssertEqual(prevRangeItemsMissingStartAndEnd[0], prevQueueItemsAll[1])
      XCTAssertEqual(prevRangeItemsMissingStartAndEnd.last!, prevQueueItemsAll[prevQueueCount - 2])
    }
    /// -------------------
    /// User Queue
    /// -------------------
    let userQueueCount = testQueueHandler.userQueueCount
    let userQueueItemsAll = testQueueHandler.getAllUserQueueItems()
    XCTAssertEqual(userQueueCount, userQueueItemsAll.count)
    for (index, item) in userQueueItemsAll.enumerated() {
      let atItem = testQueueHandler.getUserQueueItem(at: index)
      XCTAssertEqual(atItem, item)
    }
    var userRangItemsAll = testQueueHandler.getUserQueueItems(from: 0, to: nil)
    XCTAssertEqual(userRangItemsAll, userQueueItemsAll)

    if userQueueCount > 0 {
      userRangItemsAll = testQueueHandler.getUserQueueItems(from: 0, to: userQueueCount - 1)
      XCTAssertEqual(userRangItemsAll, userQueueItemsAll)
    }
    if userQueueCount > 1 {
      let userRangeItemsBeforeEnd1 = testQueueHandler.getUserQueueItems(
        from: 0,
        to: userQueueCount - 2
      )
      XCTAssertEqual(userRangeItemsBeforeEnd1.count, userQueueCount - 1)
      XCTAssertEqual(userRangeItemsBeforeEnd1, Array(userQueueItemsAll[0 ... userQueueCount - 2]))
      let userRangeItemsOff1 = testQueueHandler.getUserQueueItems(from: 1, to: userQueueCount - 1)
      XCTAssertEqual(userRangeItemsOff1.count, userQueueCount - 1)
      XCTAssertEqual(userRangeItemsOff1, Array(userQueueItemsAll[1 ... userQueueCount - 1]))
      XCTAssertEqual(userRangeItemsOff1[0], userQueueItemsAll[1])
    }
    if userQueueCount > 2 {
      let userRangeItemsMissingStartAndEnd = testQueueHandler.getUserQueueItems(
        from: 1,
        to: userQueueCount - 2
      )
      XCTAssertEqual(userRangeItemsMissingStartAndEnd.count, userQueueCount - 2)
      XCTAssertEqual(
        userRangeItemsMissingStartAndEnd,
        Array(userQueueItemsAll[1 ... userQueueCount - 2])
      )
      XCTAssertEqual(userRangeItemsMissingStartAndEnd[0], userQueueItemsAll[1])
      XCTAssertEqual(userRangeItemsMissingStartAndEnd.last!, userQueueItemsAll[userQueueCount - 2])
    }
    /// -------------------
    /// Next Queue
    /// -------------------
    let nextQueueCount = testQueueHandler.nextQueueCount
    let nextQueueItemsAll = testQueueHandler.getAllNextQueueItems()
    XCTAssertEqual(nextQueueCount, nextQueueItemsAll.count)
    for (index, item) in nextQueueItemsAll.enumerated() {
      let atItem = testQueueHandler.getNextQueueItem(at: index)
      XCTAssertEqual(atItem, item)
    }
    var nextRangItemsAll = testQueueHandler.getNextQueueItems(from: 0, to: nil)
    XCTAssertEqual(nextRangItemsAll, nextQueueItemsAll)

    if nextQueueCount > 0 {
      nextRangItemsAll = testQueueHandler.getNextQueueItems(from: 0, to: nextQueueCount - 1)
      XCTAssertEqual(nextRangItemsAll, nextQueueItemsAll)
    }
    if nextQueueCount > 1 {
      let nextRangeItemsBeforeEnd1 = testQueueHandler.getNextQueueItems(
        from: 0,
        to: nextQueueCount - 2
      )
      XCTAssertEqual(nextRangeItemsBeforeEnd1.count, nextQueueCount - 1)
      XCTAssertEqual(nextRangeItemsBeforeEnd1, Array(nextQueueItemsAll[0 ... nextQueueCount - 2]))
      let nextRangeItemsOff1 = testQueueHandler.getNextQueueItems(from: 1, to: nextQueueCount - 1)
      XCTAssertEqual(nextRangeItemsOff1.count, nextQueueCount - 1)
      XCTAssertEqual(nextRangeItemsOff1, Array(nextQueueItemsAll[1 ... nextQueueCount - 1]))
      XCTAssertEqual(nextRangeItemsOff1[0], nextQueueItemsAll[1])
    }
    if nextQueueCount > 2 {
      let nextRangeItemsMissingStartAndEnd = testQueueHandler.getNextQueueItems(
        from: 1,
        to: nextQueueCount - 2
      )
      XCTAssertEqual(nextRangeItemsMissingStartAndEnd.count, nextQueueCount - 2)
      XCTAssertEqual(
        nextRangeItemsMissingStartAndEnd,
        Array(nextQueueItemsAll[1 ... nextQueueCount - 2])
      )
      XCTAssertEqual(nextRangeItemsMissingStartAndEnd[0], nextQueueItemsAll[1])
      XCTAssertEqual(nextRangeItemsMissingStartAndEnd.last!, nextQueueItemsAll[nextQueueCount - 2])
    }
  }

  var song9: AbstractPlayable { library.getSong(for: account, id: cdHelper.seeder.songs[9].id)! }
  var songA: AbstractPlayable { library.getSong(for: account, id: cdHelper.seeder.songs[10].id)! }
  var songB: AbstractPlayable { library.getSong(for: account, id: cdHelper.seeder.songs[11].id)! }
  var songC: AbstractPlayable { library.getSong(for: account, id: cdHelper.seeder.songs[12].id)! }
  var songD: AbstractPlayable { library.getSong(for: account, id: cdHelper.seeder.songs[13].id)! }
  var songE: AbstractPlayable { library.getSong(for: account, id: cdHelper.seeder.songs[14].id)! }
  var songF: AbstractPlayable { library.getSong(for: account, id: cdHelper.seeder.songs[15].id)! }

  func testCreation() {
    XCTAssertEqual(testQueueHandler.prevQueueCount, 0)
    XCTAssertEqual(testQueueHandler.getAllPrevQueueItems(), [AbstractPlayable]())
    XCTAssertEqual(testQueueHandler.getPrevQueueItems(from: 0, to: nil), [AbstractPlayable]())
    XCTAssertEqual(testQueueHandler.getPrevQueueItem(at: 0), nil)
    XCTAssertEqual(testQueueHandler.nextQueueCount, 0)
    XCTAssertEqual(testQueueHandler.getAllNextQueueItems(), [AbstractPlayable]())
    XCTAssertEqual(testQueueHandler.getNextQueueItems(from: 0, to: nil), [AbstractPlayable]())
    XCTAssertEqual(testQueueHandler.getNextQueueItem(at: 0), nil)
    XCTAssertEqual(testQueueHandler.userQueueCount, 0)
    XCTAssertEqual(testQueueHandler.getAllUserQueueItems(), [AbstractPlayable]())
    XCTAssertEqual(testQueueHandler.getUserQueueItems(from: 0, to: nil), [AbstractPlayable]())
    XCTAssertEqual(testQueueHandler.getUserQueueItem(at: 0), nil)
    XCTAssertEqual(testQueueHandler.currentlyPlaying, nil)
  }

  func testAddToWaitingQueueToEmptyPlayerStartsPlaying() {
    guard let song = library.getSong(for: account, id: cdHelper.seeder.songs[5].id)
    else { XCTFail(); return }
    testQueueHandler.insertUserQueue(playables: [song])
    checkCurrentlyPlaying(idToBe: 5)
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [Int]())
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [Int]())
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [Int]())
  }

  func testRemoveSongFromPlaylist() {
    prepareNoWaitingQueuePlaying()
    testPlayer.setCurrentIndex(1)
    testQueueHandler.removePlayable(at: PlayerIndex(queueType: .next, index: 0))
    XCTAssertEqual(testPlayer.contextQueue.playables.count, fillCount - 1)
    XCTAssertEqual(testPlayer.currentIndex, 1)
    checkPlaylistIndexEqualSeedIndex(playlistIndex: 1, seedIndex: 1)
    checkPlaylistIndexEqualSeedIndex(playlistIndex: 2, seedIndex: 3)
    checkPlaylistIndexEqualSeedIndex(playlistIndex: 3, seedIndex: 4)

    testPlayer.setCurrentIndex(3)
    testQueueHandler.removePlayable(at: PlayerIndex(queueType: .prev, index: 0))
    XCTAssertEqual(testPlayer.contextQueue.playables.count, fillCount - 2)
    XCTAssertEqual(testPlayer.currentIndex, 2)
    checkPlaylistIndexEqualSeedIndex(playlistIndex: 0, seedIndex: 1)
    checkPlaylistIndexEqualSeedIndex(playlistIndex: 1, seedIndex: 3)
    checkPlaylistIndexEqualSeedIndex(playlistIndex: 2, seedIndex: 4)

    testPlayer.setCurrentIndex(2)
    testQueueHandler.removePlayable(at: PlayerIndex(queueType: .prev, index: 1))
    XCTAssertEqual(testPlayer.contextQueue.playables.count, fillCount - 3)
    XCTAssertEqual(testPlayer.currentIndex, 1)
    checkPlaylistIndexEqualSeedIndex(playlistIndex: 0, seedIndex: 1)
    checkPlaylistIndexEqualSeedIndex(playlistIndex: 1, seedIndex: 4)

    testPlayer.removeAllItems()
    testQueueHandler.removePlayable(at: PlayerIndex(queueType: .next, index: 10))
    XCTAssertEqual(testPlayer.contextQueue.playables.count, 0)
    testQueueHandler.removePlayable(at: PlayerIndex(queueType: .prev, index: 10))
    XCTAssertEqual(testPlayer.contextQueue.playables.count, 0)
  }

  func testQueue_accessInputValidcation() {
    prepareNoWaitingQueuePlaying()
    testPlayer.setCurrentIndex(2)

    let prevQueueCount = testQueueHandler.prevQueueCount
    XCTAssertEqual(prevQueueCount, 2)
    // end is not valid -> empty set
    var items = testQueueHandler.getPrevQueueItems(from: 0, to: prevQueueCount)
    XCTAssertEqual(items.count, 0)
    // end is not valid -> empty set
    items = testQueueHandler.getPrevQueueItems(from: 0, to: -1)
    XCTAssertEqual(items.count, 0)
    // from is not valid -> empty set
    items = testQueueHandler.getPrevQueueItems(from: -1, to: nil)
    XCTAssertEqual(items.count, 0)
    // from is not valid -> empty set
    items = testQueueHandler.getPrevQueueItems(from: 5, to: prevQueueCount - 1)
    XCTAssertEqual(items.count, 0)
    // from and to is not valid -> empty set
    items = testQueueHandler.getPrevQueueItems(from: 1, to: 0)
    XCTAssertEqual(items.count, 0)

    let userQueueCount = testQueueHandler.userQueueCount
    XCTAssertEqual(userQueueCount, 4)
    // end is not valid -> empty set
    items = testQueueHandler.getUserQueueItems(from: 0, to: userQueueCount)
    XCTAssertEqual(items.count, 0)
    // end is not valid -> empty set
    items = testQueueHandler.getUserQueueItems(from: 0, to: -1)
    XCTAssertEqual(items.count, 0)
    // from is not valid -> empty set
    items = testQueueHandler.getUserQueueItems(from: -1, to: nil)
    XCTAssertEqual(items.count, 0)
    // from is not valid -> empty set
    items = testQueueHandler.getUserQueueItems(from: 5, to: userQueueCount - 1)
    XCTAssertEqual(items.count, 0)
    // from and to is not valid -> empty set
    items = testQueueHandler.getUserQueueItems(from: 1, to: 0)
    XCTAssertEqual(items.count, 0)

    let nextQueueCount = testQueueHandler.nextQueueCount
    XCTAssertEqual(nextQueueCount, 2)
    // end is not valid -> empty set
    items = testQueueHandler.getNextQueueItems(from: 0, to: nextQueueCount)
    XCTAssertEqual(items.count, 0)
    // end is not valid -> empty set
    items = testQueueHandler.getNextQueueItems(from: 0, to: -1)
    XCTAssertEqual(items.count, 0)
    // from is not valid -> empty set
    items = testQueueHandler.getNextQueueItems(from: -1, to: nil)
    XCTAssertEqual(items.count, 0)
    // from is not valid -> empty set
    items = testQueueHandler.getNextQueueItems(from: 5, to: nextQueueCount - 1)
    XCTAssertEqual(items.count, 0)
    // from and to is not valid -> empty set
    items = testQueueHandler.getNextQueueItems(from: 1, to: 0)
    XCTAssertEqual(items.count, 0)
  }

  func testWaitingQueueInsertFirst_noWaitingQueuePlaying() {
    prepareNoWaitingQueuePlaying()
    guard let song = library.getSong(for: account, id: cdHelper.seeder.songs[1].id)
    else { XCTFail(); return }
    testPlayer.setCurrentIndex(2)
    checkCurrentlyPlaying(idToBe: 2)
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [0, 1])
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [3, 4])
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [5, 6, 7, 8])
    checkQueueInfoConsistency()
    testPlayer.insertUserQueue(playables: [song])
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [0, 1])
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [3, 4])
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [1, 5, 6, 7, 8])
    checkQueueInfoConsistency()
  }

  func testWaitingQueueInsertFirst_noWaitingQueuePlaying2() {
    prepareNoWaitingQueuePlaying()
    guard let song = library.getSong(for: account, id: cdHelper.seeder.songs[1].id)
    else { XCTFail(); return }
    testPlayer.setCurrentIndex(2)
    checkCurrentlyPlaying(idToBe: 2)
    testQueueHandler.removePlayable(at: PlayerIndex(queueType: .user, index: 0))
    testQueueHandler.removePlayable(at: PlayerIndex(queueType: .user, index: 0))
    testQueueHandler.removePlayable(at: PlayerIndex(queueType: .user, index: 0))
    testQueueHandler.removePlayable(at: PlayerIndex(queueType: .user, index: 0))
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [0, 1])
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [3, 4])
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [])
    checkQueueInfoConsistency()
    testPlayer.insertUserQueue(playables: [song])
    checkCurrentlyPlaying(idToBe: 2)
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [0, 1])
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [3, 4])
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [1])
    checkQueueInfoConsistency()
  }

  func testWaitingQueueInsertFirst_withWaitingQueuePlaying() {
    prepareWithWaitingQueuePlaying()
    guard let song = library.getSong(for: account, id: cdHelper.seeder.songs[1].id)
    else { XCTFail(); return }
    testPlayer.setCurrentIndex(2)
    checkCurrentlyPlaying(idToBe: 5)
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [0, 1, 2])
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [3, 4])
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [6, 7, 8])
    checkQueueInfoConsistency()
    testPlayer.insertUserQueue(playables: [song])
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [0, 1, 2])
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [3, 4])
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [1, 6, 7, 8])
    checkQueueInfoConsistency()
  }

  func testWaitingQueueInsertFirst_withWaitingQueuePlaying2() {
    prepareWithWaitingQueuePlaying()
    guard let song = library.getSong(for: account, id: cdHelper.seeder.songs[1].id)
    else { XCTFail(); return }
    testPlayer.setCurrentIndex(2)
    checkCurrentlyPlaying(idToBe: 5)
    testQueueHandler.removePlayable(at: PlayerIndex(queueType: .user, index: 0))
    testQueueHandler.removePlayable(at: PlayerIndex(queueType: .user, index: 0))
    testQueueHandler.removePlayable(at: PlayerIndex(queueType: .user, index: 0))
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [0, 1, 2])
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [3, 4])
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [])
    checkQueueInfoConsistency()
    testPlayer.insertUserQueue(playables: [song])
    checkCurrentlyPlaying(idToBe: 5)
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [0, 1, 2])
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [3, 4])
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [1])
    checkQueueInfoConsistency()
  }

  func testWaitingQueueInsertLast_noWaitingQueuePlaying() {
    prepareNoWaitingQueuePlaying()
    guard let song = library.getSong(for: account, id: cdHelper.seeder.songs[1].id)
    else { XCTFail(); return }
    testPlayer.setCurrentIndex(2)
    checkCurrentlyPlaying(idToBe: 2)
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [0, 1])
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [3, 4])
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [5, 6, 7, 8])
    checkQueueInfoConsistency()
    testPlayer.appendUserQueue(playables: [song])
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [0, 1])
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [3, 4])
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [5, 6, 7, 8, 1])
    checkQueueInfoConsistency()
  }

  func testWaitingQueueInsertLast_withWaitingQueuePlaying() {
    prepareWithWaitingQueuePlaying()
    guard let song = library.getSong(for: account, id: cdHelper.seeder.songs[1].id)
    else { XCTFail(); return }
    testPlayer.setCurrentIndex(2)
    checkCurrentlyPlaying(idToBe: 5)
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [0, 1, 2])
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [3, 4])
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [6, 7, 8])
    checkQueueInfoConsistency()
    testPlayer.appendUserQueue(playables: [song])
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [0, 1, 2])
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [3, 4])
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [6, 7, 8, 1])
    checkQueueInfoConsistency()
  }

  func testMovePlaylistSong_InvalidValues() {
    prepareNoWaitingQueuePlaying()
    testQueueHandler.movePlayable(
      from: PlayerIndex(queueType: .prev, index: 0),
      to: PlayerIndex(queueType: .prev, index: 5)
    )
    checkCorrectDefaultPlaylist()
    testQueueHandler.movePlayable(
      from: PlayerIndex(queueType: .next, index: 0),
      to: PlayerIndex(queueType: .prev, index: 20)
    )
    checkCorrectDefaultPlaylist()
    testQueueHandler.movePlayable(
      from: PlayerIndex(queueType: .prev, index: 5),
      to: PlayerIndex(queueType: .prev, index: 0)
    )
    checkCorrectDefaultPlaylist()
    testQueueHandler.movePlayable(
      from: PlayerIndex(queueType: .prev, index: 20),
      to: PlayerIndex(queueType: .prev, index: 0)
    )
    checkCorrectDefaultPlaylist()
    testQueueHandler.movePlayable(
      from: PlayerIndex(queueType: .next, index: 1),
      to: PlayerIndex(queueType: .next, index: 5)
    )
    checkCorrectDefaultPlaylist()
    testQueueHandler.movePlayable(
      from: PlayerIndex(queueType: .prev, index: 1),
      to: PlayerIndex(queueType: .prev, index: 1)
    )
    checkCorrectDefaultPlaylist()
    testQueueHandler.movePlayable(
      from: PlayerIndex(queueType: .prev, index: 1),
      to: PlayerIndex(queueType: .prev, index: -1)
    )
    checkCorrectDefaultPlaylist()
    testQueueHandler.movePlayable(
      from: PlayerIndex(queueType: .next, index: 1),
      to: PlayerIndex(queueType: .prev, index: -20)
    )
    checkCorrectDefaultPlaylist()
    testQueueHandler.movePlayable(
      from: PlayerIndex(queueType: .prev, index: 1),
      to: PlayerIndex(queueType: .next, index: 1)
    )
    checkCorrectDefaultPlaylist()
    testQueueHandler.movePlayable(
      from: PlayerIndex(queueType: .next, index: 4),
      to: PlayerIndex(queueType: .prev, index: 4)
    )
    checkCorrectDefaultPlaylist()
    testQueueHandler.movePlayable(
      from: PlayerIndex(queueType: .prev, index: -1),
      to: PlayerIndex(queueType: .next, index: 30)
    )
    checkCorrectDefaultPlaylist()
    testQueueHandler.movePlayable(
      from: PlayerIndex(queueType: .next, index: 30),
      to: PlayerIndex(queueType: .prev, index: -9)
    )
    checkCorrectDefaultPlaylist()
  }

  func testMovePlaylistSong() {
    prepareNoWaitingQueuePlaying()
    testPlayer.setCurrentIndex(2)
    testQueueHandler.movePlayable(
      from: PlayerIndex(queueType: .prev, index: 1),
      to: PlayerIndex(queueType: .next, index: 1)
    )
    XCTAssertEqual(testPlayer.currentIndex, 1)
    checkPlaylistIndexEqualSeedIndex(playlistIndex: 0, seedIndex: 0)
    checkPlaylistIndexEqualSeedIndex(playlistIndex: 1, seedIndex: 2)
    checkPlaylistIndexEqualSeedIndex(playlistIndex: 2, seedIndex: 3)
    checkPlaylistIndexEqualSeedIndex(playlistIndex: 3, seedIndex: 1)
    checkPlaylistIndexEqualSeedIndex(playlistIndex: 4, seedIndex: 4)
    checkQueueInfoConsistency()

    prepareNoWaitingQueuePlaying()
    testPlayer.setCurrentIndex(1)
    testQueueHandler.movePlayable(
      from: PlayerIndex(queueType: .next, index: 0),
      to: PlayerIndex(queueType: .next, index: 1)
    )
    XCTAssertEqual(testPlayer.currentIndex, 1)
    checkPlaylistIndexEqualSeedIndex(playlistIndex: 0, seedIndex: 0)
    checkPlaylistIndexEqualSeedIndex(playlistIndex: 1, seedIndex: 1)
    checkPlaylistIndexEqualSeedIndex(playlistIndex: 2, seedIndex: 3)
    checkPlaylistIndexEqualSeedIndex(playlistIndex: 3, seedIndex: 2)
    checkPlaylistIndexEqualSeedIndex(playlistIndex: 4, seedIndex: 4)
    checkQueueInfoConsistency()

    prepareNoWaitingQueuePlaying()
    testPlayer.setCurrentIndex(0)
    testQueueHandler.movePlayable(
      from: PlayerIndex(queueType: .next, index: 3),
      to: PlayerIndex(queueType: .next, index: 4)
    )
    XCTAssertEqual(testPlayer.currentIndex, 0)
    checkPlaylistIndexEqualSeedIndex(playlistIndex: 0, seedIndex: 0)
    checkPlaylistIndexEqualSeedIndex(playlistIndex: 1, seedIndex: 1)
    checkPlaylistIndexEqualSeedIndex(playlistIndex: 2, seedIndex: 2)
    checkPlaylistIndexEqualSeedIndex(playlistIndex: 3, seedIndex: 3)
    checkPlaylistIndexEqualSeedIndex(playlistIndex: 4, seedIndex: 4)
    checkQueueInfoConsistency()
    testPlayer.removeAllItems()
    fillPlayerWithSomeSongs()

    testPlayer.setCurrentIndex(0)
    testQueueHandler.movePlayable(
      from: PlayerIndex(queueType: .next, index: 2),
      to: PlayerIndex(queueType: .next, index: 3)
    )
    XCTAssertEqual(testPlayer.currentIndex, 0)
    checkPlaylistIndexEqualSeedIndex(playlistIndex: 0, seedIndex: 0)
    checkPlaylistIndexEqualSeedIndex(playlistIndex: 1, seedIndex: 1)
    checkPlaylistIndexEqualSeedIndex(playlistIndex: 2, seedIndex: 2)
    checkPlaylistIndexEqualSeedIndex(playlistIndex: 3, seedIndex: 4)
    checkPlaylistIndexEqualSeedIndex(playlistIndex: 4, seedIndex: 3)
    checkQueueInfoConsistency()

    prepareNoWaitingQueuePlaying()
    testPlayer.setCurrentIndex(2)
    testQueueHandler.movePlayable(
      from: PlayerIndex(queueType: .prev, index: 0),
      to: PlayerIndex(queueType: .next, index: 1)
    )
    XCTAssertEqual(testPlayer.currentIndex, 1)
    checkPlaylistIndexEqualSeedIndex(playlistIndex: 0, seedIndex: 1)
    checkPlaylistIndexEqualSeedIndex(playlistIndex: 1, seedIndex: 2)
    checkPlaylistIndexEqualSeedIndex(playlistIndex: 2, seedIndex: 3)
    checkPlaylistIndexEqualSeedIndex(playlistIndex: 3, seedIndex: 0)
    checkPlaylistIndexEqualSeedIndex(playlistIndex: 4, seedIndex: 4)
    checkQueueInfoConsistency()

    prepareNoWaitingQueuePlaying()
    testPlayer.setCurrentIndex(3)
    testQueueHandler.movePlayable(
      from: PlayerIndex(queueType: .next, index: 0),
      to: PlayerIndex(queueType: .prev, index: 2)
    )
    XCTAssertEqual(testPlayer.currentIndex, 4)
    checkPlaylistIndexEqualSeedIndex(playlistIndex: 0, seedIndex: 0)
    checkPlaylistIndexEqualSeedIndex(playlistIndex: 1, seedIndex: 1)
    checkPlaylistIndexEqualSeedIndex(playlistIndex: 2, seedIndex: 4)
    checkPlaylistIndexEqualSeedIndex(playlistIndex: 3, seedIndex: 2)
    checkPlaylistIndexEqualSeedIndex(playlistIndex: 4, seedIndex: 3)
    checkQueueInfoConsistency()

    prepareNoWaitingQueuePlaying()
    testPlayer.setCurrentIndex(3)
    testQueueHandler.movePlayable(
      from: PlayerIndex(queueType: .next, index: 0),
      to: PlayerIndex(queueType: .prev, index: 1)
    )
    checkPlaylistIndexEqualSeedIndex(playlistIndex: 0, seedIndex: 0)
    checkPlaylistIndexEqualSeedIndex(playlistIndex: 1, seedIndex: 4)
    checkPlaylistIndexEqualSeedIndex(playlistIndex: 2, seedIndex: 1)
    checkPlaylistIndexEqualSeedIndex(playlistIndex: 3, seedIndex: 2)
    checkPlaylistIndexEqualSeedIndex(playlistIndex: 4, seedIndex: 3)
    checkQueueInfoConsistency()

    prepareNoWaitingQueuePlaying()
    testPlayer.setCurrentIndex(4)
    testQueueHandler.movePlayable(
      from: PlayerIndex(queueType: .prev, index: 2),
      to: PlayerIndex(queueType: .next, index: 0)
    )
    XCTAssertEqual(testPlayer.currentIndex, 3)
    checkPlaylistIndexEqualSeedIndex(playlistIndex: 0, seedIndex: 0)
    checkPlaylistIndexEqualSeedIndex(playlistIndex: 1, seedIndex: 1)
    checkPlaylistIndexEqualSeedIndex(playlistIndex: 2, seedIndex: 3)
    checkPlaylistIndexEqualSeedIndex(playlistIndex: 3, seedIndex: 4)
    checkPlaylistIndexEqualSeedIndex(playlistIndex: 4, seedIndex: 2)
    checkQueueInfoConsistency()

    prepareNoWaitingQueuePlaying()
    testPlayer.setCurrentIndex(0)
    testQueueHandler.movePlayable(
      from: PlayerIndex(queueType: .next, index: 3),
      to: PlayerIndex(queueType: .prev, index: 0)
    )
    XCTAssertEqual(testPlayer.currentIndex, 1)
    checkPlaylistIndexEqualSeedIndex(playlistIndex: 0, seedIndex: 4)
    checkPlaylistIndexEqualSeedIndex(playlistIndex: 1, seedIndex: 0)
    checkPlaylistIndexEqualSeedIndex(playlistIndex: 2, seedIndex: 1)
    checkPlaylistIndexEqualSeedIndex(playlistIndex: 3, seedIndex: 2)
    checkPlaylistIndexEqualSeedIndex(playlistIndex: 4, seedIndex: 3)
    checkQueueInfoConsistency()
  }

  func testQueueCreation_noWaitingQueuePlaying() {
    prepareNoWaitingQueuePlaying()
    testPlayer.setCurrentIndex(0)
    checkCurrentlyPlaying(idToBe: 0)
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [Int]())
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [1, 2, 3, 4])
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [5, 6, 7, 8])
    checkQueueInfoConsistency()

    testPlayer.setCurrentIndex(2)
    checkCurrentlyPlaying(idToBe: 2)
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [0, 1])
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [3, 4])
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [5, 6, 7, 8])
    checkQueueInfoConsistency()

    testPlayer.setCurrentIndex(3)
    checkCurrentlyPlaying(idToBe: 3)
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [0, 1, 2])
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [4])
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [5, 6, 7, 8])
    checkQueueInfoConsistency()

    testPlayer.setCurrentIndex(4)
    checkCurrentlyPlaying(idToBe: 4)
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [0, 1, 2, 3])
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [Int]())
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [5, 6, 7, 8])
    checkQueueInfoConsistency()
  }

  func testQueueCreation_withWaitingQueuePlaying() {
    prepareWithWaitingQueuePlaying()
    testPlayer.setCurrentIndex(-1)
    checkCurrentlyPlaying(idToBe: 5)
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [Int]())
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [0, 1, 2, 3, 4])
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [6, 7, 8])
    checkQueueInfoConsistency()

    testPlayer.setCurrentIndex(0)
    checkCurrentlyPlaying(idToBe: 5)
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [0])
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [1, 2, 3, 4])
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [6, 7, 8])
    checkQueueInfoConsistency()

    testPlayer.setCurrentIndex(2)
    checkCurrentlyPlaying(idToBe: 5)
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [0, 1, 2])
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [3, 4])
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [6, 7, 8])
    checkQueueInfoConsistency()

    testPlayer.setCurrentIndex(3)
    checkCurrentlyPlaying(idToBe: 5)
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [0, 1, 2, 3])
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [4])
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [6, 7, 8])
    checkQueueInfoConsistency()

    testPlayer.setCurrentIndex(4)
    checkCurrentlyPlaying(idToBe: 5)
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [0, 1, 2, 3, 4])
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [Int]())
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [6, 7, 8])
    checkQueueInfoConsistency()
  }

  func testRemovePlayable_noWaitingQueuePlaying() {
    prepareNoWaitingQueuePlaying()
    testPlayer.setCurrentIndex(2)
    testQueueHandler.removePlayable(at: PlayerIndex(queueType: .prev, index: 0))
    checkCurrentlyPlaying(idToBe: 2)
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [1])
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [3, 4])
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [5, 6, 7, 8])
    checkQueueInfoConsistency()

    prepareNoWaitingQueuePlaying()
    testPlayer.setCurrentIndex(2)
    testQueueHandler.removePlayable(at: PlayerIndex(queueType: .prev, index: 1))
    checkCurrentlyPlaying(idToBe: 2)
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [0])
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [3, 4])
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [5, 6, 7, 8])
    checkQueueInfoConsistency()

    prepareNoWaitingQueuePlaying()
    testPlayer.setCurrentIndex(2)
    testQueueHandler.removePlayable(at: PlayerIndex(queueType: .next, index: 0))
    checkCurrentlyPlaying(idToBe: 2)
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [0, 1])
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [4])
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [5, 6, 7, 8])
    checkQueueInfoConsistency()

    prepareNoWaitingQueuePlaying()
    testPlayer.setCurrentIndex(2)
    testQueueHandler.removePlayable(at: PlayerIndex(queueType: .next, index: 1))
    checkCurrentlyPlaying(idToBe: 2)
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [0, 1])
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [3])
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [5, 6, 7, 8])
    checkQueueInfoConsistency()

    prepareNoWaitingQueuePlaying()
    testPlayer.setCurrentIndex(2)
    testQueueHandler.removePlayable(at: PlayerIndex(queueType: .user, index: 0))
    checkCurrentlyPlaying(idToBe: 2)
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [0, 1])
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [3, 4])
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [6, 7, 8])
    checkQueueInfoConsistency()

    prepareNoWaitingQueuePlaying()
    testPlayer.setCurrentIndex(2)
    testQueueHandler.removePlayable(at: PlayerIndex(queueType: .user, index: 1))
    checkCurrentlyPlaying(idToBe: 2)
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [0, 1])
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [3, 4])
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [5, 7, 8])
    checkQueueInfoConsistency()

    prepareNoWaitingQueuePlaying()
    testPlayer.setCurrentIndex(2)
    testQueueHandler.removePlayable(at: PlayerIndex(queueType: .user, index: 3))
    checkCurrentlyPlaying(idToBe: 2)
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [0, 1])
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [3, 4])
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [5, 6, 7])
    checkQueueInfoConsistency()
  }

  func testRemovePlayable_noWaitingQueuePlaying_edgeCases() {
    prepareNoWaitingQueuePlaying()
    testPlayer.setCurrentIndex(1)
    testQueueHandler.removePlayable(at: PlayerIndex(queueType: .prev, index: 0))
    checkCurrentlyPlaying(idToBe: 1)
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [Int]())
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [2, 3, 4])
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [5, 6, 7, 8])
    checkQueueInfoConsistency()

    prepareNoWaitingQueuePlaying()
    testPlayer.setCurrentIndex(0)
    testQueueHandler.removePlayable(at: PlayerIndex(queueType: .next, index: 0))
    checkCurrentlyPlaying(idToBe: 0)
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [Int]())
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [2, 3, 4])
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [5, 6, 7, 8])
    checkQueueInfoConsistency()

    prepareNoWaitingQueuePlaying()
    testPlayer.setCurrentIndex(4)
    testQueueHandler.removePlayable(at: PlayerIndex(queueType: .prev, index: 3))
    checkCurrentlyPlaying(idToBe: 4)
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [0, 1, 2])
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [Int]())
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [5, 6, 7, 8])
    checkQueueInfoConsistency()

    prepareNoWaitingQueuePlaying()
    testPlayer.setCurrentIndex(3)
    testQueueHandler.removePlayable(at: PlayerIndex(queueType: .next, index: 0))
    checkCurrentlyPlaying(idToBe: 3)
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [0, 1, 2])
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [Int]())
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [5, 6, 7, 8])
    checkQueueInfoConsistency()
  }

  func testRemovePlayable_withWaitingQueuePlaying() {
    prepareWithWaitingQueuePlaying()
    testPlayer.setCurrentIndex(2)
    testQueueHandler.removePlayable(at: PlayerIndex(queueType: .prev, index: 0))
    checkCurrentlyPlaying(idToBe: 5)
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [1, 2])
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [3, 4])
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [6, 7, 8])
    checkQueueInfoConsistency()

    prepareWithWaitingQueuePlaying()
    testPlayer.setCurrentIndex(2)
    testQueueHandler.removePlayable(at: PlayerIndex(queueType: .prev, index: 1))
    checkCurrentlyPlaying(idToBe: 5)
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [0, 2])
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [3, 4])
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [6, 7, 8])
    checkQueueInfoConsistency()

    prepareWithWaitingQueuePlaying()
    testPlayer.setCurrentIndex(2)
    testQueueHandler.removePlayable(at: PlayerIndex(queueType: .prev, index: 2))
    checkCurrentlyPlaying(idToBe: 5)
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [0, 1])
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [3, 4])
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [6, 7, 8])
    checkQueueInfoConsistency()

    prepareWithWaitingQueuePlaying()
    testPlayer.setCurrentIndex(2)
    testQueueHandler.removePlayable(at: PlayerIndex(queueType: .next, index: 0))
    checkCurrentlyPlaying(idToBe: 5)
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [0, 1, 2])
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [4])
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [6, 7, 8])
    checkQueueInfoConsistency()

    prepareWithWaitingQueuePlaying()
    testPlayer.setCurrentIndex(2)
    testQueueHandler.removePlayable(at: PlayerIndex(queueType: .next, index: 1))
    checkCurrentlyPlaying(idToBe: 5)
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [0, 1, 2])
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [3])
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [6, 7, 8])
    checkQueueInfoConsistency()

    prepareWithWaitingQueuePlaying()
    testPlayer.setCurrentIndex(2)
    testQueueHandler.removePlayable(at: PlayerIndex(queueType: .user, index: 0))
    checkCurrentlyPlaying(idToBe: 5)
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [0, 1, 2])
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [3, 4])
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [7, 8])
    checkQueueInfoConsistency()

    prepareWithWaitingQueuePlaying()
    testPlayer.setCurrentIndex(2)
    testQueueHandler.removePlayable(at: PlayerIndex(queueType: .user, index: 1))
    checkCurrentlyPlaying(idToBe: 5)
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [0, 1, 2])
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [3, 4])
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [6, 8])
    checkQueueInfoConsistency()

    prepareWithWaitingQueuePlaying()
    testPlayer.setCurrentIndex(2)
    testQueueHandler.removePlayable(at: PlayerIndex(queueType: .user, index: 2))
    checkCurrentlyPlaying(idToBe: 5)
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [0, 1, 2])
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [3, 4])
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [6, 7])
    checkQueueInfoConsistency()
  }

  func testRemovePlayable_withWaitingQueuePlaying_edgeCases() {
    prepareWithWaitingQueuePlaying()
    testPlayer.setCurrentIndex(0)
    testQueueHandler.removePlayable(at: PlayerIndex(queueType: .prev, index: 0))
    checkCurrentlyPlaying(idToBe: 5)
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [Int]())
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [1, 2, 3, 4])
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [6, 7, 8])
    checkQueueInfoConsistency()

    prepareWithWaitingQueuePlaying()
    testPlayer.setCurrentIndex(4)
    testQueueHandler.removePlayable(at: PlayerIndex(queueType: .prev, index: 4))
    checkCurrentlyPlaying(idToBe: 5)
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [0, 1, 2, 3])
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [Int]())
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [6, 7, 8])
    checkQueueInfoConsistency()

    prepareWithWaitingQueuePlaying()
    testPlayer.setCurrentIndex(3)
    testQueueHandler.removePlayable(at: PlayerIndex(queueType: .next, index: 0))
    checkCurrentlyPlaying(idToBe: 5)
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [0, 1, 2, 3])
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [Int]())
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [6, 7, 8])
    checkQueueInfoConsistency()

    prepareWithWaitingQueuePlaying()
    testPlayer.setCurrentIndex(3)
    testQueueHandler.removePlayable(at: PlayerIndex(queueType: .user, index: 2))
    testQueueHandler.removePlayable(at: PlayerIndex(queueType: .user, index: 0))
    testQueueHandler.removePlayable(at: PlayerIndex(queueType: .user, index: 0))
    checkCurrentlyPlaying(idToBe: 5)
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [0, 1, 2, 3])
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [4])
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [Int]())
    checkQueueInfoConsistency()

    prepareWithWaitingQueuePlaying()
    testPlayer.setCurrentIndex(3)
    testQueueHandler.removePlayable(at: PlayerIndex(queueType: .prev, index: 2))
    testQueueHandler.removePlayable(at: PlayerIndex(queueType: .prev, index: 0))
    testQueueHandler.removePlayable(at: PlayerIndex(queueType: .prev, index: 1))
    testQueueHandler.removePlayable(at: PlayerIndex(queueType: .prev, index: 0))
    testQueueHandler.removePlayable(at: PlayerIndex(queueType: .next, index: 1))
    testQueueHandler.removePlayable(at: PlayerIndex(queueType: .next, index: 0))
    testQueueHandler.removePlayable(at: PlayerIndex(queueType: .user, index: 2))
    testQueueHandler.removePlayable(at: PlayerIndex(queueType: .user, index: 0))
    testQueueHandler.removePlayable(at: PlayerIndex(queueType: .user, index: 0))
    checkCurrentlyPlaying(idToBe: 5)
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [Int]())
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [Int]())
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [Int]())
    checkQueueInfoConsistency()
  }

  func testMove_PrevPrev_noWaitingQueuePlaying() {
    prepareNoWaitingQueuePlaying()
    testPlayer.setCurrentIndex(2)
    testQueueHandler.movePlayable(
      from: PlayerIndex(queueType: .prev, index: 0),
      to: PlayerIndex(queueType: .prev, index: 1)
    )
    checkCurrentlyPlaying(idToBe: 2)
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [1, 0])
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [3, 4])
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [5, 6, 7, 8])
    checkQueueInfoConsistency()

    prepareNoWaitingQueuePlaying()
    testPlayer.setCurrentIndex(2)
    testQueueHandler.movePlayable(
      from: PlayerIndex(queueType: .prev, index: 1),
      to: PlayerIndex(queueType: .prev, index: 0)
    )
    checkCurrentlyPlaying(idToBe: 2)
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [1, 0])
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [3, 4])
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [5, 6, 7, 8])
    checkQueueInfoConsistency()

    prepareNoWaitingQueuePlaying()
    testPlayer.setCurrentIndex(3)
    testQueueHandler.movePlayable(
      from: PlayerIndex(queueType: .prev, index: 0),
      to: PlayerIndex(queueType: .prev, index: 2)
    )
    checkCurrentlyPlaying(idToBe: 3)
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [1, 2, 0])
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [4])
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [5, 6, 7, 8])
    checkQueueInfoConsistency()

    prepareNoWaitingQueuePlaying()
    testPlayer.setCurrentIndex(3)
    testQueueHandler.movePlayable(
      from: PlayerIndex(queueType: .prev, index: 2),
      to: PlayerIndex(queueType: .prev, index: 0)
    )
    checkCurrentlyPlaying(idToBe: 3)
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [2, 0, 1])
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [4])
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [5, 6, 7, 8])
    checkQueueInfoConsistency()

    prepareNoWaitingQueuePlaying()
    testPlayer.setCurrentIndex(4)
    testQueueHandler.movePlayable(
      from: PlayerIndex(queueType: .prev, index: 3),
      to: PlayerIndex(queueType: .prev, index: 2)
    )
    checkCurrentlyPlaying(idToBe: 4)
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [0, 1, 3, 2])
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [Int]())
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [5, 6, 7, 8])
    checkQueueInfoConsistency()

    prepareNoWaitingQueuePlaying()
    testPlayer.setCurrentIndex(4)
    testQueueHandler.movePlayable(
      from: PlayerIndex(queueType: .prev, index: 3),
      to: PlayerIndex(queueType: .prev, index: 0)
    )
    checkCurrentlyPlaying(idToBe: 4)
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [3, 0, 1, 2])
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [Int]())
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [5, 6, 7, 8])
    checkQueueInfoConsistency()
  }

  func testMove_PrevPrev_withWaitingQueuePlaying() {
    prepareWithWaitingQueuePlaying()
    testPlayer.setCurrentIndex(1)
    testQueueHandler.movePlayable(
      from: PlayerIndex(queueType: .prev, index: 0),
      to: PlayerIndex(queueType: .prev, index: 1)
    )
    checkCurrentlyPlaying(idToBe: 5)
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [1, 0])
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [2, 3, 4])
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [6, 7, 8])
    checkQueueInfoConsistency()

    prepareWithWaitingQueuePlaying()
    testPlayer.setCurrentIndex(2)
    testQueueHandler.movePlayable(
      from: PlayerIndex(queueType: .prev, index: 1),
      to: PlayerIndex(queueType: .prev, index: 0)
    )
    checkCurrentlyPlaying(idToBe: 5)
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [1, 0, 2])
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [3, 4])
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [6, 7, 8])
    checkQueueInfoConsistency()

    prepareWithWaitingQueuePlaying()
    testPlayer.setCurrentIndex(3)
    testQueueHandler.movePlayable(
      from: PlayerIndex(queueType: .prev, index: 0),
      to: PlayerIndex(queueType: .prev, index: 3)
    )
    checkCurrentlyPlaying(idToBe: 5)
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [1, 2, 3, 0])
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [4])
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [6, 7, 8])
    checkQueueInfoConsistency()

    prepareWithWaitingQueuePlaying()
    testPlayer.setCurrentIndex(3)
    testQueueHandler.movePlayable(
      from: PlayerIndex(queueType: .prev, index: 3),
      to: PlayerIndex(queueType: .prev, index: 0)
    )
    checkCurrentlyPlaying(idToBe: 5)
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [3, 0, 1, 2])
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [4])
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [6, 7, 8])
    checkQueueInfoConsistency()

    prepareWithWaitingQueuePlaying()
    testPlayer.setCurrentIndex(4)
    testQueueHandler.movePlayable(
      from: PlayerIndex(queueType: .prev, index: 3),
      to: PlayerIndex(queueType: .prev, index: 2)
    )
    checkCurrentlyPlaying(idToBe: 5)
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [0, 1, 3, 2, 4])
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [Int]())
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [6, 7, 8])
    checkQueueInfoConsistency()

    prepareWithWaitingQueuePlaying()
    testPlayer.setCurrentIndex(4)
    testQueueHandler.movePlayable(
      from: PlayerIndex(queueType: .prev, index: 4),
      to: PlayerIndex(queueType: .prev, index: 0)
    )
    checkCurrentlyPlaying(idToBe: 5)
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [4, 0, 1, 2, 3])
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [Int]())
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [6, 7, 8])
    checkQueueInfoConsistency()
  }

  func testMove_NextNext_noWaitingQueuePlaying() {
    prepareNoWaitingQueuePlaying()
    testPlayer.setCurrentIndex(2)
    testQueueHandler.movePlayable(
      from: PlayerIndex(queueType: .next, index: 0),
      to: PlayerIndex(queueType: .next, index: 1)
    )
    checkCurrentlyPlaying(idToBe: 2)
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [0, 1])
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [4, 3])
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [5, 6, 7, 8])
    checkQueueInfoConsistency()

    prepareNoWaitingQueuePlaying()
    testPlayer.setCurrentIndex(2)
    testQueueHandler.movePlayable(
      from: PlayerIndex(queueType: .next, index: 1),
      to: PlayerIndex(queueType: .next, index: 0)
    )
    checkCurrentlyPlaying(idToBe: 2)
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [0, 1])
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [4, 3])
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [5, 6, 7, 8])
    checkQueueInfoConsistency()

    prepareNoWaitingQueuePlaying()
    testPlayer.setCurrentIndex(1)
    testQueueHandler.movePlayable(
      from: PlayerIndex(queueType: .next, index: 0),
      to: PlayerIndex(queueType: .next, index: 2)
    )
    checkCurrentlyPlaying(idToBe: 1)
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [0])
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [3, 4, 2])
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [5, 6, 7, 8])
    checkQueueInfoConsistency()

    prepareNoWaitingQueuePlaying()
    testPlayer.setCurrentIndex(1)
    testQueueHandler.movePlayable(
      from: PlayerIndex(queueType: .next, index: 2),
      to: PlayerIndex(queueType: .next, index: 0)
    )
    checkCurrentlyPlaying(idToBe: 1)
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [0])
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [4, 2, 3])
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [5, 6, 7, 8])
    checkQueueInfoConsistency()

    prepareNoWaitingQueuePlaying()
    testPlayer.setCurrentIndex(0)
    testQueueHandler.movePlayable(
      from: PlayerIndex(queueType: .next, index: 3),
      to: PlayerIndex(queueType: .next, index: 2)
    )
    checkCurrentlyPlaying(idToBe: 0)
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [Int]())
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [1, 2, 4, 3])
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [5, 6, 7, 8])
    checkQueueInfoConsistency()

    prepareNoWaitingQueuePlaying()
    testPlayer.setCurrentIndex(0)
    testQueueHandler.movePlayable(
      from: PlayerIndex(queueType: .next, index: 3),
      to: PlayerIndex(queueType: .next, index: 0)
    )
    checkCurrentlyPlaying(idToBe: 0)
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [Int]())
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [4, 1, 2, 3])
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [5, 6, 7, 8])
    checkQueueInfoConsistency()
  }

  func testMove_NextNext_withWaitingQueuePlaying() {
    prepareWithWaitingQueuePlaying()
    testPlayer.setCurrentIndex(2)
    testQueueHandler.movePlayable(
      from: PlayerIndex(queueType: .next, index: 0),
      to: PlayerIndex(queueType: .next, index: 1)
    )
    checkCurrentlyPlaying(idToBe: 5)
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [0, 1, 2])
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [4, 3])
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [6, 7, 8])
    checkQueueInfoConsistency()

    prepareWithWaitingQueuePlaying()
    testPlayer.setCurrentIndex(2)
    testQueueHandler.movePlayable(
      from: PlayerIndex(queueType: .next, index: 1),
      to: PlayerIndex(queueType: .next, index: 0)
    )
    checkCurrentlyPlaying(idToBe: 5)
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [0, 1, 2])
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [4, 3])
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [6, 7, 8])
    checkQueueInfoConsistency()

    prepareWithWaitingQueuePlaying()
    testPlayer.setCurrentIndex(1)
    testQueueHandler.movePlayable(
      from: PlayerIndex(queueType: .next, index: 0),
      to: PlayerIndex(queueType: .next, index: 2)
    )
    checkCurrentlyPlaying(idToBe: 5)
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [0, 1])
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [3, 4, 2])
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [6, 7, 8])
    checkQueueInfoConsistency()

    prepareWithWaitingQueuePlaying()
    testPlayer.setCurrentIndex(1)
    testQueueHandler.movePlayable(
      from: PlayerIndex(queueType: .next, index: 2),
      to: PlayerIndex(queueType: .next, index: 0)
    )
    checkCurrentlyPlaying(idToBe: 5)
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [0, 1])
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [4, 2, 3])
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [6, 7, 8])
    checkQueueInfoConsistency()

    prepareWithWaitingQueuePlaying()
    testPlayer.setCurrentIndex(0)
    testQueueHandler.movePlayable(
      from: PlayerIndex(queueType: .next, index: 3),
      to: PlayerIndex(queueType: .next, index: 2)
    )
    checkCurrentlyPlaying(idToBe: 5)
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [0])
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [1, 2, 4, 3])
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [6, 7, 8])
    checkQueueInfoConsistency()

    prepareWithWaitingQueuePlaying()
    testPlayer.setCurrentIndex(-1)
    testQueueHandler.movePlayable(
      from: PlayerIndex(queueType: .next, index: 4),
      to: PlayerIndex(queueType: .next, index: 0)
    )
    checkCurrentlyPlaying(idToBe: 5)
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [Int]())
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [4, 0, 1, 2, 3])
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [6, 7, 8])
    checkQueueInfoConsistency()

    prepareWithWaitingQueuePlaying()
    testPlayer.setCurrentIndex(-1)
    testQueueHandler.movePlayable(
      from: PlayerIndex(queueType: .next, index: 0),
      to: PlayerIndex(queueType: .next, index: 3)
    )
    checkCurrentlyPlaying(idToBe: 5)
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [Int]())
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [1, 2, 3, 0, 4])
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [6, 7, 8])
    checkQueueInfoConsistency()
  }

  func testMove_WaitWait_noWaitingQueuePlaying() {
    prepareNoWaitingQueuePlaying()
    testPlayer.setCurrentIndex(2)
    testQueueHandler.movePlayable(
      from: PlayerIndex(queueType: .user, index: 0),
      to: PlayerIndex(queueType: .user, index: 1)
    )
    checkCurrentlyPlaying(idToBe: 2)
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [0, 1])
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [3, 4])
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [6, 5, 7, 8])
    checkQueueInfoConsistency()

    prepareNoWaitingQueuePlaying()
    testPlayer.setCurrentIndex(2)
    testQueueHandler.movePlayable(
      from: PlayerIndex(queueType: .user, index: 1),
      to: PlayerIndex(queueType: .user, index: 0)
    )
    checkCurrentlyPlaying(idToBe: 2)
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [0, 1])
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [3, 4])
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [6, 5, 7, 8])
    checkQueueInfoConsistency()

    prepareNoWaitingQueuePlaying()
    testPlayer.setCurrentIndex(1)
    testQueueHandler.movePlayable(
      from: PlayerIndex(queueType: .user, index: 0),
      to: PlayerIndex(queueType: .user, index: 2)
    )
    checkCurrentlyPlaying(idToBe: 1)
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [0])
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [2, 3, 4])
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [6, 7, 5, 8])
    checkQueueInfoConsistency()

    prepareNoWaitingQueuePlaying()
    testPlayer.setCurrentIndex(1)
    testQueueHandler.movePlayable(
      from: PlayerIndex(queueType: .user, index: 2),
      to: PlayerIndex(queueType: .user, index: 0)
    )
    checkCurrentlyPlaying(idToBe: 1)
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [0])
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [2, 3, 4])
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [7, 5, 6, 8])
    checkQueueInfoConsistency()

    prepareNoWaitingQueuePlaying()
    testPlayer.setCurrentIndex(0)
    testQueueHandler.movePlayable(
      from: PlayerIndex(queueType: .user, index: 3),
      to: PlayerIndex(queueType: .user, index: 2)
    )
    checkCurrentlyPlaying(idToBe: 0)
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [Int]())
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [1, 2, 3, 4])
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [5, 6, 8, 7])
    checkQueueInfoConsistency()

    prepareNoWaitingQueuePlaying()
    testPlayer.setCurrentIndex(0)
    testQueueHandler.movePlayable(
      from: PlayerIndex(queueType: .user, index: 3),
      to: PlayerIndex(queueType: .user, index: 0)
    )
    checkCurrentlyPlaying(idToBe: 0)
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [Int]())
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [1, 2, 3, 4])
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [8, 5, 6, 7])
    checkQueueInfoConsistency()

    prepareNoWaitingQueuePlaying()
    testPlayer.setCurrentIndex(4)
    testQueueHandler.movePlayable(
      from: PlayerIndex(queueType: .user, index: 3),
      to: PlayerIndex(queueType: .user, index: 0)
    )
    checkCurrentlyPlaying(idToBe: 4)
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [0, 1, 2, 3])
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [Int]())
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [8, 5, 6, 7])
    checkQueueInfoConsistency()
  }

  func testMove_WaitWait_withWaitingQueuePlaying() {
    prepareWithWaitingQueuePlaying()
    testPlayer.setCurrentIndex(2)
    testQueueHandler.movePlayable(
      from: PlayerIndex(queueType: .user, index: 0),
      to: PlayerIndex(queueType: .user, index: 1)
    )
    checkCurrentlyPlaying(idToBe: 5)
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [0, 1, 2])
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [3, 4])
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [7, 6, 8])
    checkQueueInfoConsistency()

    prepareWithWaitingQueuePlaying()
    testPlayer.setCurrentIndex(2)
    testQueueHandler.movePlayable(
      from: PlayerIndex(queueType: .user, index: 1),
      to: PlayerIndex(queueType: .user, index: 0)
    )
    checkCurrentlyPlaying(idToBe: 5)
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [0, 1, 2])
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [3, 4])
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [7, 6, 8])
    checkQueueInfoConsistency()

    prepareWithWaitingQueuePlaying()
    testPlayer.setCurrentIndex(1)
    testQueueHandler.movePlayable(
      from: PlayerIndex(queueType: .user, index: 0),
      to: PlayerIndex(queueType: .user, index: 2)
    )
    checkCurrentlyPlaying(idToBe: 5)
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [0, 1])
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [2, 3, 4])
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [7, 8, 6])
    checkQueueInfoConsistency()

    prepareWithWaitingQueuePlaying()
    testPlayer.setCurrentIndex(1)
    testQueueHandler.movePlayable(
      from: PlayerIndex(queueType: .user, index: 2),
      to: PlayerIndex(queueType: .user, index: 0)
    )
    checkCurrentlyPlaying(idToBe: 5)
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [0, 1])
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [2, 3, 4])
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [8, 6, 7])
    checkQueueInfoConsistency()

    prepareWithWaitingQueuePlaying()
    testPlayer.setCurrentIndex(0)
    testQueueHandler.movePlayable(
      from: PlayerIndex(queueType: .user, index: 1),
      to: PlayerIndex(queueType: .user, index: 0)
    )
    checkCurrentlyPlaying(idToBe: 5)
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [0])
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [1, 2, 3, 4])
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [7, 6, 8])
    checkQueueInfoConsistency()

    prepareWithWaitingQueuePlaying()
    testPlayer.setCurrentIndex(-1)
    testQueueHandler.movePlayable(
      from: PlayerIndex(queueType: .user, index: 0),
      to: PlayerIndex(queueType: .user, index: 1)
    )
    checkCurrentlyPlaying(idToBe: 5)
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [Int]())
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [0, 1, 2, 3, 4])
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [7, 6, 8])
    checkQueueInfoConsistency()
  }

  func testMove_PrevNext_noWaitingQueuePlaying() {
    prepareNoWaitingQueuePlaying()
    testPlayer.setCurrentIndex(2)
    testQueueHandler.movePlayable(
      from: PlayerIndex(queueType: .prev, index: 0),
      to: PlayerIndex(queueType: .next, index: 1)
    )
    checkCurrentlyPlaying(idToBe: 2)
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [1])
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [3, 0, 4])
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [5, 6, 7, 8])
    checkQueueInfoConsistency()

    prepareNoWaitingQueuePlaying()
    testPlayer.setCurrentIndex(2)
    testQueueHandler.movePlayable(
      from: PlayerIndex(queueType: .prev, index: 1),
      to: PlayerIndex(queueType: .next, index: 0)
    )
    checkCurrentlyPlaying(idToBe: 2)
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [0])
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [1, 3, 4])
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [5, 6, 7, 8])
    checkQueueInfoConsistency()

    prepareNoWaitingQueuePlaying()
    testPlayer.setCurrentIndex(1)
    testQueueHandler.movePlayable(
      from: PlayerIndex(queueType: .prev, index: 0),
      to: PlayerIndex(queueType: .next, index: 2)
    )
    checkCurrentlyPlaying(idToBe: 1)
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [Int]())
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [2, 3, 0, 4])
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [5, 6, 7, 8])
    checkQueueInfoConsistency()

    prepareNoWaitingQueuePlaying()
    testPlayer.setCurrentIndex(3)
    testQueueHandler.movePlayable(
      from: PlayerIndex(queueType: .prev, index: 1),
      to: PlayerIndex(queueType: .next, index: 0)
    )
    checkCurrentlyPlaying(idToBe: 3)
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [0, 2])
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [1, 4])
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [5, 6, 7, 8])
    checkQueueInfoConsistency()

    prepareNoWaitingQueuePlaying()
    testPlayer.setCurrentIndex(3)
    testQueueHandler.movePlayable(
      from: PlayerIndex(queueType: .prev, index: 1),
      to: PlayerIndex(queueType: .next, index: 1)
    )
    checkCurrentlyPlaying(idToBe: 3)
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [0, 2])
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [4, 1])
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [5, 6, 7, 8])
    checkQueueInfoConsistency()

    prepareNoWaitingQueuePlaying()
    testPlayer.setCurrentIndex(4)
    testQueueHandler.movePlayable(
      from: PlayerIndex(queueType: .prev, index: 0),
      to: PlayerIndex(queueType: .next, index: 0)
    )
    checkCurrentlyPlaying(idToBe: 4)
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [1, 2, 3])
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [0])
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [5, 6, 7, 8])
    checkQueueInfoConsistency()
  }

  func testMove_PrevNext_withWaitingQueuePlaying() {
    prepareWithWaitingQueuePlaying()
    testPlayer.setCurrentIndex(2)
    testQueueHandler.movePlayable(
      from: PlayerIndex(queueType: .prev, index: 0),
      to: PlayerIndex(queueType: .next, index: 1)
    )
    checkCurrentlyPlaying(idToBe: 5)
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [1, 2])
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [3, 0, 4])
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [6, 7, 8])
    checkQueueInfoConsistency()

    prepareWithWaitingQueuePlaying()
    testPlayer.setCurrentIndex(2)
    testQueueHandler.movePlayable(
      from: PlayerIndex(queueType: .prev, index: 1),
      to: PlayerIndex(queueType: .next, index: 0)
    )
    checkCurrentlyPlaying(idToBe: 5)
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [0, 2])
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [1, 3, 4])
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [6, 7, 8])
    checkQueueInfoConsistency()

    prepareWithWaitingQueuePlaying()
    testPlayer.setCurrentIndex(1)
    testQueueHandler.movePlayable(
      from: PlayerIndex(queueType: .prev, index: 1),
      to: PlayerIndex(queueType: .next, index: 0)
    )
    checkCurrentlyPlaying(idToBe: 5)
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [0])
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [1, 2, 3, 4])
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [6, 7, 8])
    checkQueueInfoConsistency()

    prepareWithWaitingQueuePlaying()
    testPlayer.setCurrentIndex(3)
    testQueueHandler.movePlayable(
      from: PlayerIndex(queueType: .prev, index: 1),
      to: PlayerIndex(queueType: .next, index: 0)
    )
    checkCurrentlyPlaying(idToBe: 5)
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [0, 2, 3])
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [1, 4])
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [6, 7, 8])
    checkQueueInfoConsistency()

    prepareWithWaitingQueuePlaying()
    testPlayer.setCurrentIndex(3)
    testQueueHandler.movePlayable(
      from: PlayerIndex(queueType: .prev, index: 3),
      to: PlayerIndex(queueType: .next, index: 1)
    )
    checkCurrentlyPlaying(idToBe: 5)
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [0, 1, 2])
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [4, 3])
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [6, 7, 8])
    checkQueueInfoConsistency()

    prepareWithWaitingQueuePlaying()
    testPlayer.setCurrentIndex(4)
    testQueueHandler.movePlayable(
      from: PlayerIndex(queueType: .prev, index: 0),
      to: PlayerIndex(queueType: .next, index: 0)
    )
    checkCurrentlyPlaying(idToBe: 5)
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [1, 2, 3, 4])
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [0])
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [6, 7, 8])
    checkQueueInfoConsistency()
  }

  func testMove_NextPrev_noWaitingQueuePlaying() {
    prepareNoWaitingQueuePlaying()
    testPlayer.setCurrentIndex(2)
    testQueueHandler.movePlayable(
      from: PlayerIndex(queueType: .next, index: 0),
      to: PlayerIndex(queueType: .prev, index: 1)
    )
    checkCurrentlyPlaying(idToBe: 2)
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [0, 3, 1])
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [4])
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [5, 6, 7, 8])
    checkQueueInfoConsistency()

    prepareNoWaitingQueuePlaying()
    testPlayer.setCurrentIndex(2)
    testQueueHandler.movePlayable(
      from: PlayerIndex(queueType: .next, index: 1),
      to: PlayerIndex(queueType: .prev, index: 0)
    )
    checkCurrentlyPlaying(idToBe: 2)
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [4, 0, 1])
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [3])
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [5, 6, 7, 8])
    checkQueueInfoConsistency()

    prepareNoWaitingQueuePlaying()
    testPlayer.setCurrentIndex(3)
    testQueueHandler.movePlayable(
      from: PlayerIndex(queueType: .next, index: 0),
      to: PlayerIndex(queueType: .prev, index: 2)
    )
    checkCurrentlyPlaying(idToBe: 3)
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [0, 1, 4, 2])
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [Int]())
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [5, 6, 7, 8])
    checkQueueInfoConsistency()

    prepareNoWaitingQueuePlaying()
    testPlayer.setCurrentIndex(1)
    testQueueHandler.movePlayable(
      from: PlayerIndex(queueType: .next, index: 1),
      to: PlayerIndex(queueType: .prev, index: 0)
    )
    checkCurrentlyPlaying(idToBe: 1)
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [3, 0])
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [2, 4])
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [5, 6, 7, 8])
    checkQueueInfoConsistency()

    prepareNoWaitingQueuePlaying()
    testPlayer.setCurrentIndex(1)
    testQueueHandler.movePlayable(
      from: PlayerIndex(queueType: .next, index: 1),
      to: PlayerIndex(queueType: .prev, index: 1)
    )
    checkCurrentlyPlaying(idToBe: 1)
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [0, 3])
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [2, 4])
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [5, 6, 7, 8])
    checkQueueInfoConsistency()

    prepareNoWaitingQueuePlaying()
    testPlayer.setCurrentIndex(0)
    testQueueHandler.movePlayable(
      from: PlayerIndex(queueType: .next, index: 0),
      to: PlayerIndex(queueType: .prev, index: 0)
    )
    checkCurrentlyPlaying(idToBe: 0)
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [1])
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [2, 3, 4])
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [5, 6, 7, 8])
    checkQueueInfoConsistency()

    prepareNoWaitingQueuePlaying()
    testPlayer.setCurrentIndex(0)
    testQueueHandler.movePlayable(
      from: PlayerIndex(queueType: .next, index: 3),
      to: PlayerIndex(queueType: .prev, index: 0)
    )
    checkCurrentlyPlaying(idToBe: 0)
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [4])
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [1, 2, 3])
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [5, 6, 7, 8])
    checkQueueInfoConsistency()
  }

  func testMove_NextPrev_withWaitingQueuePlaying() {
    prepareWithWaitingQueuePlaying()
    testPlayer.setCurrentIndex(2)
    testQueueHandler.movePlayable(
      from: PlayerIndex(queueType: .next, index: 0),
      to: PlayerIndex(queueType: .prev, index: 1)
    )
    checkCurrentlyPlaying(idToBe: 5)
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [0, 3, 1, 2])
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [4])
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [6, 7, 8])
    checkQueueInfoConsistency()

    prepareWithWaitingQueuePlaying()
    testPlayer.setCurrentIndex(2)
    testQueueHandler.movePlayable(
      from: PlayerIndex(queueType: .next, index: 1),
      to: PlayerIndex(queueType: .prev, index: 0)
    )
    checkCurrentlyPlaying(idToBe: 5)
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [4, 0, 1, 2])
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [3])
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [6, 7, 8])
    checkQueueInfoConsistency()

    prepareWithWaitingQueuePlaying()
    testPlayer.setCurrentIndex(1)
    testQueueHandler.movePlayable(
      from: PlayerIndex(queueType: .next, index: 1),
      to: PlayerIndex(queueType: .prev, index: 0)
    )
    checkCurrentlyPlaying(idToBe: 5)
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [3, 0, 1])
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [2, 4])
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [6, 7, 8])
    checkQueueInfoConsistency()

    prepareWithWaitingQueuePlaying()
    testPlayer.setCurrentIndex(3)
    testQueueHandler.movePlayable(
      from: PlayerIndex(queueType: .next, index: 0),
      to: PlayerIndex(queueType: .prev, index: 4)
    )
    checkCurrentlyPlaying(idToBe: 5)
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [0, 1, 2, 3, 4])
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [Int]())
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [6, 7, 8])
    checkQueueInfoConsistency()

    prepareWithWaitingQueuePlaying()
    testPlayer.setCurrentIndex(3)
    testQueueHandler.movePlayable(
      from: PlayerIndex(queueType: .next, index: 0),
      to: PlayerIndex(queueType: .prev, index: 3)
    )
    checkCurrentlyPlaying(idToBe: 5)
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [0, 1, 2, 4, 3])
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [Int]())
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [6, 7, 8])
    checkQueueInfoConsistency()

    prepareWithWaitingQueuePlaying()
    testPlayer.setCurrentIndex(0)
    testQueueHandler.movePlayable(
      from: PlayerIndex(queueType: .next, index: 3),
      to: PlayerIndex(queueType: .prev, index: 0)
    )
    checkCurrentlyPlaying(idToBe: 5)
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [4, 0])
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [1, 2, 3])
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [6, 7, 8])
    checkQueueInfoConsistency()

    prepareWithWaitingQueuePlaying()
    testPlayer.setCurrentIndex(0)
    testQueueHandler.movePlayable(
      from: PlayerIndex(queueType: .next, index: 3),
      to: PlayerIndex(queueType: .prev, index: 1)
    )
    checkCurrentlyPlaying(idToBe: 5)
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [0, 4])
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [1, 2, 3])
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [6, 7, 8])
    checkQueueInfoConsistency()

    prepareWithWaitingQueuePlaying()
    testPlayer.setCurrentIndex(-1)
    testQueueHandler.movePlayable(
      from: PlayerIndex(queueType: .next, index: 0),
      to: PlayerIndex(queueType: .prev, index: 0)
    )
    checkCurrentlyPlaying(idToBe: 5)
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [0])
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [1, 2, 3, 4])
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [6, 7, 8])
    checkQueueInfoConsistency()

    prepareWithWaitingQueuePlaying()
    testPlayer.setCurrentIndex(-1)
    testQueueHandler.movePlayable(
      from: PlayerIndex(queueType: .next, index: 4),
      to: PlayerIndex(queueType: .prev, index: 0)
    )
    checkCurrentlyPlaying(idToBe: 5)
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [4])
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [0, 1, 2, 3])
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [6, 7, 8])
    checkQueueInfoConsistency()
  }

  func testMove_WaitNext_noWaitingQueuePlaying() {
    prepareNoWaitingQueuePlaying()
    testPlayer.setCurrentIndex(2)
    testQueueHandler.movePlayable(
      from: PlayerIndex(queueType: .user, index: 0),
      to: PlayerIndex(queueType: .next, index: 1)
    )
    checkCurrentlyPlaying(idToBe: 2)
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [0, 1])
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [3, 5, 4])
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [6, 7, 8])
    checkQueueInfoConsistency()

    prepareNoWaitingQueuePlaying()
    testPlayer.setCurrentIndex(2)
    testQueueHandler.movePlayable(
      from: PlayerIndex(queueType: .user, index: 1),
      to: PlayerIndex(queueType: .next, index: 0)
    )
    checkCurrentlyPlaying(idToBe: 2)
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [0, 1])
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [6, 3, 4])
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [5, 7, 8])
    checkQueueInfoConsistency()

    prepareNoWaitingQueuePlaying()
    testPlayer.setCurrentIndex(3)
    testQueueHandler.movePlayable(
      from: PlayerIndex(queueType: .user, index: 3),
      to: PlayerIndex(queueType: .next, index: 1)
    )
    checkCurrentlyPlaying(idToBe: 3)
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [0, 1, 2])
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [4, 8])
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [5, 6, 7])
    checkQueueInfoConsistency()

    prepareNoWaitingQueuePlaying()
    testPlayer.setCurrentIndex(4)
    testQueueHandler.movePlayable(
      from: PlayerIndex(queueType: .user, index: 1),
      to: PlayerIndex(queueType: .next, index: 0)
    )
    checkCurrentlyPlaying(idToBe: 4)
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [0, 1, 2, 3])
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [6])
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [5, 7, 8])
    checkQueueInfoConsistency()

    prepareNoWaitingQueuePlaying()
    testPlayer.setCurrentIndex(3)
    testQueueHandler.removePlayable(at: PlayerIndex(queueType: .user, index: 0))
    testQueueHandler.removePlayable(at: PlayerIndex(queueType: .user, index: 0))
    testQueueHandler.removePlayable(at: PlayerIndex(queueType: .user, index: 0))
    testQueueHandler.movePlayable(
      from: PlayerIndex(queueType: .user, index: 0),
      to: PlayerIndex(queueType: .next, index: 1)
    )
    checkCurrentlyPlaying(idToBe: 3)
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [0, 1, 2])
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [4, 8])
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [Int]())
    checkQueueInfoConsistency()

    prepareNoWaitingQueuePlaying()
    testPlayer.setCurrentIndex(3)
    testQueueHandler.removePlayable(at: PlayerIndex(queueType: .user, index: 0))
    testQueueHandler.removePlayable(at: PlayerIndex(queueType: .user, index: 0))
    testQueueHandler.movePlayable(
      from: PlayerIndex(queueType: .user, index: 1),
      to: PlayerIndex(queueType: .next, index: 0)
    )
    checkCurrentlyPlaying(idToBe: 3)
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [0, 1, 2])
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [8, 4])
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [7])
    checkQueueInfoConsistency()

    prepareNoWaitingQueuePlaying()
    testPlayer.setCurrentIndex(0)
    testQueueHandler.movePlayable(
      from: PlayerIndex(queueType: .user, index: 2),
      to: PlayerIndex(queueType: .next, index: 4)
    )
    checkCurrentlyPlaying(idToBe: 0)
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [Int]())
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [1, 2, 3, 4, 7])
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [5, 6, 8])
    checkQueueInfoConsistency()

    prepareNoWaitingQueuePlaying()
    testPlayer.setCurrentIndex(0)
    testQueueHandler.movePlayable(
      from: PlayerIndex(queueType: .user, index: 2),
      to: PlayerIndex(queueType: .next, index: 3)
    )
    checkCurrentlyPlaying(idToBe: 0)
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [Int]())
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [1, 2, 3, 7, 4])
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [5, 6, 8])
    checkQueueInfoConsistency()
  }

  func testMove_WaitNext_withWaitingQueuePlaying() {
    prepareWithWaitingQueuePlaying()
    testPlayer.setCurrentIndex(2)
    testQueueHandler.movePlayable(
      from: PlayerIndex(queueType: .user, index: 0),
      to: PlayerIndex(queueType: .next, index: 1)
    )
    checkCurrentlyPlaying(idToBe: 5)
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [0, 1, 2])
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [3, 6, 4])
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [7, 8])
    checkQueueInfoConsistency()

    prepareWithWaitingQueuePlaying()
    testPlayer.setCurrentIndex(2)
    testQueueHandler.movePlayable(
      from: PlayerIndex(queueType: .user, index: 1),
      to: PlayerIndex(queueType: .next, index: 0)
    )
    checkCurrentlyPlaying(idToBe: 5)
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [0, 1, 2])
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [7, 3, 4])
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [6, 8])
    checkQueueInfoConsistency()

    prepareWithWaitingQueuePlaying()
    testPlayer.setCurrentIndex(3)
    testQueueHandler.movePlayable(
      from: PlayerIndex(queueType: .user, index: 2),
      to: PlayerIndex(queueType: .next, index: 1)
    )
    checkCurrentlyPlaying(idToBe: 5)
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [0, 1, 2, 3])
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [4, 8])
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [6, 7])
    checkQueueInfoConsistency()

    prepareWithWaitingQueuePlaying()
    testPlayer.setCurrentIndex(4)
    testQueueHandler.movePlayable(
      from: PlayerIndex(queueType: .user, index: 1),
      to: PlayerIndex(queueType: .next, index: 0)
    )
    checkCurrentlyPlaying(idToBe: 5)
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [0, 1, 2, 3, 4])
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [7])
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [6, 8])
    checkQueueInfoConsistency()

    prepareWithWaitingQueuePlaying()
    testPlayer.setCurrentIndex(-1)
    testQueueHandler.removePlayable(at: PlayerIndex(queueType: .user, index: 0))
    testQueueHandler.removePlayable(at: PlayerIndex(queueType: .user, index: 0))
    testQueueHandler.movePlayable(
      from: PlayerIndex(queueType: .user, index: 0),
      to: PlayerIndex(queueType: .next, index: 0)
    )
    checkCurrentlyPlaying(idToBe: 5)
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [Int]())
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [8, 0, 1, 2, 3, 4])
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [Int]())
    checkQueueInfoConsistency()

    prepareWithWaitingQueuePlaying()
    testPlayer.setCurrentIndex(-1)
    testQueueHandler.removePlayable(at: PlayerIndex(queueType: .user, index: 0))
    testQueueHandler.removePlayable(at: PlayerIndex(queueType: .user, index: 0))
    testQueueHandler.movePlayable(
      from: PlayerIndex(queueType: .user, index: 0),
      to: PlayerIndex(queueType: .next, index: 5)
    )
    checkCurrentlyPlaying(idToBe: 5)
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [Int]())
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [0, 1, 2, 3, 4, 8])
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [Int]())
    checkQueueInfoConsistency()

    prepareWithWaitingQueuePlaying()
    testPlayer.setCurrentIndex(-1)
    testQueueHandler.removePlayable(at: PlayerIndex(queueType: .user, index: 0))
    testQueueHandler.movePlayable(
      from: PlayerIndex(queueType: .user, index: 1),
      to: PlayerIndex(queueType: .next, index: 3)
    )
    checkCurrentlyPlaying(idToBe: 5)
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [Int]())
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [0, 1, 2, 8, 3, 4])
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [7])
    checkQueueInfoConsistency()

    prepareWithWaitingQueuePlaying()
    testPlayer.setCurrentIndex(0)
    testQueueHandler.movePlayable(
      from: PlayerIndex(queueType: .user, index: 2),
      to: PlayerIndex(queueType: .next, index: 0)
    )
    checkCurrentlyPlaying(idToBe: 5)
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [0])
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [8, 1, 2, 3, 4])
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [6, 7])
    checkQueueInfoConsistency()
  }

  func testMove_WaitPrev_noWaitingQueuePlaying() {
    prepareNoWaitingQueuePlaying()
    testPlayer.setCurrentIndex(2)
    testQueueHandler.movePlayable(
      from: PlayerIndex(queueType: .user, index: 0),
      to: PlayerIndex(queueType: .prev, index: 1)
    )
    checkCurrentlyPlaying(idToBe: 2)
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [0, 5, 1])
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [3, 4])
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [6, 7, 8])
    checkQueueInfoConsistency()

    prepareNoWaitingQueuePlaying()
    testPlayer.setCurrentIndex(2)
    testQueueHandler.movePlayable(
      from: PlayerIndex(queueType: .user, index: 1),
      to: PlayerIndex(queueType: .prev, index: 0)
    )
    checkCurrentlyPlaying(idToBe: 2)
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [6, 0, 1])
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [3, 4])
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [5, 7, 8])
    checkQueueInfoConsistency()

    prepareNoWaitingQueuePlaying()
    testPlayer.setCurrentIndex(2)
    testQueueHandler.movePlayable(
      from: PlayerIndex(queueType: .user, index: 3),
      to: PlayerIndex(queueType: .prev, index: 2)
    )
    checkCurrentlyPlaying(idToBe: 2)
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [0, 1, 8])
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [3, 4])
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [5, 6, 7])
    checkQueueInfoConsistency()

    prepareNoWaitingQueuePlaying()
    testPlayer.setCurrentIndex(4)
    testQueueHandler.movePlayable(
      from: PlayerIndex(queueType: .user, index: 1),
      to: PlayerIndex(queueType: .prev, index: 0)
    )
    checkCurrentlyPlaying(idToBe: 4)
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [6, 0, 1, 2, 3])
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [Int]())
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [5, 7, 8])
    checkQueueInfoConsistency()

    prepareNoWaitingQueuePlaying()
    testPlayer.setCurrentIndex(0)
    testQueueHandler.removePlayable(at: PlayerIndex(queueType: .user, index: 0))
    testQueueHandler.removePlayable(at: PlayerIndex(queueType: .user, index: 0))
    testQueueHandler.removePlayable(at: PlayerIndex(queueType: .user, index: 0))
    testQueueHandler.movePlayable(
      from: PlayerIndex(queueType: .user, index: 0),
      to: PlayerIndex(queueType: .prev, index: 0)
    )
    checkCurrentlyPlaying(idToBe: 0)
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [8])
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [1, 2, 3, 4])
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [Int]())
    checkQueueInfoConsistency()
  }

  func testMove_WaitPrev_withWaitingQueuePlaying() {
    prepareWithWaitingQueuePlaying()
    testPlayer.setCurrentIndex(2)
    testQueueHandler.movePlayable(
      from: PlayerIndex(queueType: .user, index: 0),
      to: PlayerIndex(queueType: .prev, index: 1)
    )
    checkCurrentlyPlaying(idToBe: 5)
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [0, 6, 1, 2])
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [3, 4])
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [7, 8])
    checkQueueInfoConsistency()

    prepareWithWaitingQueuePlaying()
    testPlayer.setCurrentIndex(2)
    testQueueHandler.movePlayable(
      from: PlayerIndex(queueType: .user, index: 1),
      to: PlayerIndex(queueType: .prev, index: 0)
    )
    checkCurrentlyPlaying(idToBe: 5)
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [7, 0, 1, 2])
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [3, 4])
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [6, 8])
    checkQueueInfoConsistency()

    prepareWithWaitingQueuePlaying()
    testPlayer.setCurrentIndex(1)
    testQueueHandler.movePlayable(
      from: PlayerIndex(queueType: .user, index: 2),
      to: PlayerIndex(queueType: .prev, index: 1)
    )
    checkCurrentlyPlaying(idToBe: 5)
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [0, 8, 1])
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [2, 3, 4])
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [6, 7])
    checkQueueInfoConsistency()

    prepareWithWaitingQueuePlaying()
    testPlayer.setCurrentIndex(4)
    testQueueHandler.movePlayable(
      from: PlayerIndex(queueType: .user, index: 1),
      to: PlayerIndex(queueType: .prev, index: 0)
    )
    checkCurrentlyPlaying(idToBe: 5)
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [7, 0, 1, 2, 3, 4])
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [Int]())
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [6, 8])
    checkQueueInfoConsistency()

    prepareWithWaitingQueuePlaying()
    testPlayer.setCurrentIndex(4)
    testQueueHandler.movePlayable(
      from: PlayerIndex(queueType: .user, index: 2),
      to: PlayerIndex(queueType: .prev, index: 5)
    )
    checkCurrentlyPlaying(idToBe: 5)
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [0, 1, 2, 3, 4, 8])
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [Int]())
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [6, 7])
    checkQueueInfoConsistency()

    prepareWithWaitingQueuePlaying()
    testPlayer.setCurrentIndex(4)
    testQueueHandler.movePlayable(
      from: PlayerIndex(queueType: .user, index: 1),
      to: PlayerIndex(queueType: .prev, index: 4)
    )
    checkCurrentlyPlaying(idToBe: 5)
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [0, 1, 2, 3, 7, 4])
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [Int]())
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [6, 8])
    checkQueueInfoConsistency()

    prepareWithWaitingQueuePlaying()
    testPlayer.setCurrentIndex(-1)
    testQueueHandler.removePlayable(at: PlayerIndex(queueType: .user, index: 0))
    testQueueHandler.removePlayable(at: PlayerIndex(queueType: .user, index: 0))
    testQueueHandler.movePlayable(
      from: PlayerIndex(queueType: .user, index: 0),
      to: PlayerIndex(queueType: .prev, index: 0)
    )
    checkCurrentlyPlaying(idToBe: 5)
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [8])
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [0, 1, 2, 3, 4])
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [Int]())
    checkQueueInfoConsistency()

    prepareWithWaitingQueuePlaying()
    testPlayer.setCurrentIndex(1)
    testQueueHandler.removePlayable(at: PlayerIndex(queueType: .user, index: 0))
    testQueueHandler.movePlayable(
      from: PlayerIndex(queueType: .user, index: 1),
      to: PlayerIndex(queueType: .prev, index: 1)
    )
    checkCurrentlyPlaying(idToBe: 5)
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [0, 8, 1])
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [2, 3, 4])
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [7])
    checkQueueInfoConsistency()

    prepareWithWaitingQueuePlaying()
    testPlayer.setCurrentIndex(0)
    testQueueHandler.movePlayable(
      from: PlayerIndex(queueType: .user, index: 2),
      to: PlayerIndex(queueType: .prev, index: 0)
    )
    checkCurrentlyPlaying(idToBe: 5)
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [8, 0])
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [1, 2, 3, 4])
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [6, 7])
    checkQueueInfoConsistency()
  }

  func testMove_PrevWait_noWaitingQueuePlaying() {
    prepareNoWaitingQueuePlaying()
    testPlayer.setCurrentIndex(2)
    testQueueHandler.movePlayable(
      from: PlayerIndex(queueType: .prev, index: 0),
      to: PlayerIndex(queueType: .user, index: 1)
    )
    checkCurrentlyPlaying(idToBe: 2)
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [1])
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [3, 4])
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [5, 0, 6, 7, 8])
    checkQueueInfoConsistency()

    prepareNoWaitingQueuePlaying()
    testPlayer.setCurrentIndex(2)
    testQueueHandler.movePlayable(
      from: PlayerIndex(queueType: .prev, index: 1),
      to: PlayerIndex(queueType: .user, index: 0)
    )
    checkCurrentlyPlaying(idToBe: 2)
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [0])
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [3, 4])
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [1, 5, 6, 7, 8])
    checkQueueInfoConsistency()

    prepareNoWaitingQueuePlaying()
    testPlayer.setCurrentIndex(3)
    testQueueHandler.movePlayable(
      from: PlayerIndex(queueType: .prev, index: 2),
      to: PlayerIndex(queueType: .user, index: 2)
    )
    checkCurrentlyPlaying(idToBe: 3)
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [0, 1])
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [4])
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [5, 6, 2, 7, 8])
    checkQueueInfoConsistency()

    prepareNoWaitingQueuePlaying()
    testPlayer.setCurrentIndex(4)
    testQueueHandler.movePlayable(
      from: PlayerIndex(queueType: .prev, index: 0),
      to: PlayerIndex(queueType: .user, index: 4)
    )
    checkCurrentlyPlaying(idToBe: 4)
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [1, 2, 3])
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [Int]())
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [5, 6, 7, 8, 0])
    checkQueueInfoConsistency()

    prepareNoWaitingQueuePlaying()
    testPlayer.setCurrentIndex(1)
    testQueueHandler.removePlayable(at: PlayerIndex(queueType: .user, index: 0))
    testQueueHandler.removePlayable(at: PlayerIndex(queueType: .user, index: 0))
    testQueueHandler.removePlayable(at: PlayerIndex(queueType: .user, index: 0))
    testQueueHandler.removePlayable(at: PlayerIndex(queueType: .user, index: 0))
    testQueueHandler.movePlayable(
      from: PlayerIndex(queueType: .prev, index: 0),
      to: PlayerIndex(queueType: .user, index: 0)
    )
    checkCurrentlyPlaying(idToBe: 1)
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [Int]())
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [2, 3, 4])
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [0])
    checkQueueInfoConsistency()
  }

  func testMove_PrevWait_withWaitingQueuePlaying() {
    prepareWithWaitingQueuePlaying()
    testPlayer.setCurrentIndex(2)
    testQueueHandler.movePlayable(
      from: PlayerIndex(queueType: .prev, index: 0),
      to: PlayerIndex(queueType: .user, index: 1)
    )
    checkCurrentlyPlaying(idToBe: 5)
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [1, 2])
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [3, 4])
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [6, 0, 7, 8])
    checkQueueInfoConsistency()

    prepareWithWaitingQueuePlaying()
    testPlayer.setCurrentIndex(2)
    testQueueHandler.movePlayable(
      from: PlayerIndex(queueType: .prev, index: 1),
      to: PlayerIndex(queueType: .user, index: 0)
    )
    checkCurrentlyPlaying(idToBe: 5)
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [0, 2])
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [3, 4])
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [1, 6, 7, 8])
    checkQueueInfoConsistency()

    prepareWithWaitingQueuePlaying()
    testPlayer.setCurrentIndex(3)
    testQueueHandler.movePlayable(
      from: PlayerIndex(queueType: .prev, index: 2),
      to: PlayerIndex(queueType: .user, index: 1)
    )
    checkCurrentlyPlaying(idToBe: 5)
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [0, 1, 3])
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [4])
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [6, 2, 7, 8])
    checkQueueInfoConsistency()

    prepareWithWaitingQueuePlaying()
    testPlayer.setCurrentIndex(4)
    testQueueHandler.movePlayable(
      from: PlayerIndex(queueType: .prev, index: 4),
      to: PlayerIndex(queueType: .user, index: 0)
    )
    checkCurrentlyPlaying(idToBe: 5)
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [0, 1, 2, 3])
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [Int]())
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [4, 6, 7, 8])
    checkQueueInfoConsistency()

    prepareWithWaitingQueuePlaying()
    testPlayer.setCurrentIndex(4)
    testQueueHandler.movePlayable(
      from: PlayerIndex(queueType: .prev, index: 4),
      to: PlayerIndex(queueType: .user, index: 3)
    )
    checkCurrentlyPlaying(idToBe: 5)
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [0, 1, 2, 3])
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [Int]())
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [6, 7, 8, 4])
    checkQueueInfoConsistency()

    prepareWithWaitingQueuePlaying()
    testPlayer.setCurrentIndex(0)
    testQueueHandler.movePlayable(
      from: PlayerIndex(queueType: .prev, index: 0),
      to: PlayerIndex(queueType: .user, index: 0)
    )
    checkCurrentlyPlaying(idToBe: 5)
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [Int]())
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [1, 2, 3, 4])
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [0, 6, 7, 8])
    checkQueueInfoConsistency()

    prepareWithWaitingQueuePlaying()
    testPlayer.setCurrentIndex(1)
    testQueueHandler.removePlayable(at: PlayerIndex(queueType: .user, index: 0))
    testQueueHandler.removePlayable(at: PlayerIndex(queueType: .user, index: 0))
    testQueueHandler.removePlayable(at: PlayerIndex(queueType: .user, index: 0))
    testQueueHandler.movePlayable(
      from: PlayerIndex(queueType: .prev, index: 1),
      to: PlayerIndex(queueType: .user, index: 0)
    )
    checkCurrentlyPlaying(idToBe: 5)
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [0])
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [2, 3, 4])
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [1])
    checkQueueInfoConsistency()
  }

  func testMove_NextWait_noWaitingQueuePlaying() {
    prepareNoWaitingQueuePlaying()
    testPlayer.setCurrentIndex(2)
    testQueueHandler.movePlayable(
      from: PlayerIndex(queueType: .next, index: 0),
      to: PlayerIndex(queueType: .user, index: 1)
    )
    checkCurrentlyPlaying(idToBe: 2)
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [0, 1])
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [4])
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [5, 3, 6, 7, 8])
    checkQueueInfoConsistency()

    prepareNoWaitingQueuePlaying()
    testPlayer.setCurrentIndex(2)
    testQueueHandler.movePlayable(
      from: PlayerIndex(queueType: .next, index: 1),
      to: PlayerIndex(queueType: .user, index: 0)
    )
    checkCurrentlyPlaying(idToBe: 2)
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [0, 1])
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [3])
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [4, 5, 6, 7, 8])
    checkQueueInfoConsistency()

    prepareNoWaitingQueuePlaying()
    testPlayer.setCurrentIndex(3)
    testQueueHandler.movePlayable(
      from: PlayerIndex(queueType: .next, index: 0),
      to: PlayerIndex(queueType: .user, index: 2)
    )
    checkCurrentlyPlaying(idToBe: 3)
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [0, 1, 2])
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [Int]())
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [5, 6, 4, 7, 8])
    checkQueueInfoConsistency()

    prepareNoWaitingQueuePlaying()
    testPlayer.setCurrentIndex(1)
    testQueueHandler.movePlayable(
      from: PlayerIndex(queueType: .next, index: 2),
      to: PlayerIndex(queueType: .user, index: 4)
    )
    checkCurrentlyPlaying(idToBe: 1)
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [0])
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [2, 3])
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [5, 6, 7, 8, 4])
    checkQueueInfoConsistency()

    prepareNoWaitingQueuePlaying()
    testPlayer.setCurrentIndex(1)
    testQueueHandler.removePlayable(at: PlayerIndex(queueType: .user, index: 0))
    testQueueHandler.removePlayable(at: PlayerIndex(queueType: .user, index: 0))
    testQueueHandler.removePlayable(at: PlayerIndex(queueType: .user, index: 0))
    testQueueHandler.removePlayable(at: PlayerIndex(queueType: .user, index: 0))
    testQueueHandler.movePlayable(
      from: PlayerIndex(queueType: .next, index: 0),
      to: PlayerIndex(queueType: .user, index: 0)
    )
    checkCurrentlyPlaying(idToBe: 1)
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [0])
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [3, 4])
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [2])
    checkQueueInfoConsistency()

    prepareNoWaitingQueuePlaying()
    testPlayer.setCurrentIndex(0)
    testQueueHandler.removePlayable(at: PlayerIndex(queueType: .user, index: 0))
    testQueueHandler.movePlayable(
      from: PlayerIndex(queueType: .next, index: 0),
      to: PlayerIndex(queueType: .user, index: 0)
    )
    checkCurrentlyPlaying(idToBe: 0)
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [Int]())
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [2, 3, 4])
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [1, 6, 7, 8])
    checkQueueInfoConsistency()
  }

  func testMove_NextWait_withWaitingQueuePlaying() {
    prepareWithWaitingQueuePlaying()
    testPlayer.setCurrentIndex(2)
    testQueueHandler.movePlayable(
      from: PlayerIndex(queueType: .next, index: 0),
      to: PlayerIndex(queueType: .user, index: 1)
    )
    checkCurrentlyPlaying(idToBe: 5)
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [0, 1, 2])
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [4])
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [6, 3, 7, 8])
    checkQueueInfoConsistency()

    prepareWithWaitingQueuePlaying()
    testPlayer.setCurrentIndex(2)
    testQueueHandler.movePlayable(
      from: PlayerIndex(queueType: .next, index: 1),
      to: PlayerIndex(queueType: .user, index: 0)
    )
    checkCurrentlyPlaying(idToBe: 5)
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [0, 1, 2])
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [3])
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [4, 6, 7, 8])
    checkQueueInfoConsistency()

    prepareWithWaitingQueuePlaying()
    testPlayer.setCurrentIndex(1)
    testQueueHandler.movePlayable(
      from: PlayerIndex(queueType: .next, index: 2),
      to: PlayerIndex(queueType: .user, index: 1)
    )
    checkCurrentlyPlaying(idToBe: 5)
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [0, 1])
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [2, 3])
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [6, 4, 7, 8])
    checkQueueInfoConsistency()

    prepareWithWaitingQueuePlaying()
    testPlayer.setCurrentIndex(0)
    testQueueHandler.movePlayable(
      from: PlayerIndex(queueType: .next, index: 3),
      to: PlayerIndex(queueType: .user, index: 0)
    )
    checkCurrentlyPlaying(idToBe: 5)
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [0])
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [1, 2, 3])
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [4, 6, 7, 8])
    checkQueueInfoConsistency()

    prepareWithWaitingQueuePlaying()
    testPlayer.setCurrentIndex(3)
    testQueueHandler.movePlayable(
      from: PlayerIndex(queueType: .next, index: 0),
      to: PlayerIndex(queueType: .user, index: 3)
    )
    checkCurrentlyPlaying(idToBe: 5)
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [0, 1, 2, 3])
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [Int]())
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [6, 7, 8, 4])
    checkQueueInfoConsistency()

    prepareWithWaitingQueuePlaying()
    testPlayer.setCurrentIndex(-1)
    testQueueHandler.movePlayable(
      from: PlayerIndex(queueType: .next, index: 0),
      to: PlayerIndex(queueType: .user, index: 0)
    )
    checkCurrentlyPlaying(idToBe: 5)
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [Int]())
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [1, 2, 3, 4])
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [0, 6, 7, 8])
    checkQueueInfoConsistency()

    prepareWithWaitingQueuePlaying()
    testPlayer.setCurrentIndex(-1)
    testQueueHandler.removePlayable(at: PlayerIndex(queueType: .user, index: 0))
    testQueueHandler.removePlayable(at: PlayerIndex(queueType: .user, index: 0))
    testQueueHandler.removePlayable(at: PlayerIndex(queueType: .user, index: 0))
    testQueueHandler.movePlayable(
      from: PlayerIndex(queueType: .next, index: 0),
      to: PlayerIndex(queueType: .user, index: 0)
    )
    checkCurrentlyPlaying(idToBe: 5)
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [Int]())
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [1, 2, 3, 4])
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [0])
    checkQueueInfoConsistency()
  }

  func testInsertPodcastQueue_playerModeMusic_NoWaitingQueuePlaying() {
    prepareNoWaitingQueuePlaying()
    testPlayer.setCurrentIndex(2)
    checkCurrentlyPlaying(idToBe: 2)
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [0, 1])
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [3, 4])
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [5, 6, 7, 8])
    checkQueueItems(queue: testPlayer.podcastQueue.playables, seedIds: [Int]())
    checkQueueInfoConsistency()

    testPlayer.insertPodcastQueue(playables: [song9])
    checkCurrentlyPlaying(idToBe: 2)
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [0, 1])
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [3, 4])
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [5, 6, 7, 8])
    checkQueueItems(queue: testPlayer.podcastQueue.playables, seedIds: [9])
    checkQueueInfoConsistency()

    testPlayer.insertPodcastQueue(playables: [songA])
    checkCurrentlyPlaying(idToBe: 2)
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [0, 1])
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [3, 4])
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [5, 6, 7, 8])
    checkQueueItems(queue: testPlayer.podcastQueue.playables, seedIds: [9, 10])
    checkQueueInfoConsistency()

    testPlayer.insertPodcastQueue(playables: [songB])
    checkCurrentlyPlaying(idToBe: 2)
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [0, 1])
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [3, 4])
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [5, 6, 7, 8])
    checkQueueItems(queue: testPlayer.podcastQueue.playables, seedIds: [9, 11, 10])
    checkQueueInfoConsistency()

    testPlayer.insertPodcastQueue(playables: [songC])
    checkCurrentlyPlaying(idToBe: 2)
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [0, 1])
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [3, 4])
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [5, 6, 7, 8])
    checkQueueItems(queue: testPlayer.podcastQueue.playables, seedIds: [9, 12, 11, 10])
    checkQueueInfoConsistency()
  }

  func testAppendPodcastQueue_playerModeMusic_NoWaitingQueuePlaying() {
    prepareNoWaitingQueuePlaying()
    testPlayer.setCurrentIndex(2)

    testPlayer.appendPodcastQueue(playables: [song9])
    checkCurrentlyPlaying(idToBe: 2)
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [0, 1])
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [3, 4])
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [5, 6, 7, 8])
    checkQueueItems(queue: testPlayer.podcastQueue.playables, seedIds: [9])
    checkQueueInfoConsistency()

    testPlayer.appendPodcastQueue(playables: [songA])
    checkCurrentlyPlaying(idToBe: 2)
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [0, 1])
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [3, 4])
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [5, 6, 7, 8])
    checkQueueItems(queue: testPlayer.podcastQueue.playables, seedIds: [9, 10])
    checkQueueInfoConsistency()

    testPlayer.appendPodcastQueue(playables: [songB])
    checkCurrentlyPlaying(idToBe: 2)
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [0, 1])
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [3, 4])
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [5, 6, 7, 8])
    checkQueueItems(queue: testPlayer.podcastQueue.playables, seedIds: [9, 10, 11])
    checkQueueInfoConsistency()

    testPlayer.appendPodcastQueue(playables: [songC])
    checkCurrentlyPlaying(idToBe: 2)
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [0, 1])
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [3, 4])
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [5, 6, 7, 8])
    checkQueueItems(queue: testPlayer.podcastQueue.playables, seedIds: [9, 10, 11, 12])
    checkQueueInfoConsistency()
  }

  func testInsertContextQueue_playerModePodcast_NoWaitingQueuePlaying() {
    prepareNoWaitingQueuePlaying()
    testPlayer.setCurrentIndex(2)
    testPlayer.setPlayerMode(.podcast)

    checkCurrentlyPlaying(idToBe: nil)
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [Int]())
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [Int]())
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [Int]())
    checkQueueItems(queue: testPlayer.contextQueue.playables, seedIds: [0, 1, 2, 3, 4])
    checkQueueInfoConsistency()

    testPlayer.insertContextQueue(playables: [song9])
    checkCurrentlyPlaying(idToBe: nil)
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [Int]())
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [Int]())
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [Int]())
    checkQueueItems(queue: testPlayer.contextQueue.playables, seedIds: [0, 1, 2, 9, 3, 4])
    checkQueueInfoConsistency()
    testPlayer.setPlayerMode(.music)
    checkCurrentlyPlaying(idToBe: 2)
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [0, 1])
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [9, 3, 4])
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [5, 6, 7, 8])
    checkQueueItems(queue: testPlayer.podcastQueue.playables, seedIds: [Int]())
    checkQueueInfoConsistency()
    testPlayer.setPlayerMode(.podcast)

    testPlayer.insertContextQueue(playables: [songA])
    checkCurrentlyPlaying(idToBe: nil)
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [Int]())
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [Int]())
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [Int]())
    checkQueueItems(queue: testPlayer.contextQueue.playables, seedIds: [0, 1, 2, 10, 9, 3, 4])
    checkQueueInfoConsistency()
    testPlayer.setPlayerMode(.music)
    checkCurrentlyPlaying(idToBe: 2)
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [0, 1])
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [10, 9, 3, 4])
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [5, 6, 7, 8])
    checkQueueItems(queue: testPlayer.podcastQueue.playables, seedIds: [Int]())
    checkQueueInfoConsistency()
    testPlayer.setPlayerMode(.podcast)

    testPlayer.insertContextQueue(playables: [songB])
    checkCurrentlyPlaying(idToBe: nil)
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [Int]())
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [Int]())
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [Int]())
    checkQueueItems(queue: testPlayer.contextQueue.playables, seedIds: [0, 1, 2, 11, 10, 9, 3, 4])
    checkQueueInfoConsistency()
    testPlayer.setPlayerMode(.music)
    checkCurrentlyPlaying(idToBe: 2)
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [0, 1])
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [11, 10, 9, 3, 4])
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [5, 6, 7, 8])
    checkQueueItems(queue: testPlayer.podcastQueue.playables, seedIds: [Int]())
    checkQueueInfoConsistency()
    testPlayer.setPlayerMode(.podcast)
  }

  func testAppendContextQueue_playerModePodcast_NoWaitingQueuePlaying() {
    prepareNoWaitingQueuePlaying()
    testPlayer.setCurrentIndex(2)
    testPlayer.setPlayerMode(.podcast)

    checkCurrentlyPlaying(idToBe: nil)
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [Int]())
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [Int]())
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [Int]())
    checkQueueItems(queue: testPlayer.contextQueue.playables, seedIds: [0, 1, 2, 3, 4])
    checkQueueInfoConsistency()

    testPlayer.appendContextQueue(playables: [song9])
    checkCurrentlyPlaying(idToBe: nil)
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [Int]())
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [Int]())
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [Int]())
    checkQueueItems(queue: testPlayer.contextQueue.playables, seedIds: [0, 1, 2, 3, 4, 9])
    checkQueueInfoConsistency()
    testPlayer.setPlayerMode(.music)
    checkCurrentlyPlaying(idToBe: 2)
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [0, 1])
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [3, 4, 9])
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [5, 6, 7, 8])
    checkQueueItems(queue: testPlayer.podcastQueue.playables, seedIds: [Int]())
    checkQueueInfoConsistency()
    testPlayer.setPlayerMode(.podcast)

    testPlayer.appendContextQueue(playables: [songA])
    checkCurrentlyPlaying(idToBe: nil)
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [Int]())
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [Int]())
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [Int]())
    checkQueueItems(queue: testPlayer.contextQueue.playables, seedIds: [0, 1, 2, 3, 4, 9, 10])
    checkQueueInfoConsistency()
    testPlayer.setPlayerMode(.music)
    checkCurrentlyPlaying(idToBe: 2)
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [0, 1])
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [3, 4, 9, 10])
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [5, 6, 7, 8])
    checkQueueItems(queue: testPlayer.podcastQueue.playables, seedIds: [Int]())
    checkQueueInfoConsistency()
    testPlayer.setPlayerMode(.podcast)

    testPlayer.appendContextQueue(playables: [songB])
    checkCurrentlyPlaying(idToBe: nil)
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [Int]())
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [Int]())
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [Int]())
    checkQueueItems(queue: testPlayer.contextQueue.playables, seedIds: [0, 1, 2, 3, 4, 9, 10, 11])
    checkQueueInfoConsistency()
    testPlayer.setPlayerMode(.music)
    checkCurrentlyPlaying(idToBe: 2)
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [0, 1])
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [3, 4, 9, 10, 11])
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [5, 6, 7, 8])
    checkQueueItems(queue: testPlayer.podcastQueue.playables, seedIds: [Int]())
    checkQueueInfoConsistency()
    testPlayer.setPlayerMode(.podcast)
  }

  func testInsertUserQueue_playerModePodcast_NoWaitingQueuePlaying() {
    prepareNoWaitingQueuePlaying()
    testPlayer.setCurrentIndex(2)
    testPlayer.setPlayerMode(.podcast)

    checkCurrentlyPlaying(idToBe: nil)
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [Int]())
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [Int]())
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [Int]())
    checkQueueItems(queue: testPlayer.contextQueue.playables, seedIds: [0, 1, 2, 3, 4])
    checkQueueInfoConsistency()

    testPlayer.insertUserQueue(playables: [song9])
    checkCurrentlyPlaying(idToBe: nil)
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [Int]())
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [Int]())
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [Int]())
    checkQueueItems(queue: testPlayer.contextQueue.playables, seedIds: [0, 1, 2, 3, 4])
    checkQueueInfoConsistency()
    testPlayer.setPlayerMode(.music)
    checkCurrentlyPlaying(idToBe: 2)
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [0, 1])
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [3, 4])
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [9, 5, 6, 7, 8])
    checkQueueItems(queue: testPlayer.podcastQueue.playables, seedIds: [Int]())
    checkQueueInfoConsistency()
    testPlayer.setPlayerMode(.podcast)

    testPlayer.insertUserQueue(playables: [songA])
    checkCurrentlyPlaying(idToBe: nil)
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [Int]())
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [Int]())
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [Int]())
    checkQueueItems(queue: testPlayer.contextQueue.playables, seedIds: [0, 1, 2, 3, 4])
    checkQueueInfoConsistency()
    testPlayer.setPlayerMode(.music)
    checkCurrentlyPlaying(idToBe: 2)
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [0, 1])
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [3, 4])
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [10, 9, 5, 6, 7, 8])
    checkQueueItems(queue: testPlayer.podcastQueue.playables, seedIds: [Int]())
    checkQueueInfoConsistency()
    testPlayer.setPlayerMode(.podcast)

    testPlayer.insertUserQueue(playables: [songB])
    checkCurrentlyPlaying(idToBe: nil)
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [Int]())
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [Int]())
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [Int]())
    checkQueueItems(queue: testPlayer.contextQueue.playables, seedIds: [0, 1, 2, 3, 4])
    checkQueueInfoConsistency()
    testPlayer.setPlayerMode(.music)
    checkCurrentlyPlaying(idToBe: 2)
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [0, 1])
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [3, 4])
    checkQueueItems(
      queue: testQueueHandler.getAllUserQueueItems(),
      seedIds: [11, 10, 9, 5, 6, 7, 8]
    )
    checkQueueItems(queue: testPlayer.podcastQueue.playables, seedIds: [Int]())
    checkQueueInfoConsistency()
    testPlayer.setPlayerMode(.podcast)
  }

  func testAppendUserQueue_playerModePodcast_NoWaitingQueuePlaying() {
    prepareNoWaitingQueuePlaying()
    testPlayer.setCurrentIndex(2)
    testPlayer.setPlayerMode(.podcast)

    checkCurrentlyPlaying(idToBe: nil)
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [Int]())
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [Int]())
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [Int]())
    checkQueueItems(queue: testPlayer.contextQueue.playables, seedIds: [0, 1, 2, 3, 4])
    checkQueueInfoConsistency()

    testPlayer.appendUserQueue(playables: [song9])
    checkCurrentlyPlaying(idToBe: nil)
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [Int]())
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [Int]())
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [Int]())
    checkQueueItems(queue: testPlayer.contextQueue.playables, seedIds: [0, 1, 2, 3, 4])
    checkQueueInfoConsistency()
    testPlayer.setPlayerMode(.music)
    checkCurrentlyPlaying(idToBe: 2)
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [0, 1])
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [3, 4])
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [5, 6, 7, 8, 9])
    checkQueueItems(queue: testPlayer.podcastQueue.playables, seedIds: [Int]())
    checkQueueInfoConsistency()
    testPlayer.setPlayerMode(.podcast)

    testPlayer.appendUserQueue(playables: [songA])
    checkCurrentlyPlaying(idToBe: nil)
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [Int]())
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [Int]())
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [Int]())
    checkQueueItems(queue: testPlayer.contextQueue.playables, seedIds: [0, 1, 2, 3, 4])
    checkQueueInfoConsistency()
    testPlayer.setPlayerMode(.music)
    checkCurrentlyPlaying(idToBe: 2)
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [0, 1])
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [3, 4])
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [5, 6, 7, 8, 9, 10])
    checkQueueItems(queue: testPlayer.podcastQueue.playables, seedIds: [Int]())
    checkQueueInfoConsistency()
    testPlayer.setPlayerMode(.podcast)

    testPlayer.appendUserQueue(playables: [songB])
    checkCurrentlyPlaying(idToBe: nil)
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [Int]())
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [Int]())
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [Int]())
    checkQueueItems(queue: testPlayer.contextQueue.playables, seedIds: [0, 1, 2, 3, 4])
    checkQueueInfoConsistency()
    testPlayer.setPlayerMode(.music)
    checkCurrentlyPlaying(idToBe: 2)
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [0, 1])
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [3, 4])
    checkQueueItems(
      queue: testQueueHandler.getAllUserQueueItems(),
      seedIds: [5, 6, 7, 8, 9, 10, 11]
    )
    checkQueueItems(queue: testPlayer.podcastQueue.playables, seedIds: [Int]())
    checkQueueInfoConsistency()
    testPlayer.setPlayerMode(.podcast)
  }

  func testInsertPodcastQueue_playerModeMusic_WithWaitingQueuePlaying() {
    prepareWithWaitingQueuePlaying()
    testPlayer.setCurrentIndex(2)
    checkCurrentlyPlaying(idToBe: 5)
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [0, 1, 2])
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [3, 4])
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [6, 7, 8])
    checkQueueItems(queue: testPlayer.podcastQueue.playables, seedIds: [Int]())
    checkQueueInfoConsistency()

    testPlayer.insertPodcastQueue(playables: [song9])
    checkCurrentlyPlaying(idToBe: 5)
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [0, 1, 2])
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [3, 4])
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [6, 7, 8])
    checkQueueItems(queue: testPlayer.podcastQueue.playables, seedIds: [9])
    checkQueueInfoConsistency()

    testPlayer.insertPodcastQueue(playables: [songA])
    checkCurrentlyPlaying(idToBe: 5)
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [0, 1, 2])
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [3, 4])
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [6, 7, 8])
    checkQueueItems(queue: testPlayer.podcastQueue.playables, seedIds: [9, 10])
    checkQueueInfoConsistency()

    testPlayer.insertPodcastQueue(playables: [songB])
    checkCurrentlyPlaying(idToBe: 5)
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [0, 1, 2])
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [3, 4])
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [6, 7, 8])
    checkQueueItems(queue: testPlayer.podcastQueue.playables, seedIds: [9, 11, 10])
    checkQueueInfoConsistency()

    testPlayer.insertPodcastQueue(playables: [songC])
    checkCurrentlyPlaying(idToBe: 5)
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [0, 1, 2])
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [3, 4])
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [6, 7, 8])
    checkQueueItems(queue: testPlayer.podcastQueue.playables, seedIds: [9, 12, 11, 10])
    checkQueueInfoConsistency()
  }

  func testAppendPodcastQueue_playerModeMusic_WithWaitingQueuePlaying() {
    prepareWithWaitingQueuePlaying()
    testPlayer.setCurrentIndex(2)

    testPlayer.appendPodcastQueue(playables: [song9])
    checkCurrentlyPlaying(idToBe: 5)
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [0, 1, 2])
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [3, 4])
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [6, 7, 8])
    checkQueueItems(queue: testPlayer.podcastQueue.playables, seedIds: [9])
    checkQueueInfoConsistency()

    testPlayer.appendPodcastQueue(playables: [songA])
    checkCurrentlyPlaying(idToBe: 5)
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [0, 1, 2])
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [3, 4])
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [6, 7, 8])
    checkQueueItems(queue: testPlayer.podcastQueue.playables, seedIds: [9, 10])
    checkQueueInfoConsistency()

    testPlayer.appendPodcastQueue(playables: [songB])
    checkCurrentlyPlaying(idToBe: 5)
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [0, 1, 2])
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [3, 4])
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [6, 7, 8])
    checkQueueItems(queue: testPlayer.podcastQueue.playables, seedIds: [9, 10, 11])
    checkQueueInfoConsistency()

    testPlayer.appendPodcastQueue(playables: [songC])
    checkCurrentlyPlaying(idToBe: 5)
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [0, 1, 2])
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [3, 4])
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [6, 7, 8])
    checkQueueItems(queue: testPlayer.podcastQueue.playables, seedIds: [9, 10, 11, 12])
    checkQueueInfoConsistency()
  }

  func testInsertContextQueue_playerModePodcast_WithWaitingQueuePlaying() {
    prepareWithWaitingQueuePlaying()
    testPlayer.setCurrentIndex(2)

    testPlayer.setPlayerMode(.podcast)
    testPlayer.insertPodcastQueue(playables: [songD, songE, songF])
    testPlayer.setCurrentIndex(1)

    checkCurrentlyPlaying(idToBe: 14)
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [13])
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [15])
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [Int]())
    checkQueueInfoConsistency()

    testPlayer.insertContextQueue(playables: [song9])
    checkCurrentlyPlaying(idToBe: 14)
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [13])
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [15])
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [Int]())
    checkQueueInfoConsistency()
    testPlayer.setPlayerMode(.music)
    checkCurrentlyPlaying(idToBe: 5)
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [0, 1, 2])
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [9, 3, 4])
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [6, 7, 8])
    checkQueueInfoConsistency()
    testPlayer.setPlayerMode(.podcast)

    testPlayer.insertContextQueue(playables: [songA])
    checkCurrentlyPlaying(idToBe: 14)
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [13])
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [15])
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [Int]())
    checkQueueInfoConsistency()
    testPlayer.setPlayerMode(.music)
    checkCurrentlyPlaying(idToBe: 5)
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [0, 1, 2])
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [10, 9, 3, 4])
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [6, 7, 8])
    checkQueueInfoConsistency()
    testPlayer.setPlayerMode(.podcast)

    testPlayer.insertContextQueue(playables: [songB])
    checkCurrentlyPlaying(idToBe: 14)
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [13])
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [15])
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [Int]())
    checkQueueItems(queue: testPlayer.contextQueue.playables, seedIds: [0, 1, 2, 11, 10, 9, 3, 4])
    checkQueueInfoConsistency()
    testPlayer.setPlayerMode(.music)
    checkCurrentlyPlaying(idToBe: 5)
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [0, 1, 2])
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [11, 10, 9, 3, 4])
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [6, 7, 8])
    checkQueueInfoConsistency()
    testPlayer.setPlayerMode(.podcast)
  }

  func testAppendContextQueue_playerModePodcast_WithWaitingQueuePlaying() {
    prepareWithWaitingQueuePlaying()
    testPlayer.setCurrentIndex(2)

    testPlayer.setPlayerMode(.podcast)
    testPlayer.insertPodcastQueue(playables: [songD, songE, songF])
    testPlayer.setCurrentIndex(1)

    checkCurrentlyPlaying(idToBe: 14)
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [13])
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [15])
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [Int]())
    checkQueueInfoConsistency()

    testPlayer.appendContextQueue(playables: [song9])
    checkCurrentlyPlaying(idToBe: 14)
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [13])
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [15])
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [Int]())
    checkQueueInfoConsistency()
    testPlayer.setPlayerMode(.music)
    checkCurrentlyPlaying(idToBe: 5)
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [0, 1, 2])
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [3, 4, 9])
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [6, 7, 8])
    checkQueueInfoConsistency()
    testPlayer.setPlayerMode(.podcast)

    testPlayer.appendContextQueue(playables: [songA])
    checkCurrentlyPlaying(idToBe: 14)
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [13])
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [15])
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [Int]())
    checkQueueInfoConsistency()
    testPlayer.setPlayerMode(.music)
    checkCurrentlyPlaying(idToBe: 5)
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [0, 1, 2])
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [3, 4, 9, 10])
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [6, 7, 8])
    checkQueueInfoConsistency()
    testPlayer.setPlayerMode(.podcast)

    testPlayer.appendContextQueue(playables: [songB])
    checkCurrentlyPlaying(idToBe: 14)
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [13])
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [15])
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [Int]())
    checkQueueInfoConsistency()
    testPlayer.setPlayerMode(.music)
    checkCurrentlyPlaying(idToBe: 5)
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [0, 1, 2])
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [3, 4, 9, 10, 11])
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [6, 7, 8])
    checkQueueInfoConsistency()
    testPlayer.setPlayerMode(.podcast)
  }

  func testInsertUserQueue_playerModePodcast_WithWaitingQueuePlaying() {
    prepareWithWaitingQueuePlaying()
    testPlayer.setCurrentIndex(2)

    testPlayer.setPlayerMode(.podcast)
    testPlayer.insertPodcastQueue(playables: [songD, songE, songF])
    testPlayer.setCurrentIndex(1)

    checkCurrentlyPlaying(idToBe: 14)
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [13])
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [15])
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [Int]())
    checkQueueInfoConsistency()

    testPlayer.insertUserQueue(playables: [song9])
    checkCurrentlyPlaying(idToBe: 14)
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [13])
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [15])
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [Int]())
    checkQueueInfoConsistency()
    testPlayer.setPlayerMode(.music)
    checkCurrentlyPlaying(idToBe: 5)
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [0, 1, 2])
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [3, 4])
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [9, 6, 7, 8])
    checkQueueInfoConsistency()
    testPlayer.setPlayerMode(.podcast)

    testPlayer.insertUserQueue(playables: [songA])
    checkCurrentlyPlaying(idToBe: 14)
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [13])
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [15])
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [Int]())
    checkQueueInfoConsistency()
    testPlayer.setPlayerMode(.music)
    checkCurrentlyPlaying(idToBe: 5)
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [0, 1, 2])
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [3, 4])
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [10, 9, 6, 7, 8])
    checkQueueInfoConsistency()
    testPlayer.setPlayerMode(.podcast)

    testPlayer.insertUserQueue(playables: [songB])
    checkCurrentlyPlaying(idToBe: 14)
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [13])
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [15])
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [Int]())
    checkQueueInfoConsistency()
    testPlayer.setPlayerMode(.music)
    checkCurrentlyPlaying(idToBe: 5)
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [0, 1, 2])
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [3, 4])
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [11, 10, 9, 6, 7, 8])
    checkQueueInfoConsistency()
    testPlayer.setPlayerMode(.podcast)
  }

  func testAppendUserQueue_playerModePodcast_WithWaitingQueuePlaying() {
    prepareWithWaitingQueuePlaying()
    testPlayer.setCurrentIndex(2)

    testPlayer.setPlayerMode(.podcast)
    testPlayer.insertPodcastQueue(playables: [songD, songE, songF])
    testPlayer.setCurrentIndex(1)

    checkCurrentlyPlaying(idToBe: 14)
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [13])
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [15])
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [Int]())
    checkQueueInfoConsistency()

    testPlayer.appendUserQueue(playables: [song9])
    checkCurrentlyPlaying(idToBe: 14)
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [13])
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [15])
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [Int]())
    checkQueueInfoConsistency()
    testPlayer.setPlayerMode(.music)
    checkCurrentlyPlaying(idToBe: 5)
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [0, 1, 2])
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [3, 4])
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [6, 7, 8, 9])
    checkQueueInfoConsistency()
    testPlayer.setPlayerMode(.podcast)

    testPlayer.appendUserQueue(playables: [songA])
    checkCurrentlyPlaying(idToBe: 14)
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [13])
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [15])
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [Int]())
    checkQueueInfoConsistency()
    testPlayer.setPlayerMode(.music)
    checkCurrentlyPlaying(idToBe: 5)
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [0, 1, 2])
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [3, 4])
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [6, 7, 8, 9, 10])
    checkQueueInfoConsistency()
    testPlayer.setPlayerMode(.podcast)

    testPlayer.appendUserQueue(playables: [songB])
    checkCurrentlyPlaying(idToBe: 14)
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [13])
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [15])
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [Int]())
    checkQueueInfoConsistency()
    testPlayer.setPlayerMode(.music)
    checkCurrentlyPlaying(idToBe: 5)
    checkQueueItems(queue: testQueueHandler.getAllPrevQueueItems(), seedIds: [0, 1, 2])
    checkQueueItems(queue: testQueueHandler.getAllNextQueueItems(), seedIds: [3, 4])
    checkQueueItems(queue: testQueueHandler.getAllUserQueueItems(), seedIds: [6, 7, 8, 9, 10, 11])
    checkQueueInfoConsistency()
    testPlayer.setPlayerMode(.podcast)
  }
}
