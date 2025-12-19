//
//  PlayerDataTest.swift
//  AmperfyKitTests
//
//  Created by Maximilian Bauer on 02.01.20.
//  Copyright (c) 2020 Maximilian Bauer. All rights reserved.
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
class PlayerDataTest: XCTestCase {
  var cdHelper: CoreDataHelper!
  var library: LibraryStorage!
  var account: Account!
  var testPlayer: PlayerData!
  var testNormalPlaylist: Playlist!
  var testShuffledPlaylist: Playlist!
  var testPodcastPlaylist: Playlist!
  let fillCount = 5

  override func setUp() async throws {
    cdHelper = CoreDataHelper()
    library = cdHelper.createSeededStorage()
    account = library.getAccount(info: TestAccountInfo.create1())
    testPlayer = library.getPlayerData()
    testPlayer.setShuffle(true)
    testShuffledPlaylist = testPlayer.activeQueue
    testPlayer.setShuffle(false)
    testNormalPlaylist = testPlayer.activeQueue
    testPodcastPlaylist = testPlayer.podcastQueue
  }

  override func tearDown() {}

  func fillPlayerWithSomeSongs() {
    for i in 0 ... fillCount - 1 {
      guard let song = library.getSong(for: account, id: cdHelper.seeder.songs[i].id)
      else { XCTFail(); return }
      testPlayer.appendActiveQueue(playables: [song])
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
    XCTAssertEqual(testPlayer.activeQueue.playables[playlistIndex].id, song.id)
  }

  func testCreation() {
    XCTAssertNotEqual(testNormalPlaylist, testShuffledPlaylist)
    XCTAssertEqual(testPlayer.activeQueue, testNormalPlaylist)
    XCTAssertEqual(testPlayer.currentItem, nil)
    XCTAssertFalse(testPlayer.isShuffle)
    XCTAssertEqual(testPlayer.repeatMode, RepeatMode.off)
    XCTAssertEqual(testPlayer.currentIndex, 0)
    XCTAssertEqual(testNormalPlaylist.playables.count, 0)
    XCTAssertEqual(testShuffledPlaylist.playables.count, 0)
  }

  func testPlaylist() {
    fillPlayerWithSomeSongs()
    XCTAssertEqual(testPlayer.activeQueue.playables.count, fillCount)
    checkCorrectDefaultPlaylist()
  }

  func testCurrentSong() {
    fillPlayerWithSomeSongs()

    for i in [3, 2, 4, 1, 0] {
      guard let song = library.getSong(for: account, id: cdHelper.seeder.songs[i].id)
      else { XCTFail(); return }
      testPlayer.setCurrentIndex(i)
      XCTAssertEqual(testPlayer.currentItem?.id, song.id)
    }
  }

  func testShuffle() {
    testPlayer.setShuffle(true)
    XCTAssertTrue(testPlayer.isShuffle)
    XCTAssertEqual(testPlayer.activeQueue, testShuffledPlaylist)
    testPlayer.setShuffle(false)
    XCTAssertFalse(testPlayer.isShuffle)
    XCTAssertEqual(testPlayer.activeQueue, testNormalPlaylist)
    testPlayer.setShuffle(true)
    XCTAssertEqual(testPlayer.activeQueue, testShuffledPlaylist)

    fillPlayerWithSomeSongs()
    XCTAssertEqual(testPlayer.activeQueue.playables.count, fillCount)
    testPlayer.setShuffle(false)
    XCTAssertEqual(testPlayer.activeQueue.playables.count, fillCount)
    checkCorrectDefaultPlaylist()
    testPlayer.setShuffle(true)
    XCTAssertEqual(testPlayer.activeQueue.playables.count, fillCount)
    testPlayer.setShuffle(false)
    XCTAssertEqual(testPlayer.activeQueue.playables.count, fillCount)
    checkCorrectDefaultPlaylist()
    testPlayer.setShuffle(true)
  }

  func testRepeat() {
    testPlayer.setRepeatMode(RepeatMode.all)
    XCTAssertEqual(testPlayer.repeatMode, RepeatMode.all)
    testPlayer.setRepeatMode(RepeatMode.single)
    XCTAssertEqual(testPlayer.repeatMode, RepeatMode.single)
    testPlayer.setRepeatMode(RepeatMode.off)
    XCTAssertEqual(testPlayer.repeatMode, RepeatMode.off)
  }

  func testCurrentSongIndexSet() {
    fillPlayerWithSomeSongs()
    let curIndex = 2
    testPlayer.setCurrentIndex(curIndex)
    XCTAssertEqual(testPlayer.currentIndex, curIndex)
    testPlayer.setCurrentIndex(-1)
    XCTAssertEqual(testPlayer.currentIndex, 0)
    testPlayer.setCurrentIndex(-2)
    XCTAssertEqual(testPlayer.currentIndex, 0)
    testPlayer.setUserQueuePlaying(true)
    testPlayer.setCurrentIndex(-1)
    XCTAssertEqual(testPlayer.currentIndex, -1)
    testPlayer.setCurrentIndex(-2)
    XCTAssertEqual(testPlayer.currentIndex, -1)
    testPlayer.setUserQueuePlaying(false)
    testPlayer.setCurrentIndex(-10)
    XCTAssertEqual(testPlayer.currentIndex, 0)
    testPlayer.setCurrentIndex(fillCount - 1)
    XCTAssertEqual(testPlayer.currentIndex, fillCount - 1)
    testPlayer.setCurrentIndex(fillCount)
    XCTAssertEqual(testPlayer.currentIndex, 0)
    testPlayer.setCurrentIndex(100)
    XCTAssertEqual(testPlayer.currentIndex, 0)
  }

  func testAddToPlaylist() {
    fillPlayerWithSomeSongs()
    guard let song1 = library.getSong(for: account, id: cdHelper.seeder.songs[6].id)
    else { XCTFail(); return }
    guard let song2 = library.getSong(for: account, id: cdHelper.seeder.songs[7].id)
    else { XCTFail(); return }
    testPlayer.appendActiveQueue(playables: [song1])
    XCTAssertEqual(testPlayer.activeQueue.playables.count, fillCount + 1)
    testPlayer.setShuffle(true)
    XCTAssertEqual(testPlayer.activeQueue.playables.count, fillCount + 1)
    testPlayer.appendActiveQueue(playables: [song2])
    XCTAssertEqual(testPlayer.activeQueue.playables.count, fillCount + 2)
    testPlayer.setShuffle(false)
    XCTAssertEqual(testPlayer.activeQueue.playables.count, fillCount + 2)
    XCTAssertEqual(testPlayer.activeQueue.playables[fillCount].id, song1.id)
    XCTAssertEqual(testPlayer.activeQueue.playables[fillCount + 1].id, song2.id)
  }

  func testRemoveAllSongs() {
    fillPlayerWithSomeSongs()
    testPlayer.setCurrentIndex(3)
    XCTAssertEqual(testPlayer.currentIndex, 3)
    testPlayer.removeAllItems()
    XCTAssertEqual(testPlayer.currentIndex, 0)
    XCTAssertEqual(testPlayer.activeQueue.playables.count, 0)

    guard let song1 = library.getSong(for: account, id: cdHelper.seeder.songs[6].id)
    else { XCTFail(); return }
    guard let song2 = library.getSong(for: account, id: cdHelper.seeder.songs[7].id)
    else { XCTFail(); return }
    testPlayer.appendActiveQueue(playables: [song1])
    testPlayer.appendActiveQueue(playables: [song2])
    testPlayer.removeAllItems()
    XCTAssertEqual(testPlayer.activeQueue.playables.count, 0)
  }
}
