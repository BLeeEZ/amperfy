//
//  PlaylistTest.swift
//  AmperfyKitTests
//
//  Created by Maximilian Bauer on 30.12.19.
//  Copyright (c) 2019 Maximilian Bauer. All rights reserved.
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
class PlaylistTest: XCTestCase {
  var cdHelper: CoreDataHelper!
  var library: LibraryStorage!
  var account: Account!
  var testPlaylist: Playlist!
  var defaultPlaylist: Playlist!
  var playlistThreeCached: Playlist!
  var playlistNoCached: Playlist!

  override func setUp() async throws {
    cdHelper = CoreDataHelper()
    library = cdHelper.createSeededStorage()
    account = library.getAccount(info: TestAccountInfo.create1())
    guard let playlist = library.getPlaylist(for: account, id: cdHelper.seeder.playlists[0].id)
    else { XCTFail(); return }
    defaultPlaylist = playlist
    guard let playlistCached = library.getPlaylist(
      for: account,
      id: cdHelper.seeder.playlists[1].id
    )
    else { XCTFail(); return }
    playlistThreeCached = playlistCached
    guard let playlistZeroCached = library.getPlaylist(
      for: account,
      id: cdHelper.seeder.playlists[2].id
    )
    else { XCTFail(); return }
    playlistNoCached = playlistZeroCached
    testPlaylist = library.createPlaylist(account: account)
    resetTestPlaylist()
  }

  override func tearDown() {}

  func resetTestPlaylist() {
    testPlaylist.removeAllItems()
    for i in 0 ... 4 {
      guard let song = library.getSong(for: account, id: cdHelper.seeder.songs[i].id)
      else { XCTFail(); return }
      testPlaylist.append(playable: song)
    }
  }

  func checkTestPlaylistNoChange() {
    for i in 0 ... 4 {
      checkPlaylistIndexEqualSeedIndex(playlistIndex: i, seedIndex: i)
    }
  }

  func checkPlaylistIndexEqualSeedIndex(playlistIndex: Int, seedIndex: Int) {
    guard let song = library.getSong(for: account, id: cdHelper.seeder.songs[seedIndex].id)
    else { XCTFail(); return }
    XCTAssertEqual(testPlaylist.playables[playlistIndex].id, song.id)
  }

  func testCreation() {
    let playlist = library.createPlaylist(account: account)
    XCTAssertEqual(playlist.account?.serverHash, TestAccountInfo.test1ServerHash)
    XCTAssertEqual(playlist.account?.userHash, TestAccountInfo.test1UserHash)
    XCTAssertEqual(playlist.items.count, 0)
    XCTAssertEqual(playlist.id, "")
    XCTAssertEqual(playlist.lastPlayableIndex, 0)
    XCTAssertFalse(playlist.playables.hasCachedItems)

    let name = "Test 234"
    playlist.name = name
    XCTAssertEqual(playlist.name, name)

    let id = "12345"
    playlist.id = id
    XCTAssertEqual(playlist.id, id)
  }

  func testFetch() {
    let playlist = library.createPlaylist(account: account)
    XCTAssertEqual(playlist.account?.serverHash, TestAccountInfo.test1ServerHash)
    XCTAssertEqual(playlist.account?.userHash, TestAccountInfo.test1UserHash)
    let id = "12345"
    let name = "Test 234"
    let testAccount = library.getAccount(info: TestAccountInfo.create2())
    playlist.account = testAccount
    playlist.name = name
    playlist.id = id
    guard let playlistFetched = library.getPlaylist(for: testAccount, id: id)
    else { XCTFail(); return }
    XCTAssertEqual(playlistFetched.name, name)
    XCTAssertEqual(playlistFetched.id, id)
    XCTAssertEqual(playlistFetched.account?.serverHash, TestAccountInfo.test2ServerHash)
    XCTAssertEqual(playlistFetched.account?.userHash, TestAccountInfo.test2UserHash)
  }

