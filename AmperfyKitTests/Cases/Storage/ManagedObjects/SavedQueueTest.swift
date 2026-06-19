//
//  SavedQueueTest.swift
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
class SavedQueueTest: XCTestCase {
  var cdHelper: CoreDataHelper!
  var library: LibraryStorage!
  var account: Account!

  override func setUp() async throws {
    cdHelper = CoreDataHelper()
    library = cdHelper.createSeededStorage()
    account = library.getAccount(info: TestAccountInfo.create1())
  }

  override func tearDown() {}

  func makeSavedQueue() -> SavedQueue {
    library.createSavedQueue(account: account)
  }

  func testEmptyIdArraysDecodeAsEmpty() {
    let sq = makeSavedQueue()
    XCTAssertEqual(sq.contextSongIds, [])
    XCTAssertEqual(sq.userQueueSongIds, [])
  }

  func testRoundTripContextSongIds() {
    let sq = makeSavedQueue()
    sq.contextSongIds = ["a", "b", "c"]
    XCTAssertEqual(sq.contextSongIds, ["a", "b", "c"])
  }

  func testRoundTripUserQueueSongIds() {
    let sq = makeSavedQueue()
    sq.userQueueSongIds = ["x", "y"]
    XCTAssertEqual(sq.userQueueSongIds, ["x", "y"])
  }

  func testPlayerModeDefaultsToMusic() {
    let sq = makeSavedQueue()
    XCTAssertEqual(sq.playerMode, .music)
  }

  func testRepeatModeRoundTrip() {
    let sq = makeSavedQueue()
    sq.repeatMode = .all
    XCTAssertEqual(sq.repeatMode, .all)
  }
}
