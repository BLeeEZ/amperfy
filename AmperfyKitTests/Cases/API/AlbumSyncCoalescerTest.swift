//
//  AlbumSyncCoalescerTest.swift
//  AmperfyKitTests
//
//  Created by Maximilian Bauer on 08.10.26.
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

// MARK: - MOCK_AlbumSyncError

struct MOCK_AlbumSyncError: Error {}

// MARK: - MOCK_GatedAlbumSyncOperation

/// Stands in for an album sync: counts how often it is entered and blocks each
/// entry on a gate the test opens explicitly. Once opened, the gate stays open,
/// so a sync entered later runs straight through instead of hanging the test.
@MainActor
final class MOCK_GatedAlbumSyncOperation {
  private(set) var runCount = 0
  /// `Task.isCancelled` as seen by each run after the gate opened.
  private(set) var isCancelledAfterGate = [Bool]()
  var errorToThrow: Error?
  var onEntered: ((Int) -> ())?
  private var isGateOpen = false
  private var gateContinuations = [CheckedContinuation<(), Never>]()

  func openGate() {
    isGateOpen = true
    let continuations = gateContinuations
    gateContinuations.removeAll()
    for continuation in continuations {
      continuation.resume()
    }
  }

  func run() async throws {
    runCount += 1
    onEntered?(runCount)
    if !isGateOpen {
      await withCheckedContinuation { continuation in
        gateContinuations.append(continuation)
      }
    }
    isCancelledAfterGate.append(Task.isCancelled)
    if let errorToThrow {
      throw errorToThrow
    }
  }
}

// MARK: - AlbumSyncCoalescerTest

@MainActor
class AlbumSyncCoalescerTest: XCTestCase {
  var cdHelper: CoreDataHelper!
  var library: LibraryStorage!
  var account: Account!
  var operation: MOCK_GatedAlbumSyncOperation!
  var album: Album!
  var otherAlbum: Album!
  var isFirstCallerReturned = false

  override func setUp() async throws {
    cdHelper = CoreDataHelper()
    library = cdHelper.createSeededStorage()
    account = library.getAccount(info: TestAccountInfo.create1())
    operation = MOCK_GatedAlbumSyncOperation()
    isFirstCallerReturned = false
    // Two distinct albums that share the same (empty) server id: an unsynced
    // album carries id "", so keying the coalescing on the server id would
    // wrongly merge them. See testDistinctAlbumsWithSameServerIdAreNotCoalesced.
    album = library.createAlbum(account: account)
    album.id = ""
    otherAlbum = library.createAlbum(account: account)
    otherAlbum.id = ""
    library.saveContext()
  }

  override func tearDown() {}

  /// Starts a sync of `album` through the coalescer. `joined` is fulfilled right
  /// before the call; both run on the main actor without a suspension point in
  /// between, so once the test has awaited `joined`, the caller is already
  /// awaiting a sync inside the coalescer.
  private func startSync(of album: Album, joined: XCTestExpectation? = nil) -> Task<(), Error> {
    let operation = operation!
    return Task { @MainActor in
      joined?.fulfill()
      try await AlbumSyncCoalescer.sync(album) {
        try await operation.run()
      }
    }
  }

  private func assertThrowsAlbumSyncError(
    _ task: Task<(), Error>,
    file: StaticString = #filePath,
    line: UInt = #line
  ) async {
    do {
      try await task.value
      XCTFail("album sync did not throw", file: file, line: line)
    } catch {
      XCTAssertTrue(error is MOCK_AlbumSyncError, file: file, line: line)
    }
  }