  func testSongAppend() {
    let playlist = library.createPlaylist(account: account)
    XCTAssertEqual(playlist.items.count, 0)
    guard let song1 = library.getSong(for: account, id: cdHelper.seeder.songs[0].id)
    else { XCTFail(); return }
    playlist.append(playable: song1)
    XCTAssertEqual(playlist.items.count, 1)
    guard let song2 = library.getSong(for: account, id: cdHelper.seeder.songs[1].id)
    else { XCTFail(); return }
    playlist.append(playable: song2)
    XCTAssertEqual(playlist.items.count, 2)
    guard let song3 = library.getSong(for: account, id: cdHelper.seeder.songs[2].id)
    else { XCTFail(); return }
    playlist.append(playable: song3)
    XCTAssertEqual(playlist.items.count, 3)

    for (index, entry) in playlist.items.enumerated() {
      XCTAssertEqual(entry.playable.id, cdHelper.seeder.songs[index].id)
      XCTAssertEqual(entry.account?.serverHash, TestAccountInfo.test1ServerHash)
      XCTAssertEqual(entry.account?.userHash, TestAccountInfo.test1UserHash)
    }
  }

  func testSongInsertInvalidIndexes() {
    guard let song1 = library.getSong(for: account, id: cdHelper.seeder.songs[0].id)
    else { XCTFail(); return }
    guard let song2 = library.getSong(for: account, id: cdHelper.seeder.songs[1].id)
    else { XCTFail(); return }
    resetTestPlaylist()
    testPlaylist.insert(playables: [song1, song2], index: -1)
    checkTestPlaylistNoChange()
    testPlaylist.insert(playables: [song1, song2], index: -5)
    checkTestPlaylistNoChange()
    testPlaylist.insert(playables: [], index: -1)
    checkTestPlaylistNoChange()
    testPlaylist.insert(playables: [], index: -5)
    checkTestPlaylistNoChange()
    testPlaylist.insert(playables: [song1, song2], index: 6)
    checkTestPlaylistNoChange()
    testPlaylist.insert(playables: [], index: 6)
    checkTestPlaylistNoChange()
    testPlaylist.insert(playables: [song1, song2], index: 100)
    checkTestPlaylistNoChange()
    testPlaylist.insert(playables: [], index: 100)
    checkTestPlaylistNoChange()
  }

  func testSongInsert() {
    let playlist = library.createPlaylist(account: account)
    guard let song1 = library.getSong(for: account, id: cdHelper.seeder.songs[0].id)
    else { XCTFail(); return }
    guard let song2 = library.getSong(for: account, id: cdHelper.seeder.songs[1].id)
    else { XCTFail(); return }
    guard let song3 = library.getSong(for: account, id: cdHelper.seeder.songs[2].id)
    else { XCTFail(); return }
    guard let song4 = library.getSong(for: account, id: cdHelper.seeder.songs[3].id)
    else { XCTFail(); return }
    guard let song5 = library.getSong(for: account, id: cdHelper.seeder.songs[4].id)
    else { XCTFail(); return }
    XCTAssertEqual(playlist.items.count, 0)
    playlist.insert(playables: [song5])
    XCTAssertEqual(playlist.items.count, 1)
    playlist.insert(playables: [song4])
    XCTAssertEqual(playlist.items.count, 2)
    playlist.insert(playables: [song1, song2, song3])
    XCTAssertEqual(playlist.items.count, 5)

    for (index, entry) in playlist.items.enumerated() {
      if index > 0 {
        XCTAssert(playlist.items[index - 1].order < entry.order)
      }
      XCTAssertEqual(entry.playable.id, cdHelper.seeder.songs[index].id)
      XCTAssertEqual(entry.account?.serverHash, TestAccountInfo.test1ServerHash)
      XCTAssertEqual(entry.account?.userHash, TestAccountInfo.test1UserHash)
    }
  }

  func testSongInsert1() {
    let playlist = library.createPlaylist(account: account)
    guard let song1 = library.getSong(for: account, id: cdHelper.seeder.songs[0].id)
    else { XCTFail(); return }
    guard let song2 = library.getSong(for: account, id: cdHelper.seeder.songs[1].id)
    else { XCTFail(); return }
    guard let song3 = library.getSong(for: account, id: cdHelper.seeder.songs[2].id)
    else { XCTFail(); return }
    guard let song4 = library.getSong(for: account, id: cdHelper.seeder.songs[3].id)
    else { XCTFail(); return }
    guard let song5 = library.getSong(for: account, id: cdHelper.seeder.songs[4].id)
    else { XCTFail(); return }
    XCTAssertEqual(playlist.items.count, 0)
    playlist.insert(playables: [song5], index: 0)
    playlist.insert(playables: [song4], index: 0)
    XCTAssertEqual(playlist.items.count, 2)
    playlist.insert(playables: [song1, song2, song3], index: 0)
    XCTAssertEqual(playlist.items.count, 5)

    for (index, entry) in playlist.items.enumerated() {
      if index > 0 {
        XCTAssert(playlist.items[index - 1].order < entry.order)
      }
      XCTAssertEqual(entry.playable.id, cdHelper.seeder.songs[index].id)
      XCTAssertEqual(entry.account?.serverHash, TestAccountInfo.test1ServerHash)
      XCTAssertEqual(entry.account?.userHash, TestAccountInfo.test1UserHash)
    }
  }

