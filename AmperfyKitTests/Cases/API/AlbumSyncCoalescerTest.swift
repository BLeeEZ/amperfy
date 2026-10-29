//
//  AlbumSyncCoalescerTest.swift
//  AmperfyKitTests
//
//  Created by Jerome Mohm on 08.10.26.
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
import CoreData
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
  var claimedObjectIDs = [NSManagedObjectID]()
  var albumSyncsFinishedBeforeExclusiveSync: Int?
  var batchesFinishedBeforeAlbumSync: Int?
  var exclusiveSyncsFinishedBeforeAlbumSync: Int?
  var batchesFinishedBeforeExclusiveSync: Int?
  var exclusiveSyncsFinishedBeforeBatch: Int?

  override func setUp() async throws {
    cdHelper = CoreDataHelper()
    library = cdHelper.createSeededStorage()
    account = library.getAccount(info: TestAccountInfo.create1())
    operation = MOCK_GatedAlbumSyncOperation()
    isFirstCallerReturned = false
    claimedObjectIDs = []
    albumSyncsFinishedBeforeExclusiveSync = nil
    batchesFinishedBeforeAlbumSync = nil
    exclusiveSyncsFinishedBeforeAlbumSync = nil
    batchesFinishedBeforeExclusiveSync = nil
    exclusiveSyncsFinishedBeforeBatch = nil
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
  /// operation as well and the count would be 2.
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

  /// A batch must leave out an album whose sync is in flight and await that
  /// sync instead of syncing the album a second time.
  func testBatchSkipsAlbumInFlightAndAwaitsIt() async throws {
    let batchRan = expectation(description: "batch ran its operation")
    let albumEntered = expectation(description: "album sync entered the operation")
    operation.onEntered = { count in
      if count == 1 { albumEntered.fulfill() }
    }
    let albumSync = startSync(of: album)
    await fulfillment(of: [albumEntered], timeout: 2)

    let albumObjectIDs = [album.managedObject.objectID, otherAlbum.managedObject.objectID]
    let batch = Task { @MainActor in
      await AlbumSyncCoalescer.sync(albumObjectIDs: albumObjectIDs) { claimedObjectIDs in
        self.claimedObjectIDs = claimedObjectIDs
        batchRan.fulfill()
      }
      self.isFirstCallerReturned = true
    }
    await fulfillment(of: [batchRan], timeout: 2)
    XCTAssertEqual(claimedObjectIDs, [otherAlbum.managedObject.objectID])
    XCTAssertFalse(isFirstCallerReturned)

    operation.openGate()
    try await albumSync.value
    await batch.value
    XCTAssertTrue(isFirstCallerReturned)
    XCTAssertEqual(operation.runCount, 1)
  }

  /// An album sync that finds the album claimed by a batch must wait for the
  /// batch and then sync the album itself, so its caller gets the album's own
  /// result instead of the batch's.
  func testAlbumSyncWaitsForBatchThenSyncsItself() async throws {
    let batchOperation = MOCK_GatedAlbumSyncOperation()
    let batchEntered = expectation(description: "batch entered the operation")
    batchOperation.onEntered = { _ in batchEntered.fulfill() }
    let albumObjectIDs = [album.managedObject.objectID]
    let batch = Task { @MainActor in
      await AlbumSyncCoalescer.sync(albumObjectIDs: albumObjectIDs) { _ in
        try? await batchOperation.run()
      }
    }
    await fulfillment(of: [batchEntered], timeout: 2)

    operation.openGate()
    operation.onEntered = { _ in
      self.batchesFinishedBeforeAlbumSync = batchOperation.isCancelledAfterGate.count
    }
    let albumSyncJoined = expectation(description: "album sync joined")
    let albumSync = startSync(of: album, joined: albumSyncJoined)
    await fulfillment(of: [albumSyncJoined], timeout: 2)
    XCTAssertEqual(operation.runCount, 0)

    batchOperation.openGate()
    await batch.value
    try await albumSync.value
    XCTAssertEqual(batchesFinishedBeforeAlbumSync, 1)
    XCTAssertEqual(batchOperation.runCount, 1)
    XCTAssertEqual(operation.runCount, 1)
  }

  /// An exclusive sync must only start once every album sync in flight has
  /// finished, and an album sync started meanwhile, of any album, must wait
  /// for it and then sync the album itself.
  func testExclusiveSyncWaitsForAlbumSyncsInFlightAndBlocksNewOnes() async throws {
    let operation = operation!
    let otherAlbum = otherAlbum!
    let exclusiveOperation = MOCK_GatedAlbumSyncOperation()
    let otherOperation = MOCK_GatedAlbumSyncOperation()
    otherOperation.openGate()
    let albumEntered = expectation(description: "album sync entered the operation")
    operation.onEntered = { count in
      if count == 1 { albumEntered.fulfill() }
    }
    let albumSync = startSync(of: album)
    await fulfillment(of: [albumEntered], timeout: 2)

    let exclusiveJoined = expectation(description: "exclusive sync joined")
    let exclusiveEntered = expectation(description: "exclusive sync entered the operation")
    exclusiveOperation.onEntered = { _ in exclusiveEntered.fulfill() }
    let exclusiveSync = Task { @MainActor in
      exclusiveJoined.fulfill()
      return try await AlbumSyncCoalescer.syncExclusively {
        self.albumSyncsFinishedBeforeExclusiveSync = operation.isCancelledAfterGate.count
        try await exclusiveOperation.run()
        return 42
      }
    }
    await fulfillment(of: [exclusiveJoined], timeout: 2)
    XCTAssertEqual(exclusiveOperation.runCount, 0)

    operation.openGate()
    await fulfillment(of: [exclusiveEntered], timeout: 2)
    otherOperation.onEntered = { _ in
      self.exclusiveSyncsFinishedBeforeAlbumSync = exclusiveOperation.isCancelledAfterGate.count
    }
    let otherAlbumSyncJoined = expectation(description: "other album sync joined")
    let otherAlbumSync = Task { @MainActor in
      otherAlbumSyncJoined.fulfill()
      try await AlbumSyncCoalescer.sync(otherAlbum) {
        try await otherOperation.run()
      }
    }
    await fulfillment(of: [otherAlbumSyncJoined], timeout: 2)
    XCTAssertEqual(otherOperation.runCount, 0)

    exclusiveOperation.openGate()
    let result = try await exclusiveSync.value
    try await otherAlbumSync.value
    try await albumSync.value
    XCTAssertEqual(result, 42)
    XCTAssertEqual(albumSyncsFinishedBeforeExclusiveSync, 1)
    XCTAssertEqual(exclusiveSyncsFinishedBeforeAlbumSync, 1)
    XCTAssertEqual(operation.runCount, 1)
    XCTAssertEqual(exclusiveOperation.runCount, 1)
    XCTAssertEqual(otherOperation.runCount, 1)
  }

  /// An exclusive sync must also wait for a batch in flight, and a batch
  /// started meanwhile must wait until the exclusive sync has finished.
  func testExclusiveSyncWaitsForBatchAndBlocksNewBatches() async throws {
    let batchOperation = MOCK_GatedAlbumSyncOperation()
    let exclusiveOperation = MOCK_GatedAlbumSyncOperation()
    let batchEntered = expectation(description: "batch entered the operation")
    batchOperation.onEntered = { _ in batchEntered.fulfill() }
    let albumObjectIDs = [album.managedObject.objectID]
    let batch = Task { @MainActor in
      await AlbumSyncCoalescer.sync(albumObjectIDs: albumObjectIDs) { _ in
        try? await batchOperation.run()
      }
    }
    await fulfillment(of: [batchEntered], timeout: 2)

    let exclusiveJoined = expectation(description: "exclusive sync joined")
    let exclusiveEntered = expectation(description: "exclusive sync entered the operation")
    exclusiveOperation.onEntered = { _ in exclusiveEntered.fulfill() }
    let exclusiveSync = Task { @MainActor in
      exclusiveJoined.fulfill()
      try await AlbumSyncCoalescer.syncExclusively {
        self.batchesFinishedBeforeExclusiveSync = batchOperation.isCancelledAfterGate.count
        try await exclusiveOperation.run()
      }
    }
    await fulfillment(of: [exclusiveJoined], timeout: 2)

    batchOperation.openGate()
    await fulfillment(of: [exclusiveEntered], timeout: 2)
    let otherAlbumObjectIDs = [otherAlbum.managedObject.objectID]
    let secondBatchJoined = expectation(description: "second batch joined")
    let secondBatch = Task { @MainActor in
      secondBatchJoined.fulfill()
      await AlbumSyncCoalescer.sync(albumObjectIDs: otherAlbumObjectIDs) { _ in
        self.exclusiveSyncsFinishedBeforeBatch = exclusiveOperation.isCancelledAfterGate.count
      }
    }
    await fulfillment(of: [secondBatchJoined], timeout: 2)

    exclusiveOperation.openGate()
    await batch.value
    try await exclusiveSync.value
    await secondBatch.value
    XCTAssertEqual(batchesFinishedBeforeExclusiveSync, 1)
    XCTAssertEqual(exclusiveSyncsFinishedBeforeBatch, 1)
  }

  /// An album sync started while an exclusive sync still waits for the syncs
  /// in flight must wait for the exclusive sync as well, not slip in before it.
  func testAlbumSyncStartedWhileExclusiveSyncWaitsIsBlocked() async throws {
    let operation = operation!
    let otherAlbum = otherAlbum!
    let exclusiveOperation = MOCK_GatedAlbumSyncOperation()
    let otherOperation = MOCK_GatedAlbumSyncOperation()
    otherOperation.openGate()
    let albumEntered = expectation(description: "album sync entered the operation")
    operation.onEntered = { count in
      if count == 1 { albumEntered.fulfill() }
    }
    let albumSync = startSync(of: album)
    await fulfillment(of: [albumEntered], timeout: 2)

    let exclusiveJoined = expectation(description: "exclusive sync joined")
    let exclusiveSync = Task { @MainActor in
      exclusiveJoined.fulfill()
      try await AlbumSyncCoalescer.syncExclusively {
        try await exclusiveOperation.run()
      }
    }
    await fulfillment(of: [exclusiveJoined], timeout: 2)

    otherOperation.onEntered = { _ in
      self.exclusiveSyncsFinishedBeforeAlbumSync = exclusiveOperation.isCancelledAfterGate.count
    }
    let otherAlbumSyncJoined = expectation(description: "other album sync joined")
    let otherAlbumSync = Task { @MainActor in
      otherAlbumSyncJoined.fulfill()
      try await AlbumSyncCoalescer.sync(otherAlbum) {
        try await otherOperation.run()
      }
    }
    await fulfillment(of: [otherAlbumSyncJoined], timeout: 2)
    XCTAssertEqual(otherOperation.runCount, 0)

    exclusiveOperation.openGate()
    operation.openGate()
    try await albumSync.value
    try await exclusiveSync.value
    try await otherAlbumSync.value
    XCTAssertEqual(exclusiveSyncsFinishedBeforeAlbumSync, 1)
    XCTAssertEqual(otherOperation.runCount, 1)
  }
}