  /// Two overlapping syncs of the same album must run the sync only once
  /// (upstream issue #778). Without coalescing the second caller would run the
  /// operation through the open gate as well and the count would be 2.
  func testConcurrentSyncOfSameAlbumRunsOnce() async throws {
    let firstEntered = expectation(description: "first sync entered the operation")
    operation.onEntered = { count in
      if count == 1 { firstEntered.fulfill() }
    }
    let first = startSync(of: album)
    await fulfillment(of: [firstEntered], timeout: 2)

    let secondJoined = expectation(description: "second caller joined")
    let second = startSync(of: album, joined: secondJoined)
    await fulfillment(of: [secondJoined], timeout: 2)

    operation.openGate()
    try await first.value
    try await second.value
    XCTAssertEqual(operation.runCount, 1)
  }

  /// A sync started after the previous one finished must run again; coalescing
  /// only applies while a sync is in flight.
  func testSyncAfterCompletionRunsAgain() async throws {
    operation.openGate()
    try await startSync(of: album).value
    XCTAssertEqual(operation.runCount, 1)

    try await startSync(of: album).value
    XCTAssertEqual(operation.runCount, 2)
  }

  /// A failing sync hands its error to every caller that awaited it, and the
  /// failed sync is not kept: the next sync of the album runs again.
  func testFailedSyncIsSharedAndRunsAgainAfterwards() async throws {
    operation.errorToThrow = MOCK_AlbumSyncError()
    let firstEntered = expectation(description: "first sync entered the operation")
    operation.onEntered = { count in
      if count == 1 { firstEntered.fulfill() }
    }
    let first = startSync(of: album)
    await fulfillment(of: [firstEntered], timeout: 2)

    let secondJoined = expectation(description: "second caller joined")
    let second = startSync(of: album, joined: secondJoined)
    await fulfillment(of: [secondJoined], timeout: 2)

    operation.openGate()
    await assertThrowsAlbumSyncError(first)
    await assertThrowsAlbumSyncError(second)
    XCTAssertEqual(operation.runCount, 1)

    operation.errorToThrow = nil
    try await startSync(of: album).value
    XCTAssertEqual(operation.runCount, 2)
  }

  /// Two different albums that happen to share a server id (here the empty id
  /// of unsynced albums) must each be synced; coalescing keys on the local
  /// object identity, not the server id. Keying on the server id would merge
  /// them and this test would time out at one entry.
  func testDistinctAlbumsWithSameServerIdAreNotCoalesced() async throws {
    let bothEntered = expectation(description: "both albums entered the operation")
    bothEntered.expectedFulfillmentCount = 2
    operation.onEntered = { _ in bothEntered.fulfill() }

    let first = startSync(of: album)
    let second = startSync(of: otherAlbum)
    await fulfillment(of: [bothEntered], timeout: 2)
    XCTAssertEqual(operation.runCount, 2)

    operation.openGate()
    try await first.value
    try await second.value
  }

  /// Cancelling one caller must not cancel the shared sync that other callers
  /// await (task groups cancel their remaining children when one child throws).
  /// The cancelled caller keeps waiting until the shared sync has finished.
  func testCancelledCallerDoesNotCancelSharedSync() async throws {
    let operation = operation!
    let firstEntered = expectation(description: "first sync entered the operation")
    operation.onEntered = { count in
      if count == 1 { firstEntered.fulfill() }
    }
    let first = Task { @MainActor in
      try await AlbumSyncCoalescer.sync(self.album) {
        try await operation.run()
      }
      self.isFirstCallerReturned = true
    }
    await fulfillment(of: [firstEntered], timeout: 2)

    let secondJoined = expectation(description: "second caller joined")
    let second = startSync(of: album, joined: secondJoined)
    await fulfillment(of: [secondJoined], timeout: 2)

    first.cancel()
    let thirdJoined = expectation(description: "third caller joined")
    let third = startSync(of: album, joined: thirdJoined)
    await fulfillment(of: [thirdJoined], timeout: 2)
    XCTAssertFalse(isFirstCallerReturned)

    operation.openGate()
    try await first.value
    try await second.value
    try await third.value
    XCTAssertTrue(isFirstCallerReturned)
    XCTAssertEqual(operation.runCount, 1)
    XCTAssertEqual(operation.isCancelledAfterGate, [false])
  }
}