  func testSongInsertCustomIndex() {
    let playlist = library.createPlaylist(account: account)
    guard let song1 = library.getSong(for: account, id: cdHelper.seeder.songs[0].id)
    else { XCTFail(); return }
    guard let song2 = library.getSong(for: account, id: cdHelper.seeder.songs[1].id)
    else { XCTFail(); return }
    guard let song3 = library.getSong(for: account, id: cdHelper.seeder.songs[2].id)
    else { XCTFail(); return }
    guard let song4 = library.getSong(for: account, id: cdHelper.seeder.songs[3].id)
    else { XCTFail(); return }
    guard let song5 = library.getSong(for: account, id: cdHelper.seeder.songs[4].id)
    else { XCTFail(); return }
    playlist.insert(playables: [song5], index: 0)
    playlist.insert(playables: [song4], index: 0)
    playlist.insert(playables: [song2], index: 0)
    playlist.insert(playables: [song1], index: 0)
    playlist.insert(playables: [song3], index: 2)

    for (index, entry) in playlist.items.enumerated() {
      if index > 0 {
        XCTAssert(playlist.items[index - 1].order < entry.order)
      }
      XCTAssertEqual(entry.playable.id, cdHelper.seeder.songs[index].id)
      XCTAssertEqual(entry.account?.serverHash, TestAccountInfo.test1ServerHash)
      XCTAssertEqual(entry.account?.userHash, TestAccountInfo.test1UserHash)
    }
  }

  func testSongInsertCustomIndex2() {
    let playlist = library.createPlaylist(account: account)
    guard let song1 = library.getSong(for: account, id: cdHelper.seeder.songs[0].id)
    else { XCTFail(); return }
    guard let song2 = library.getSong(for: account, id: cdHelper.seeder.songs[1].id)
    else { XCTFail(); return }
    guard let song3 = library.getSong(for: account, id: cdHelper.seeder.songs[2].id)
    else { XCTFail(); return }
    guard let song4 = library.getSong(for: account, id: cdHelper.seeder.songs[3].id)
    else { XCTFail(); return }
    guard let song5 = library.getSong(for: account, id: cdHelper.seeder.songs[4].id)
    else { XCTFail(); return }
    playlist.insert(playables: [song4], index: 0)
    playlist.insert(playables: [song3], index: 0)
    playlist.insert(playables: [song2], index: 0)
    playlist.insert(playables: [song1], index: 0)
    playlist.insert(playables: [song5], index: 4)

    for (index, entry) in playlist.items.enumerated() {
      if index > 0 {
        XCTAssert(playlist.items[index - 1].order < entry.order)
      }
      XCTAssertEqual(entry.playable.id, cdHelper.seeder.songs[index].id)
      XCTAssertEqual(entry.account?.serverHash, TestAccountInfo.test1ServerHash)
      XCTAssertEqual(entry.account?.userHash, TestAccountInfo.test1UserHash)
    }
  }

  func testSongInsertCustomIndex3() {
    let playlist = library.createPlaylist(account: account)
    guard let song1 = library.getSong(for: account, id: cdHelper.seeder.songs[0].id)
    else { XCTFail(); return }
    guard let song2 = library.getSong(for: account, id: cdHelper.seeder.songs[1].id)
    else { XCTFail(); return }
    playlist.insert(playables: [song1], index: 0)
    playlist.insert(playables: [song2], index: 1)

    for (index, entry) in playlist.items.enumerated() {
      if index > 0 {
        XCTAssert(playlist.items[index - 1].order < entry.order)
      }
      XCTAssertEqual(entry.playable.id, cdHelper.seeder.songs[index].id)
      XCTAssertEqual(entry.account?.serverHash, TestAccountInfo.test1ServerHash)
      XCTAssertEqual(entry.account?.userHash, TestAccountInfo.test1UserHash)
    }
  }

