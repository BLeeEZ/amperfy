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
  func testStartWhenIdleStartsARun() {
    var state = BackgroundSyncRunState()
    XCTAssertEqual(state.start(), 1)
    XCTAssertTrue(state.isCurrent(1))
  }

  func testStartDuringACompletedRunStartsNoNewRun() {
    var state = BackgroundSyncRunState()
    let run = state.start()!
    XCTAssertNil(state.start())
    XCTAssertTrue(state.isCurrent(run))
    XCTAssertNil(state.finishRun(run, isCompleted: true))
    XCTAssertNil(state.current)
  }

  func testStartDuringARunThatEndedEarlyStartsANewRun() {
    var state = BackgroundSyncRunState()
    let run = state.start()!
    // e.g. going online again while the run already decided to end because it was offline
    XCTAssertNil(state.start())
    let nextRun = state.finishRun(run, isCompleted: false)
    XCTAssertEqual(nextRun, run + 1)
    XCTAssertTrue(state.isCurrent(run + 1))
    // the new run ends early as well, without another start(): nothing follows
    XCTAssertNil(state.finishRun(run + 1, isCompleted: false))
    XCTAssertNil(state.current)
  }

  func testRunEndedEarlyWithoutStartStartsNoNewRun() {
    var state = BackgroundSyncRunState()
    let run = state.start()!
    XCTAssertNil(state.finishRun(run, isCompleted: false))
    XCTAssertNil(state.current)
    XCTAssertEqual(state.start(), run + 1)
  }

  func testStopEndsTheRun() {
    var state = BackgroundSyncRunState()
    let run = state.start()!
    state.stop()
    XCTAssertFalse(state.isCurrent(run))
    XCTAssertNil(state.finishRun(run, isCompleted: false))
    XCTAssertNil(state.current)
  }

  func testStopThenStartReplacesTheRunningOne() {
    var state = BackgroundSyncRunState()
    let oldRun = state.start()!
    state.stop()
    // the old run may not have noticed the stop yet: the new generation ends it anyway
    let newRun = state.start()!
    XCTAssertNotEqual(oldRun, newRun)
    XCTAssertFalse(state.isCurrent(oldRun))
    XCTAssertFalse(state.isStartRequested)
    // the old run ending neither ends nor restarts the new one
    XCTAssertNil(state.finishRun(oldRun, isCompleted: false))
    XCTAssertTrue(state.isCurrent(newRun))
    XCTAssertNil(state.finishRun(newRun, isCompleted: true))
    XCTAssertNil(state.current)
  }
}
