//
//  CacheRelocationTest.swift
//  AmperfyKit
//
//  Copyright (c) 2026 Amperfy contributors. All rights reserved.
//
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//

@testable import AmperfyKit
import XCTest

// MARK: - CacheRelocationTest

final class CacheRelocationTest: XCTestCase {
  private var root: URL!
  override func setUpWithError() throws {
    root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
  }

  override func tearDownWithError() throws { try FileManager.default.removeItem(at: root) }

  private func runtime(store: RelocationPreferenceStore) -> CacheRootRuntime {
    CacheRootRuntime(
      preferenceStore: store,
      activationStore: DurableExternalCacheActivationStore(
        transactionURL: root
          .appendingPathComponent("activation.json")
      ),
      defaultRootProvider: { [root = root!] in
        root.appendingPathComponent("internal")
      },
      bookmarkClient: RelocationBookmarkClient(),
      relocationURL: root.appendingPathComponent("relocation.json")
    )
  }

  private func destination() throws -> URL {
    let parent = root.appendingPathComponent("external")
    try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)
    return parent
  }

  private func writePayload(_ source: URL) throws -> URL {
    let file = source.appendingPathComponent("accounts/server/user/songs/a # % ?.mp3")
    try FileManager.default.createDirectory(
      at: file.deletingLastPathComponent(),
      withIntermediateDirectories: true
    )
    try Data(repeating: 47, count: 2 * 1024 * 1024).write(to: file)
    return file
  }

  func testRoundTripPreservesBytesAndMovesBackToBuiltInStorage() throws {
    let store = RelocationPreferenceStore()
    let runtime = runtime(store: store)
    try runtime.bootstrap()
    let internalRoot = try runtime.registry.currentLease().rootURL
    let source = try writePayload(internalRoot)
    let expected = try Data(contentsOf: source)
    let parent = try destination()
    let oldLease = try runtime.registry.currentLease()
    try runtime.relocateCache(
      to: runtime.prepareExternal(selectedParentURL: parent),
      progress: { _ in }
    )
    XCTAssertThrowsError(try oldLease.validateCurrent())
    XCTAssertEqual(try store.load().mode, .external)
    let externalRoot = try runtime.registry.currentLease().rootURL
    let file = externalRoot.appendingPathComponent("accounts/server/user/songs/a # % ?.mp3")
    XCTAssertEqual(try Data(contentsOf: file), expected)
    XCTAssertFalse(FileManager.default.fileExists(atPath: source.path))
    XCTAssertFalse(runtime.hasUnfinishedMove)
    try runtime.relocateCache(to: nil, progress: { _ in })
    XCTAssertEqual(try store.load().mode, .default)
    XCTAssertEqual(try Data(contentsOf: source), expected)
    XCTAssertFalse(FileManager.default.fileExists(atPath: file.path))
  }

  func testCancellationDuringInventoryLeavesSourceAvailable() throws {
    let store = RelocationPreferenceStore()
    let runtime = runtime(store: store)
    try runtime.bootstrap()
    let source = try writePayload(runtime.registry.currentLease().rootURL)
    let parent = try destination()
    XCTAssertThrowsError(try runtime.relocateCache(
      to: runtime.prepareExternal(selectedParentURL: parent),
      progress: { _ in },
      checkCancellation: { throw CancellationError() }
    ))
    XCTAssertEqual(try store.load().mode, .default)
    XCTAssertTrue(FileManager.default.fileExists(atPath: source.path))
    XCTAssertTrue(try FileManager.default.contentsOfDirectory(atPath: parent.path).isEmpty)
    XCTAssertFalse(runtime.hasUnfinishedMove)
    XCTAssertTrue(runtime.isCacheAvailable)
  }

  func testCancellationDuringCopyPreservesSourceAndCleansTemporaryFiles() throws {
    let store = RelocationPreferenceStore()
    let runtime = runtime(store: store)
    try runtime.bootstrap()
    let source = try writePayload(runtime.registry.currentLease().rootURL)
    let parent = try destination()
    let cancel = RelocationCancellation()
    XCTAssertThrowsError(try runtime.relocateCache(
      to: runtime.prepareExternal(selectedParentURL: parent),
      progress: { update in if update.completedBytes > 0 { cancel.cancel() } },
      checkCancellation: { try cancel.check() }
    ))
    XCTAssertEqual(try store.load().mode, .default)
    XCTAssertTrue(FileManager.default.fileExists(atPath: source.path))
    XCTAssertTrue(try FileManager.default.contentsOfDirectory(atPath: parent.path).isEmpty)
    XCTAssertFalse(runtime.hasUnfinishedMove)
    XCTAssertTrue(runtime.isCacheAvailable)
  }

  func testPreferenceFailureRollsBackVerifiedDestination() throws {
    let store = RelocationPreferenceStore(failExternalSave: true)
    let runtime = runtime(store: store)
    try runtime.bootstrap()
    let source = try writePayload(runtime.registry.currentLease().rootURL)
    let parent = try destination()
    XCTAssertThrowsError(try runtime.relocateCache(
      to: runtime.prepareExternal(selectedParentURL: parent),
      progress: { _ in }
    ))
    XCTAssertEqual(try store.load().mode, .default)
    XCTAssertTrue(FileManager.default.fileExists(atPath: source.path))
    XCTAssertTrue(try FileManager.default.contentsOfDirectory(atPath: parent.path).isEmpty)
  }

  func testRecoveryAfterCopyBeforePreferenceCommitKeepsOriginal() throws {
    let store = RelocationPreferenceStore()
    let runtime = runtime(store: store)
    try runtime.bootstrap()
    let sourceRoot = try runtime.registry.currentLease().rootURL
    let file = try writePayload(sourceRoot)
    let parent = try destination()
    let prepared = try runtime.prepareExternal(selectedParentURL: parent)
    defer { prepared.cancel() }
    let id = UUID()
    let move = CacheRelocationRecord(
      source: sourceRoot,
      destination: parent
        .appendingPathComponent(CacheMarker.childDirectoryName),
      oldPreference: try store.load(),
      newPreference: CacheLocationPreference(
        mode: .external,
        bookmarkData: prepared.bookmarkData,
        displayName: parent.lastPathComponent,
        cacheID: id
      ),
      cacheID: id,
      inventory: try CacheInventoryBuilder()
        .build(rootURL: sourceRoot)
    )
    try DurableAtomicFileStore().write(move, to: root.appendingPathComponent("relocation.json"))
    try CacheRelocationCopy.copy(move, progress: { _ in }, checkCancellation: {})
    let restarted = self.runtime(store: store)
    try restarted.bootstrap()
    try restarted.finishInterruptedMove()
    XCTAssertTrue(FileManager.default.fileExists(atPath: file.path))
    XCTAssertFalse(FileManager.default.fileExists(atPath: move.destination.path))
    XCTAssertFalse(restarted.hasUnfinishedMove)
  }

  func testRecoveryAfterPreferenceCommitFinishesSourceCleanup() throws {
    let store = RelocationPreferenceStore()
    let runtime = runtime(store: store)
    try runtime.bootstrap()
    let sourceRoot = try runtime.registry.currentLease().rootURL
    let original = try writePayload(sourceRoot)
    let parent = try destination()
    let prepared = try runtime.prepareExternal(selectedParentURL: parent)
    defer { prepared.cancel() }
    let id = UUID()
    let preference = CacheLocationPreference(
      mode: .external,
      bookmarkData: prepared.bookmarkData,
      displayName: parent.lastPathComponent,
      cacheID: id
    )
    let move = CacheRelocationRecord(
      source: sourceRoot,
      destination: parent
        .appendingPathComponent(CacheMarker.childDirectoryName),
      oldPreference: try store.load(),
      newPreference: preference,
      cacheID: id,
      inventory: try CacheInventoryBuilder()
        .build(rootURL: sourceRoot)
    )
    try DurableAtomicFileStore().write(move, to: root.appendingPathComponent("relocation.json"))
    try CacheRelocationCopy.copy(move, progress: { _ in }, checkCancellation: {})
    try store.save(preference)
    let restarted = self.runtime(store: store)
    try restarted.bootstrap()
    try restarted.finishInterruptedMove()
    XCTAssertFalse(FileManager.default.fileExists(atPath: original.path))
    XCTAssertTrue(FileManager.default.fileExists(
      atPath: move.destination
        .appendingPathComponent("accounts/server/user/songs/a # % ?.mp3").path
    ))
    XCTAssertFalse(restarted.hasUnfinishedMove)
  }

  func testPopulatedDestinationIsNeverOverwritten() throws {
    let store = RelocationPreferenceStore()
    let runtime = runtime(store: store)
    try runtime.bootstrap()
    let source = try writePayload(runtime.registry.currentLease().rootURL)
    let parent = try destination()
    let existing = parent.appendingPathComponent(CacheMarker.childDirectoryName)
    let otherFile = try writePayload(existing)
    let marker = CacheMarker(cacheID: UUID())
    try DurableAtomicFileStore().write(
      marker,
      to: existing.appendingPathComponent(CacheMarker.fileName)
    )
    XCTAssertThrowsError(try runtime.relocateCache(
      to: runtime.prepareExternal(selectedParentURL: parent),
      progress: { _ in }
    ))
    XCTAssertTrue(FileManager.default.fileExists(atPath: source.path))
    XCTAssertTrue(FileManager.default.fileExists(atPath: otherFile.path))
    XCTAssertEqual(try DurableAtomicFileStore().read(
      CacheMarker.self,
      from: existing.appendingPathComponent(CacheMarker.fileName)
    ), marker)
    XCTAssertTrue(runtime.isCacheAvailable)
  }

  func testMissingSourceCannotBeInventoriedAsEmpty() throws {
    XCTAssertThrowsError(
      try CacheInventoryBuilder()
        .build(rootURL: root.appendingPathComponent("missing"))
    )
  }

  func testUnpluggedCacheRejectsLeaseAndReconnectsWithoutFallback() throws {
    let store = RelocationPreferenceStore()
    let runtime = runtime(store: store)
    try runtime.bootstrap()
    _ = try writePayload(runtime.registry.currentLease().rootURL)
    let parent = try destination()
    try runtime.relocateCache(
      to: runtime.prepareExternal(selectedParentURL: parent),
      progress: { _ in }
    )
    let lease = try runtime.registry.currentLease()
    let detached = root.appendingPathComponent("detached")
    try FileManager.default.moveItem(at: parent, to: detached)
    XCTAssertThrowsError(try lease.validateCurrent())
    runtime.refreshAvailability()
    XCTAssertFalse(runtime.isCacheAvailable)
    XCTAssertEqual(try store.load().mode, .external)
    try FileManager.default.moveItem(at: detached, to: parent)
    runtime.refreshAvailability()
    XCTAssertTrue(runtime.isCacheAvailable)
    XCTAssertEqual(try runtime.registry.currentLease().rootURL, lease.rootURL)
  }
}

