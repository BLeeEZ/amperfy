//
//  BackgroundSyncRunStateTest.swift
//  AmperfyKitTests
//
//  Created by Chrizz Gelbach on 16.11.26.
//  Copyright (c) 2026 Chrizz Gelbach. All rights reserved.
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

final class BackgroundSyncRunStateTest: XCTestCase {
  private typealias RunEnd = BackgroundSyncRunState.RunEnd

  func testStartWhenIdleStartsARun() {
    var state = BackgroundSyncRunState()
    XCTAssertEqual(state.start(), 1)
    XCTAssertTrue(state.isCurrent(1))
  }

  func testStartWhileRunningContinuesTheCurrentRun() {
    var state = BackgroundSyncRunState()
    let run = state.start()!
    XCTAssertNil(state.start())
    XCTAssertEqual(
      state.finishRun(run, isCompleted: true, isOnlineAndConnected: true),
      RunEnd(isCurrent: true, nextGeneration: nil)
    )
    XCTAssertNil(state.current)
    XCTAssertFalse(state.isEndedEarly)
  }

  func testRunEndedEarlyWhileStillOfflineWaitsForReconnect() {
    var state = BackgroundSyncRunState()
    let run = state.start()!
    XCTAssertEqual(
      state.finishRun(run, isCompleted: false, isOnlineAndConnected: false),
      RunEnd(isCurrent: true, nextGeneration: nil)
    )
    XCTAssertTrue(state.isEndedEarly)
    XCTAssertEqual(state.startAfterReconnect(), run + 1)
    XCTAssertFalse(state.isEndedEarly)
    // a second reconnect while the new run goes on starts nothing
    XCTAssertNil(state.startAfterReconnect())
  }

  func testRunEndedEarlyWhenAlreadyOnlineAgainStartsTheNextRun() {
    var state = BackgroundSyncRunState()
    let run = state.start()!
    // the reconnect came while the run was still ending: it starts nothing itself
    XCTAssertNil(state.startAfterReconnect())
    XCTAssertEqual(
      state.finishRun(run, isCompleted: false, isOnlineAndConnected: true),
      RunEnd(isCurrent: true, nextGeneration: run + 1)
    )
    XCTAssertTrue(state.isCurrent(run + 1))
    XCTAssertFalse(state.isEndedEarly)
  }

  func testCompletedRunDoesNotStartAfterReconnect() {
    var state = BackgroundSyncRunState()
    let run = state.start()!
    _ = state.finishRun(run, isCompleted: true, isOnlineAndConnected: false)
    XCTAssertNil(state.startAfterReconnect())
  }

  func testStoppedRunNeitherNotifiesNorRestarts() {
    var state = BackgroundSyncRunState()
    let run = state.start()!
    state.stop()
    XCTAssertFalse(state.isCurrent(run))
    XCTAssertEqual(
      state.finishRun(run, isCompleted: false, isOnlineAndConnected: true),
      RunEnd(isCurrent: false, nextGeneration: nil)
    )
    XCTAssertNil(state.startAfterReconnect())
  }

  func testStopAfterEarlyEndPreventsTheRestart() {
    var state = BackgroundSyncRunState()
    let run = state.start()!
    _ = state.finishRun(run, isCompleted: false, isOnlineAndConnected: false)
    state.stop()
    XCTAssertNil(state.startAfterReconnect())
  }

  func testStopThenStartReplacesTheRunningOne() {
    var state = BackgroundSyncRunState()
    let oldRun = state.start()!
    state.stop()
    // the old run may not have noticed the stop yet: the new generation ends it anyway
    let newRun = state.start()!
    XCTAssertNotEqual(oldRun, newRun)
    XCTAssertFalse(state.isCurrent(oldRun))
    // the old run ending neither ends, notifies for nor restarts the new one
    XCTAssertEqual(
      state.finishRun(oldRun, isCompleted: false, isOnlineAndConnected: true),
      RunEnd(isCurrent: false, nextGeneration: nil)
    )
    XCTAssertTrue(state.isCurrent(newRun))
    XCTAssertEqual(
      state.finishRun(newRun, isCompleted: true, isOnlineAndConnected: true),
      RunEnd(isCurrent: true, nextGeneration: nil)
    )
    XCTAssertNil(state.current)
  }
}