  func testSongInsertCustomIndex4() {
    let playlist = library.createPlaylist(account: account)
    guard let song1 = library.getSong(for: account, id: cdHelper.seeder.songs[0].id)
    else { XCTFail(); return }
    guard let song2 = library.getSong(for: account, id: cdHelper.seeder.songs[1].id)
    else { XCTFail(); return }
    guard let song3 = library.getSong(for: account, id: cdHelper.seeder.songs[2].id)
    else { XCTFail(); return }
    guard let song4 = library.getSong(for: account, id: cdHelper.seeder.songs[3].id)
    else { XCTFail(); return }
    guard let song5 = library.getSong(for: account, id: cdHelper.seeder.songs[4].id)
    else { XCTFail(); return }
    playlist.insert(playables: [song5], index: 0)
    playlist.insert(playables: [song1], index: 0)

    playlist.insert(playables: [song2, song3, song4], index: 1)

    for (index, entry) in playlist.items.enumerated() {
      if index > 0 {
        XCTAssert(playlist.items[index - 1].order < entry.order)
      }
      XCTAssertEqual(entry.playable.id, cdHelper.seeder.songs[index].id)
      XCTAssertEqual(entry.account?.serverHash, TestAccountInfo.test1ServerHash)
      XCTAssertEqual(entry.account?.userHash, TestAccountInfo.test1UserHash)
    }
  }

  func testSongInsertEmpty() {
    let playlist = library.createPlaylist(account: account)
    guard let song1 = library.getSong(for: account, id: cdHelper.seeder.songs[0].id)
    else { XCTFail(); return }
    guard let song2 = library.getSong(for: account, id: cdHelper.seeder.songs[1].id)
    else { XCTFail(); return }
    guard let song3 = library.getSong(for: account, id: cdHelper.seeder.songs[2].id)
    else { XCTFail(); return }
    XCTAssertEqual(playlist.items.count, 0)
    playlist.insert(playables: [])
    XCTAssertEqual(playlist.items.count, 0)
    playlist.insert(playables: [song1, song2, song3])
    XCTAssertEqual(playlist.items.count, 3)
    playlist.insert(playables: [])
    XCTAssertEqual(playlist.items.count, 3)

    for (index, entry) in playlist.items.enumerated() {
      if index > 0 {
        XCTAssert(playlist.items[index - 1].order < entry.order)
      }
      XCTAssertEqual(entry.playable.id, cdHelper.seeder.songs[index].id)
      XCTAssertEqual(entry.account?.serverHash, TestAccountInfo.test1ServerHash)
      XCTAssertEqual(entry.account?.userHash, TestAccountInfo.test1UserHash)
    }
  }

  func testDefaultPlaylist() {
    XCTAssertTrue(defaultPlaylist.playables.hasCachedItems)
    XCTAssertEqual(defaultPlaylist.playables.count, 5)
    XCTAssertEqual(defaultPlaylist.items.count, 5)
    XCTAssertEqual(defaultPlaylist.lastPlayableIndex, 4)
    XCTAssertEqual(defaultPlaylist.playables[0].id, cdHelper.seeder.songs[0].id)
    XCTAssertEqual(defaultPlaylist.items[0].playable.id, cdHelper.seeder.songs[0].id)
    XCTAssertEqual(defaultPlaylist.items[0].order, Int(PlaylistItemMO.orderDistance) * 1)
    XCTAssertEqual(defaultPlaylist.items[0].account?.serverHash, TestAccountInfo.test1ServerHash)
    XCTAssertEqual(defaultPlaylist.items[0].account?.userHash, TestAccountInfo.test1UserHash)
    XCTAssertEqual(defaultPlaylist.playables[1].id, cdHelper.seeder.songs[1].id)
    XCTAssertEqual(defaultPlaylist.items[1].playable.id, cdHelper.seeder.songs[1].id)
    XCTAssertEqual(defaultPlaylist.items[1].order, Int(PlaylistItemMO.orderDistance) * 2)
    XCTAssertEqual(defaultPlaylist.playables[2].id, cdHelper.seeder.songs[2].id)
    XCTAssertEqual(defaultPlaylist.items[2].playable.id, cdHelper.seeder.songs[2].id)
    XCTAssertEqual(defaultPlaylist.items[2].order, Int(PlaylistItemMO.orderDistance) * 3)
    XCTAssertEqual(defaultPlaylist.playables[3].id, cdHelper.seeder.songs[4].id)
    XCTAssertEqual(defaultPlaylist.items[3].playable.id, cdHelper.seeder.songs[4].id)
    XCTAssertEqual(defaultPlaylist.items[3].order, Int(PlaylistItemMO.orderDistance) * 4)
    XCTAssertEqual(defaultPlaylist.playables[4].id, cdHelper.seeder.songs[3].id)
    XCTAssertEqual(defaultPlaylist.items[4].playable.id, cdHelper.seeder.songs[3].id)
    XCTAssertEqual(defaultPlaylist.items[4].order, Int(PlaylistItemMO.orderDistance) * 5)
    XCTAssertEqual(defaultPlaylist.items[4].account?.serverHash, TestAccountInfo.test1ServerHash)
    XCTAssertEqual(defaultPlaylist.items[4].account?.userHash, TestAccountInfo.test1UserHash)
  }