// MARK: - RelocationPreferenceStore

private final class RelocationPreferenceStore: CacheLocationPreferenceStoring, @unchecked Sendable {
  private let lock = NSLock()
  private var value = CacheLocationPreference(mode: .default)
  let failExternalSave: Bool
  init(failExternalSave: Bool = false) { self.failExternalSave = failExternalSave }
  func load() throws -> CacheLocationPreference { lock.withLock { value } }
  func save(_ preference: CacheLocationPreference) throws {
    if failExternalSave, preference.mode == .external { throw CocoaError(.fileWriteUnknown) }
    lock.withLock { value = preference }
  }
}

// MARK: - RelocationBookmarkClient

private struct RelocationBookmarkClient: SecurityScopedBookmarkClient {
  func createBookmark(for url: URL) throws -> Data { Data(url.path.utf8) }
  func resolveBookmark(_ data: Data) throws -> ResolvedCacheBookmark {
    ResolvedCacheBookmark(
      url: URL(fileURLWithPath: String(decoding: data, as: UTF8.self)),
      isStale: false
    )
  }

  func startAccessing(_ url: URL) -> Bool { true }
  func stopAccessing(_ url: URL) {}
}

// MARK: - RelocationCancellation

private final class RelocationCancellation: @unchecked Sendable {
  let lock = NSLock()
  private var canceled = false
  func cancel() { lock.withLock { canceled = true } }
  func check() throws { if lock.withLock({ canceled }) { throw CancellationError() } }
}