  func testReorderLastToFirst() {
    defaultPlaylist.movePlaylistItem(fromIndex: 2, to: 0)
    XCTAssertEqual(defaultPlaylist.items[0].playable.id, cdHelper.seeder.songs[2].id)
    XCTAssertEqual(defaultPlaylist.items[1].playable.id, cdHelper.seeder.songs[0].id)
    XCTAssertEqual(defaultPlaylist.items[2].playable.id, cdHelper.seeder.songs[1].id)
  }

  func testReorderSecondToLast() {
    defaultPlaylist.movePlaylistItem(fromIndex: 1, to: 2)
    XCTAssertEqual(defaultPlaylist.items[0].playable.id, cdHelper.seeder.songs[0].id)
    XCTAssertEqual(defaultPlaylist.items[1].playable.id, cdHelper.seeder.songs[2].id)
    XCTAssertEqual(defaultPlaylist.items[2].playable.id, cdHelper.seeder.songs[1].id)
  }

  func testReorderNoChange() {
    defaultPlaylist.movePlaylistItem(fromIndex: 1, to: 1)
    XCTAssertEqual(defaultPlaylist.items[0].playable.id, cdHelper.seeder.songs[0].id)
    XCTAssertEqual(defaultPlaylist.items[1].playable.id, cdHelper.seeder.songs[1].id)
    XCTAssertEqual(defaultPlaylist.items[2].playable.id, cdHelper.seeder.songs[2].id)
  }

  func testEntryRemoval() {
    defaultPlaylist.remove(at: 1)
    XCTAssertEqual(defaultPlaylist.items.count, cdHelper.seeder.playlists[0].songIds.count - 1)
    XCTAssertEqual(defaultPlaylist.items[0].playable.id, cdHelper.seeder.songs[0].id)
    XCTAssertEqual(defaultPlaylist.items[0].order, Int(PlaylistItemMO.orderDistance) * 1)
    XCTAssertEqual(defaultPlaylist.items[1].playable.id, cdHelper.seeder.songs[2].id)
    XCTAssertEqual(defaultPlaylist.items[1].order, Int(PlaylistItemMO.orderDistance) * 3)
  }

  func testRemoveFirstOccurrenceOfSong_Success() {
    guard let song1 = library.getSong(for: account, id: cdHelper.seeder.songs[1].id)
    else { XCTFail(); return }
    defaultPlaylist.append(playable: song1)
    defaultPlaylist.remove(firstOccurrenceOfPlayable: song1)
    XCTAssertEqual(defaultPlaylist.items.count, cdHelper.seeder.playlists[0].songIds.count)
    XCTAssertEqual(defaultPlaylist.items[0].playable.id, cdHelper.seeder.songs[0].id)
    XCTAssertEqual(defaultPlaylist.items[0].order, Int(PlaylistItemMO.orderDistance) * 1)
    XCTAssertEqual(defaultPlaylist.items[1].playable.id, cdHelper.seeder.songs[2].id)
    XCTAssertEqual(defaultPlaylist.items[1].order, Int(PlaylistItemMO.orderDistance) * 3)
    XCTAssertEqual(defaultPlaylist.items[4].playable.id, song1.id)

    defaultPlaylist.remove(firstOccurrenceOfPlayable: song1)
    XCTAssertEqual(defaultPlaylist.items.count, cdHelper.seeder.playlists[0].songIds.count - 1)
    XCTAssertEqual(defaultPlaylist.items[0].playable.id, cdHelper.seeder.songs[0].id)
    XCTAssertEqual(defaultPlaylist.items[0].order, Int(PlaylistItemMO.orderDistance) * 1)
    XCTAssertEqual(defaultPlaylist.items[1].playable.id, cdHelper.seeder.songs[2].id)
    XCTAssertEqual(defaultPlaylist.items[1].order, Int(PlaylistItemMO.orderDistance) * 3)
    XCTAssertEqual(defaultPlaylist.items[3].playable.id, cdHelper.seeder.songs[3].id)
    XCTAssertEqual(defaultPlaylist.items[3].order, Int(PlaylistItemMO.orderDistance) * 5)
  }

  func testRemoveFirstOccurrenceOfSong_NoChange() {
    guard let song6 = library.getSong(for: account, id: cdHelper.seeder.songs[6].id)
    else { XCTFail(); return }
    defaultPlaylist.remove(firstOccurrenceOfPlayable: song6)
    testDefaultPlaylist()
  }

  func testRemovalAll() {
    defaultPlaylist.removeAllItems()
    XCTAssertEqual(defaultPlaylist.items.count, 0)
  }

  func testGetFirstIndex() {
    guard let song0 = library.getSong(for: account, id: cdHelper.seeder.songs[1].id)
    else { XCTFail(); return }
    guard let foundSongIndex0 = defaultPlaylist.getFirstIndex(playable: song0)
    else { XCTFail(); return }
    XCTAssertEqual(foundSongIndex0, 1)
    XCTAssertEqual(defaultPlaylist.items[foundSongIndex0].playable.id, song0.id)
    defaultPlaylist.append(playable: song0)
    guard let foundSongIndex1 = defaultPlaylist.getFirstIndex(playable: song0)
    else { XCTFail(); return }
    XCTAssertEqual(foundSongIndex1, 1)
    XCTAssertEqual(defaultPlaylist.items[foundSongIndex1].playable.id, song0.id)
    defaultPlaylist.remove(firstOccurrenceOfPlayable: song0)
    guard let foundSongIndex2 = defaultPlaylist.getFirstIndex(playable: song0)
    else { XCTFail(); return }
    XCTAssertEqual(foundSongIndex2, 4)
    XCTAssertEqual(defaultPlaylist.items[foundSongIndex2].playable.id, song0.id)
    defaultPlaylist.remove(firstOccurrenceOfPlayable: song0)
    XCTAssertEqual(defaultPlaylist.getFirstIndex(playable: song0), nil)
  }

  func testhasCachedSongs() {
    XCTAssertFalse(playlistNoCached.playables.hasCachedItems)
    XCTAssertTrue(defaultPlaylist.playables.hasCachedItems)
    XCTAssertTrue(playlistThreeCached.playables.hasCachedItems)
  }

  func testMovePlaylistSong_InvalidValues() {
    resetTestPlaylist()

    testPlaylist.movePlaylistItem(fromIndex: 0, to: 5)
    checkTestPlaylistNoChange()
    testPlaylist.movePlaylistItem(fromIndex: 0, to: 20)
    checkTestPlaylistNoChange()
    testPlaylist.movePlaylistItem(fromIndex: 5, to: 0)
    checkTestPlaylistNoChange()
    testPlaylist.movePlaylistItem(fromIndex: 20, to: 0)
    checkTestPlaylistNoChange()
    testPlaylist.movePlaylistItem(fromIndex: -1, to: 2)
    checkTestPlaylistNoChange()
    testPlaylist.movePlaylistItem(fromIndex: -9, to: 1)
    checkTestPlaylistNoChange()
    testPlaylist.movePlaylistItem(fromIndex: 1, to: -1)
    checkTestPlaylistNoChange()
    testPlaylist.movePlaylistItem(fromIndex: 1, to: -20)
    checkTestPlaylistNoChange()
    testPlaylist.movePlaylistItem(fromIndex: 1, to: 1)
    checkTestPlaylistNoChange()
    testPlaylist.movePlaylistItem(fromIndex: 4, to: 4)
    checkTestPlaylistNoChange()
    testPlaylist.movePlaylistItem(fromIndex: -5, to: 30)
    checkTestPlaylistNoChange()
    testPlaylist.movePlaylistItem(fromIndex: 30, to: -9)
    checkTestPlaylistNoChange()
  }

  func testMovePlaylistSong() {
    resetTestPlaylist()
    testPlaylist.movePlaylistItem(fromIndex: 1, to: 4)
    checkPlaylistIndexEqualSeedIndex(playlistIndex: 0, seedIndex: 0)
    checkPlaylistIndexEqualSeedIndex(playlistIndex: 1, seedIndex: 2)
    checkPlaylistIndexEqualSeedIndex(playlistIndex: 2, seedIndex: 3)
    checkPlaylistIndexEqualSeedIndex(playlistIndex: 3, seedIndex: 4)
    checkPlaylistIndexEqualSeedIndex(playlistIndex: 4, seedIndex: 1)

    resetTestPlaylist()
    testPlaylist.movePlaylistItem(fromIndex: 2, to: 3)
    checkPlaylistIndexEqualSeedIndex(playlistIndex: 0, seedIndex: 0)
    checkPlaylistIndexEqualSeedIndex(playlistIndex: 1, seedIndex: 1)
    checkPlaylistIndexEqualSeedIndex(playlistIndex: 2, seedIndex: 3)
    checkPlaylistIndexEqualSeedIndex(playlistIndex: 3, seedIndex: 2)
    checkPlaylistIndexEqualSeedIndex(playlistIndex: 4, seedIndex: 4)

    resetTestPlaylist()
    testPlaylist.movePlaylistItem(fromIndex: 2, to: 4)
    checkPlaylistIndexEqualSeedIndex(playlistIndex: 0, seedIndex: 0)
    checkPlaylistIndexEqualSeedIndex(playlistIndex: 1, seedIndex: 1)
    checkPlaylistIndexEqualSeedIndex(playlistIndex: 2, seedIndex: 3)
    checkPlaylistIndexEqualSeedIndex(playlistIndex: 3, seedIndex: 4)
    checkPlaylistIndexEqualSeedIndex(playlistIndex: 4, seedIndex: 2)

    resetTestPlaylist()
    testPlaylist.movePlaylistItem(fromIndex: 0, to: 3)
    checkPlaylistIndexEqualSeedIndex(playlistIndex: 0, seedIndex: 1)
    checkPlaylistIndexEqualSeedIndex(playlistIndex: 1, seedIndex: 2)
    checkPlaylistIndexEqualSeedIndex(playlistIndex: 2, seedIndex: 3)
    checkPlaylistIndexEqualSeedIndex(playlistIndex: 3, seedIndex: 0)
    checkPlaylistIndexEqualSeedIndex(playlistIndex: 4, seedIndex: 4)

    resetTestPlaylist()
    testPlaylist.movePlaylistItem(fromIndex: 4, to: 2)
    checkPlaylistIndexEqualSeedIndex(playlistIndex: 0, seedIndex: 0)
    checkPlaylistIndexEqualSeedIndex(playlistIndex: 1, seedIndex: 1)
    checkPlaylistIndexEqualSeedIndex(playlistIndex: 2, seedIndex: 4)
    checkPlaylistIndexEqualSeedIndex(playlistIndex: 3, seedIndex: 2)
    checkPlaylistIndexEqualSeedIndex(playlistIndex: 4, seedIndex: 3)

    resetTestPlaylist()
    testPlaylist.movePlaylistItem(fromIndex: 4, to: 1)
    checkPlaylistIndexEqualSeedIndex(playlistIndex: 0, seedIndex: 0)
    checkPlaylistIndexEqualSeedIndex(playlistIndex: 1, seedIndex: 4)
    checkPlaylistIndexEqualSeedIndex(playlistIndex: 2, seedIndex: 1)
    checkPlaylistIndexEqualSeedIndex(playlistIndex: 3, seedIndex: 2)
    checkPlaylistIndexEqualSeedIndex(playlistIndex: 4, seedIndex: 3)

    resetTestPlaylist()
    testPlaylist.movePlaylistItem(fromIndex: 3, to: 1)
    checkPlaylistIndexEqualSeedIndex(playlistIndex: 0, seedIndex: 0)
    checkPlaylistIndexEqualSeedIndex(playlistIndex: 1, seedIndex: 3)
    checkPlaylistIndexEqualSeedIndex(playlistIndex: 2, seedIndex: 1)
    checkPlaylistIndexEqualSeedIndex(playlistIndex: 3, seedIndex: 2)
    checkPlaylistIndexEqualSeedIndex(playlistIndex: 4, seedIndex: 4)

    resetTestPlaylist()
    testPlaylist.movePlaylistItem(fromIndex: 4, to: 2)
    checkPlaylistIndexEqualSeedIndex(playlistIndex: 0, seedIndex: 0)
    checkPlaylistIndexEqualSeedIndex(playlistIndex: 1, seedIndex: 1)
    checkPlaylistIndexEqualSeedIndex(playlistIndex: 2, seedIndex: 4)
    checkPlaylistIndexEqualSeedIndex(playlistIndex: 3, seedIndex: 2)
    checkPlaylistIndexEqualSeedIndex(playlistIndex: 4, seedIndex: 3)
  }

  func testMovePlaylistSongToStart() {
    resetTestPlaylist()
    testPlaylist.movePlaylistItem(fromIndex: 1, to: 0)
    checkPlaylistIndexEqualSeedIndex(playlistIndex: 0, seedIndex: 1)
    checkPlaylistIndexEqualSeedIndex(playlistIndex: 1, seedIndex: 0)
    checkPlaylistIndexEqualSeedIndex(playlistIndex: 2, seedIndex: 2)
    checkPlaylistIndexEqualSeedIndex(playlistIndex: 3, seedIndex: 3)
    checkPlaylistIndexEqualSeedIndex(playlistIndex: 4, seedIndex: 4)

    resetTestPlaylist()
    testPlaylist.movePlaylistItem(fromIndex: 2, to: 0)
    checkPlaylistIndexEqualSeedIndex(playlistIndex: 0, seedIndex: 2)
    checkPlaylistIndexEqualSeedIndex(playlistIndex: 1, seedIndex: 0)
    checkPlaylistIndexEqualSeedIndex(playlistIndex: 2, seedIndex: 1)
    checkPlaylistIndexEqualSeedIndex(playlistIndex: 3, seedIndex: 3)
    checkPlaylistIndexEqualSeedIndex(playlistIndex: 4, seedIndex: 4)

    resetTestPlaylist()
    testPlaylist.movePlaylistItem(fromIndex: 4, to: 0)
    checkPlaylistIndexEqualSeedIndex(playlistIndex: 0, seedIndex: 4)
    checkPlaylistIndexEqualSeedIndex(playlistIndex: 1, seedIndex: 0)
    checkPlaylistIndexEqualSeedIndex(playlistIndex: 2, seedIndex: 1)
    checkPlaylistIndexEqualSeedIndex(playlistIndex: 3, seedIndex: 2)
    checkPlaylistIndexEqualSeedIndex(playlistIndex: 4, seedIndex: 3)
  }

  func testMovePlaylistSongToEnd() {
    resetTestPlaylist()
    testPlaylist.movePlaylistItem(fromIndex: 0, to: 4)
    checkPlaylistIndexEqualSeedIndex(playlistIndex: 0, seedIndex: 1)
    checkPlaylistIndexEqualSeedIndex(playlistIndex: 1, seedIndex: 2)
    checkPlaylistIndexEqualSeedIndex(playlistIndex: 2, seedIndex: 3)
    checkPlaylistIndexEqualSeedIndex(playlistIndex: 3, seedIndex: 4)
    checkPlaylistIndexEqualSeedIndex(playlistIndex: 4, seedIndex: 0)

    resetTestPlaylist()
    testPlaylist.movePlaylistItem(fromIndex: 2, to: 4)
    checkPlaylistIndexEqualSeedIndex(playlistIndex: 0, seedIndex: 0)
    checkPlaylistIndexEqualSeedIndex(playlistIndex: 1, seedIndex: 1)
    checkPlaylistIndexEqualSeedIndex(playlistIndex: 2, seedIndex: 3)
    checkPlaylistIndexEqualSeedIndex(playlistIndex: 3, seedIndex: 4)
    checkPlaylistIndexEqualSeedIndex(playlistIndex: 4, seedIndex: 2)
  }
}
