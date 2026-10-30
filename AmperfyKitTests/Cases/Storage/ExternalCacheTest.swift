//
//  ExternalCacheTest.swift
//  AmperfyKitTests
//
//  Copyright (c) 2026 Amperfy contributors. All rights reserved.
//
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//

@testable import AmperfyKit
import Foundation
import XCTest

// MARK: - ExternalCacheTest

final class ExternalCacheTest: XCTestCase {
  private var temporaryDirectory: URL!

  override func setUpWithError() throws {
    temporaryDirectory = FileManager.default.temporaryDirectory
      .appendingPathComponent("ExternalCacheTest-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(
      at: temporaryDirectory,
      withIntermediateDirectories: true
    )
  }

  override func tearDownWithError() throws {
    if let temporaryDirectory {
      try? FileManager.default.removeItem(at: temporaryDirectory)
    }
  }

  func testRootTransitionInvalidatesPriorLease() throws {
    let registry = CacheRootRegistry()
    let firstRoot = temporaryDirectory.appendingPathComponent("first", isDirectory: true)
    let secondRoot = temporaryDirectory.appendingPathComponent("second", isDirectory: true)
    let firstLease = registry.activate(rootURL: firstRoot)
    XCTAssertNoThrow(try firstLease.validateCurrent())

    let secondLease = registry.activate(rootURL: secondRoot)
    XCTAssertThrowsError(try firstLease.validateCurrent()) { error in
      XCTAssertEqual(error as? CacheRootError, .staleGeneration)
    }
    XCTAssertNoThrow(try secondLease.validateCurrent())
  }

  func testBlockedRegistryRejectsExistingLease() throws {
    let registry = CacheRootRegistry()
    let lease = registry.activate(rootURL: temporaryDirectory)
    registry.block()
    XCTAssertThrowsError(try lease.validateCurrent()) { error in
      XCTAssertEqual(error as? CacheRootError, .unavailable)
    }
    XCTAssertThrowsError(try registry.currentLease())
  }

  func testRelativeResolutionPreservesAccountLayoutAndRejectsEscape() throws {
    let registry = CacheRootRegistry()
    let lease = registry.activate(rootURL: temporaryDirectory)
    let relative = URL(string: "accounts/server-hash/user-hash/songs/song.flac")!
    let resolved = try lease.resolve(relativePath: relative)
    XCTAssertEqual(
      resolved.path,
      temporaryDirectory.appendingPathComponent(relative.path).path
    )

    XCTAssertThrowsError(try lease.resolve(relativePath: URL(string: "../../escape")!)) {
      error in
      XCTAssertEqual(error as? CacheRootError, .pathEscapesRoot)
    }
  }

  func testCommitBoundaryRejectsStaleGenerationBeforeWrite() throws {
    let registry = CacheRootRegistry()
    let firstRoot = temporaryDirectory.appendingPathComponent("first", isDirectory: true)
    let lease = registry.activate(rootURL: firstRoot)
    registry.activate(rootURL: temporaryDirectory.appendingPathComponent("second"))
    let destination = firstRoot.appendingPathComponent("should-not-exist")

    XCTAssertThrowsError(try lease.performAtCommitBoundary {
      try Data("unsafe".utf8).write(to: destination)
    })
    XCTAssertFalse(FileManager.default.fileExists(atPath: destination.path))
  }

  func testCapacityPolicyUsesFiveGiBOrTenPercent() throws {
    let policy = CacheCapacityPolicy()
    let oneGiB: Int64 = 1024 * 1024 * 1024
    XCTAssertEqual(policy.reserveBytes(for: oneGiB), 5 * oneGiB)
    XCTAssertEqual(policy.reserveBytes(for: 100 * oneGiB), 10 * oneGiB)
    XCTAssertEqual(policy.requiredCapacity(for: oneGiB), 6 * oneGiB)

    XCTAssertThrowsError(try policy.validate(available: 6 * oneGiB - 1, inventoryBytes: oneGiB)) {
      error in
      XCTAssertEqual(
        error as? CacheRootError,
        .insufficientCapacity(required: 6 * oneGiB, available: 6 * oneGiB - 1)
      )
    }
  }

  func testBackgroundStagingPolicyEnforcesByteAndAgeLimits() {
    let policy = BackgroundStagingPolicy(
      absoluteByteLimit: 200,
      containerCapacityFractionDivisor: 10,
      maximumAge: 60
    )
    XCTAssertEqual(policy.byteLimit(containerAvailableCapacity: 1_000), 100)
    XCTAssertTrue(policy.permits(
      stagedBytes: 100,
      oldestItemAge: 60,
      containerAvailableCapacity: 1_000
    ))
    XCTAssertFalse(policy.permits(
      stagedBytes: 101,
      oldestItemAge: 10,
      containerAvailableCapacity: 1_000
    ))
    XCTAssertFalse(policy.permits(
      stagedBytes: 10,
      oldestItemAge: 61,
      containerAvailableCapacity: 1_000
    ))
  }

  func testExternalSelectionCreatesNeutralMarkerAndBalancesScope() throws {
    let selectedParent = temporaryDirectory.appendingPathComponent("Selected", isDirectory: true)
    try FileManager.default.createDirectory(at: selectedParent, withIntermediateDirectories: true)
    let registry = CacheRootRegistry()
    let bookmarks = FakeBookmarkClient(resolvedURL: selectedParent)
    let coordinator = CacheRootCoordinator(
      registry: registry,
      bookmarkClient: bookmarks,
      capacityProvider: FixedCapacityProvider(available: 20 * 1024 * 1024 * 1024)
    )

    let prepared = try coordinator.prepareExternal(selectedParentURL: selectedParent)
    let cacheID = UUID()
    let preference = CacheLocationPreference(
      mode: .external,
      bookmarkData: prepared.bookmarkData,
      displayName: selectedParent.lastPathComponent,
      cacheID: cacheID
    )
    let transaction = ExternalCacheActivationTransaction(
      cacheID: cacheID,
      oldPreference: CacheLocationPreference(mode: .default),
      oldRootURL: temporaryDirectory.appendingPathComponent("old"),
      newPreference: preference,
      newRootURL: selectedParent.appendingPathComponent(CacheMarker.childDirectoryName),
      phase: .prepared
    )
    XCTAssertEqual(
      try coordinator.materializeExternal(prepared: prepared, transaction: transaction),
      preference
    )
    _ = try coordinator.activatePreparedExternal(prepared: prepared, preference: preference)
    XCTAssertEqual(preference.mode, .external)
    XCTAssertEqual(
      try registry.currentLease().rootURL.lastPathComponent,
      CacheMarker.childDirectoryName
    )
    XCTAssertTrue(FileManager.default.fileExists(
      atPath: selectedParent.appendingPathComponent(CacheMarker.childDirectoryName)
        .appendingPathComponent(CacheMarker.fileName).path
    ))
    XCTAssertEqual(bookmarks.startCount, 1)
    XCTAssertEqual(bookmarks.stopCount, 0)

    coordinator.block(reason: "test complete")
    XCTAssertEqual(bookmarks.stopCount, 1)
  }

  func testStaleBookmarkIsRefreshedBeforeExternalRootBecomesReady() throws {
    let selectedParent = temporaryDirectory.appendingPathComponent("Renamed", isDirectory: true)
    let root = selectedParent.appendingPathComponent(
      CacheMarker.childDirectoryName,
      isDirectory: true
    )
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    let cacheID = UUID()
    try DurableAtomicFileStore().write(
      CacheMarker(cacheID: cacheID),
      to: root.appendingPathComponent(CacheMarker.fileName)
    )
    let registry = CacheRootRegistry()
    let bookmarks = FakeBookmarkClient(resolvedURL: selectedParent, isStale: true)
    let coordinator = CacheRootCoordinator(
      registry: registry,
      bookmarkClient: bookmarks,
      capacityProvider: FixedCapacityProvider(available: 20 * 1024 * 1024 * 1024)
    )
    let original = CacheLocationPreference(
      mode: .external,
      bookmarkData: Data("old".utf8),
      displayName: "Selected",
      cacheID: cacheID
    )

    let refreshed = try coordinator.resolveExternal(preference: original)
    XCTAssertEqual(refreshed.bookmarkData, FakeBookmarkClient.refreshedBookmark)
    XCTAssertEqual(refreshed.displayName, "Renamed")
    XCTAssertNoThrow(try registry.currentLease().validateCurrent())
    coordinator.block(reason: "test complete")
    XCTAssertEqual(bookmarks.stopCount, 1)
  }

  func testNonStaleBookmarkRefreshesDisplayNameFromResolvedParent() throws {
    let selectedParent = temporaryDirectory.appendingPathComponent("Resolved", isDirectory: true)
    let root = selectedParent.appendingPathComponent(
      CacheMarker.childDirectoryName,
      isDirectory: true
    )
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    let cacheID = UUID()
    try DurableAtomicFileStore().write(
      CacheMarker(cacheID: cacheID),
      to: root.appendingPathComponent(CacheMarker.fileName)
    )
    let registry = CacheRootRegistry()
    let bookmarks = FakeBookmarkClient(resolvedURL: selectedParent, isStale: false)
    let coordinator = CacheRootCoordinator(
      registry: registry,
      bookmarkClient: bookmarks,
      capacityProvider: FixedCapacityProvider(available: 20 * 1024 * 1024 * 1024)
    )
    let originalBookmark = Data("original".utf8)
    let original = CacheLocationPreference(
      mode: .external,
      bookmarkData: originalBookmark,
      displayName: "Old Name",
      cacheID: cacheID
    )

    let refreshed = try coordinator.resolveExternal(preference: original)
    XCTAssertEqual(refreshed.bookmarkData, originalBookmark)
    XCTAssertEqual(refreshed.displayName, "Resolved")
    XCTAssertEqual(bookmarks.createCount, 0)
    coordinator.block(reason: "test complete")
    XCTAssertEqual(bookmarks.stopCount, 1)
  }

  func testMarkerMismatchBlocksRegistryWithoutFallback() throws {
    let selectedParent = temporaryDirectory.appendingPathComponent("Selected", isDirectory: true)
    let root = selectedParent.appendingPathComponent(
      CacheMarker.childDirectoryName,
      isDirectory: true
    )
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    try DurableAtomicFileStore().write(
      CacheMarker(cacheID: UUID()),
      to: root.appendingPathComponent(CacheMarker.fileName)
    )
    let registry = CacheRootRegistry()
    let bookmarks = FakeBookmarkClient(resolvedURL: selectedParent)
    let coordinator = CacheRootCoordinator(
      registry: registry,
      bookmarkClient: bookmarks,
      capacityProvider: FixedCapacityProvider(available: 20 * 1024 * 1024 * 1024)
    )
    let preference = CacheLocationPreference(
      mode: .external,
      bookmarkData: Data("bookmark".utf8),
      cacheID: UUID()
    )

    do {
      _ = try coordinator.resolveExternal(preference: preference)
      XCTFail("Marker mismatch must fail closed")
    } catch {
      XCTAssertEqual(error as? CacheRootError, .markerMismatch)
    }
    XCTAssertThrowsError(try registry.currentLease())
    XCTAssertEqual(bookmarks.stopCount, 1)
  }

  func testDurableAtomicStoreOverwritesCompleteRecord() throws {
    struct Record: Codable, Equatable {
      let value: String
    }
    let store = DurableAtomicFileStore()
    let url = temporaryDirectory.appendingPathComponent("receipt.json")
    try store.write(Record(value: "before"), to: url)
    try store.write(Record(value: "after"), to: url)
    XCTAssertEqual(try store.read(Record.self, from: url), Record(value: "after"))
    XCTAssertEqual(
      try FileManager.default.contentsOfDirectory(atPath: temporaryDirectory.path),
      ["receipt.json"]
    )
  }

  func testActivationReconciliationCoversEveryCrashBoundary() {
    let transactionID = UUID()
    let destinationCacheID = UUID()
    let journal = CacheMigrationJournal(
      transactionID: transactionID,
      sourceCacheID: UUID(),
      destinationCacheID: destinationCacheID,
      phase: .activated,
      inventory: [CacheInventoryEntry(relativePath: "song", byteCount: 4, sha256: "hash")]
    )
    let marker = CacheMarker(cacheID: destinationCacheID)
    let receipt = CacheActivationReceipt(
      transactionID: transactionID,
      cacheID: destinationCacheID,
      inventoryDigest: journal.inventoryDigest
    )
    let reconciler = CacheActivationReconciler()

    XCTAssertEqual(reconciler.reconcile(
      journal: journal,
      evidence: CacheActivationEvidence(
        finalDirectoryExists: false,
        destinationMarker: nil,
        appReceipt: nil,
        destinationReceipt: nil,
        preferenceCacheID: nil
      )
    ), .sourceActiveResumeOrAbandon)

    XCTAssertEqual(reconciler.reconcile(
      journal: journal,
      evidence: CacheActivationEvidence(
        finalDirectoryExists: true,
        destinationMarker: marker,
        appReceipt: nil,
        destinationReceipt: receipt,
        preferenceCacheID: nil
      )
    ), .blockCompleteReceiptsOrRollback)

    XCTAssertEqual(reconciler.reconcile(
      journal: journal,
      evidence: CacheActivationEvidence(
        finalDirectoryExists: true,
        destinationMarker: marker,
        appReceipt: nil,
        destinationReceipt: receipt,
        preferenceCacheID: destinationCacheID
      )
    ), .blockCompleteReceiptsOrRollback)

    XCTAssertEqual(reconciler.reconcile(
      journal: journal,
      evidence: CacheActivationEvidence(
        finalDirectoryExists: true,
        destinationMarker: marker,
        appReceipt: receipt,
        destinationReceipt: receipt,
        preferenceCacheID: destinationCacheID
      )
    ), .destinationActive)

    XCTAssertEqual(reconciler.reconcile(
      journal: journal,
      evidence: CacheActivationEvidence(
        finalDirectoryExists: true,
        destinationMarker: CacheMarker(cacheID: UUID()),
        appReceipt: receipt,
        destinationReceipt: receipt,
        preferenceCacheID: destinationCacheID
      )
    ), .blockedInconsistent)
  }

  func testMigrationCopiesVerifiesActivatesAndPreservesSource() throws {
    let sourceRoot = temporaryDirectory.appendingPathComponent("source", isDirectory: true)
    let destinationParent = temporaryDirectory.appendingPathComponent(
      "destination",
      isDirectory: true
    )
    let appContainer = temporaryDirectory.appendingPathComponent("app", isDirectory: true)
    try FileManager.default.createDirectory(
      at: sourceRoot.appendingPathComponent("accounts/server/user/songs"),
      withIntermediateDirectories: true
    )
    try FileManager.default.createDirectory(
      at: destinationParent,
      withIntermediateDirectories: true
    )
    let sourceFile = sourceRoot.appendingPathComponent("accounts/server/user/songs/song.flac")
    try Data("synthetic media".utf8).write(to: sourceFile)

    let capacity = FixedCapacityProvider(available: 20 * 1024 * 1024 * 1024)
    let engine = CacheMigrationEngine(capacityProvider: capacity)
    let journal = try engine.makeJournal(sourceRoot: sourceRoot, sourceCacheID: UUID())
    let projection = LockedPreferenceProjection()
    let appJournalURL = appContainer.appendingPathComponent("migration.json")
    let activationPreference = CacheLocationPreference(
      mode: .external,
      bookmarkData: Data("bookmark".utf8),
      displayName: "destination",
      cacheID: journal.destinationCacheID
    )
    let finalRoot = try engine.migrate(
      journal: journal,
      sourceRoot: sourceRoot,
      destinationParent: destinationParent,
      appContainerJournalURL: appJournalURL,
      activationPreference: activationPreference
    ) { preference in
      projection.set(preference)
    }

    XCTAssertTrue(FileManager.default.fileExists(atPath: sourceFile.path))
    XCTAssertEqual(
      try Data(
        contentsOf: finalRoot
          .appendingPathComponent("accounts/server/user/songs/song.flac")
      ),
      Data("synthetic media".utf8)
    )
    XCTAssertTrue(FileManager.default.fileExists(
      atPath: finalRoot.appendingPathComponent(CacheMarker.fileName).path
    ))
    XCTAssertTrue(FileManager.default.fileExists(
      atPath: finalRoot.appendingPathComponent(CacheMigrationEngine.receiptFileName).path
    ))
    XCTAssertEqual(projection.value()?.cacheID, journal.destinationCacheID)
  }

  func testMigrationLowSpaceFailureDoesNotActivate() throws {
    let sourceRoot = temporaryDirectory.appendingPathComponent("source", isDirectory: true)
    let destinationParent = temporaryDirectory.appendingPathComponent(
      "destination",
      isDirectory: true
    )
    try FileManager.default.createDirectory(at: sourceRoot, withIntermediateDirectories: true)
    try FileManager.default.createDirectory(
      at: destinationParent,
      withIntermediateDirectories: true
    )
    try Data("synthetic media".utf8).write(to: sourceRoot.appendingPathComponent("song"))

    let engine = CacheMigrationEngine(capacityProvider: FixedCapacityProvider(available: 1))
    let journal = try engine.makeJournal(sourceRoot: sourceRoot, sourceCacheID: UUID())
    let activationPreference = CacheLocationPreference(
      mode: .external,
      bookmarkData: Data("bookmark".utf8),
      cacheID: journal.destinationCacheID
    )
    XCTAssertThrowsError(try engine.migrate(
      journal: journal,
      sourceRoot: sourceRoot,
      destinationParent: destinationParent,
      appContainerJournalURL: temporaryDirectory.appendingPathComponent("app/journal"),
      activationPreference: activationPreference
    ) { _ in
      XCTFail("Preference projection must not run on low-space failure")
    })
    XCTAssertFalse(FileManager.default.fileExists(
      atPath: destinationParent.appendingPathComponent(CacheMarker.childDirectoryName).path
    ))
  }

  func testBootstrapIsSingleAuthorityAndCreatesNothingBeforeDecision() throws {
    let defaultRoot = temporaryDirectory.appendingPathComponent("not-created", isDirectory: true)
    let registry = CacheRootRegistry()
    let store = FakePreferenceStore(preference: CacheLocationPreference(mode: .default))
    let runtime = CacheRootRuntime(
      registry: registry,
      preferenceStore: store,
      defaultRootProvider: { defaultRoot },
      bookmarkClient: FakeBookmarkClient(resolvedURL: defaultRoot),
      capacityProvider: FixedCapacityProvider(available: 20 * 1024 * 1024 * 1024),
      backgroundStagingRoot: temporaryDirectory.appendingPathComponent("staging")
    )

    XCTAssertFalse(FileManager.default.fileExists(atPath: defaultRoot.path))
    XCTAssertThrowsError(try registry.currentLease())
    XCTAssertThrowsError(try runtime.fileManager.currentRootLease())

    let state = try runtime.bootstrap()
    guard case let .ready(preference, rootURL) = state else {
      return XCTFail("Expected ready bootstrap")
    }
    XCTAssertEqual(preference.mode, .default)
    XCTAssertEqual(rootURL, defaultRoot.standardizedFileURL)
    XCTAssertTrue(FileManager.default.fileExists(atPath: defaultRoot.path))
    XCTAssertEqual(
      try runtime.fileManager.currentRootLease().generation,
      try registry.currentLease().generation
    )
  }

  func testIncompleteExternalPreferenceBlocksWithoutDefaultFallback() throws {
    let defaultRoot = temporaryDirectory.appendingPathComponent("must-not-exist")
    let runtime = CacheRootRuntime(
      preferenceStore: FakePreferenceStore(preference: CacheLocationPreference(mode: .external)),
      defaultRootProvider: { defaultRoot },
      bookmarkClient: FakeBookmarkClient(resolvedURL: temporaryDirectory),
      capacityProvider: FixedCapacityProvider(available: 20 * 1024 * 1024 * 1024)
    )

    XCTAssertThrowsError(try runtime.bootstrap())
    XCTAssertFalse(FileManager.default.fileExists(atPath: defaultRoot.path))
    XCTAssertThrowsError(try runtime.fileManager.currentRootLease())
    guard case .blocked = runtime.state else { return XCTFail("Expected blocked state") }
  }

  func testCacheLocationPresentationIsDeterministicAndFailClosed() {
    let root = URL(fileURLWithPath: "/deterministic/cache")
    XCTAssertEqual(
      CacheLocationPresentation(state: .ready(
        preference: CacheLocationPreference(mode: .external),
        rootURL: root
      )),
      CacheLocationPresentation(state: .ready(
        preference: CacheLocationPreference(mode: .external),
        rootURL: root
      ))
    )
    let blocked = CacheLocationPresentation(state: .blocked(reason: "Drive unavailable"))
    XCTAssertTrue(blocked.blocksNormalOperation)
    XCTAssertEqual(blocked.statusText, "Unavailable — Drive unavailable")
    XCTAssertTrue(CacheLocationPresentation(state: .unresolved).blocksNormalOperation)
    XCTAssertTrue(CacheLocationPresentation(state: .resolving).blocksNormalOperation)
  }

  func testPendingCacheLocationSelectionIsInMemoryAndNonActivating() throws {
    let registry = CacheRootRegistry()
    let activeRoot = temporaryDirectory.appendingPathComponent("active", isDirectory: true)
    let originalLease = registry.activate(rootURL: activeRoot)
    let preferenceStore = FakePreferenceStore(
      preference: CacheLocationPreference(mode: .default)
    )
    let selectedParent = temporaryDirectory.appendingPathComponent("selected", isDirectory: true)
    try FileManager.default.createDirectory(at: selectedParent, withIntermediateDirectories: true)
    var selection = PendingCacheLocationSelection()

    selection.beginChoosing()
    selection.select(selectedParent)

    XCTAssertEqual(selection.parentURL, selectedParent)
    XCTAssertFalse(selection.isPickerPresented)
    XCTAssertEqual(try registry.currentLease().generation, originalLease.generation)
    XCTAssertEqual(try preferenceStore.load().mode, .default)
    XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: selectedParent.path), [])
  }

  func testPendingCacheLocationCancellationDoesNotMutateCandidateOrDurableState() throws {
    let selectedParent = temporaryDirectory.appendingPathComponent("selected", isDirectory: true)
    try FileManager.default.createDirectory(at: selectedParent, withIntermediateDirectories: true)
    let preferenceStore = FakePreferenceStore(
      preference: CacheLocationPreference(mode: .default)
    )
    var selection = PendingCacheLocationSelection()
    selection.select(selectedParent)

    selection.beginChoosing()
    selection.cancel()

    XCTAssertEqual(selection.parentURL, selectedParent)
    XCTAssertFalse(selection.isPickerPresented)
    XCTAssertEqual(try preferenceStore.load().mode, .default)
    XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: selectedParent.path), [])
  }

  func testPreparedSelectionCancelPreservesDefaultReadyAndBalancesScope() throws {
    let defaultRoot = temporaryDirectory.appendingPathComponent("default", isDirectory: true)
    let selectedParent = temporaryDirectory.appendingPathComponent("selected", isDirectory: true)
    try FileManager.default.createDirectory(at: selectedParent, withIntermediateDirectories: true)
    let registry = CacheRootRegistry()
    let preferences = FakePreferenceStore(preference: CacheLocationPreference(mode: .default))
    let activations = FakeActivationStore()
    let bookmarks = FakeBookmarkClient(resolvedURL: selectedParent)
    let runtime = CacheRootRuntime(
      registry: registry,
      preferenceStore: preferences,
      activationStore: activations,
      defaultRootProvider: { defaultRoot },
      bookmarkClient: bookmarks,
      capacityProvider: FixedCapacityProvider(available: 20 * 1024 * 1024 * 1024)
    )
    _ = try runtime.bootstrap()
    let originalLease = try registry.currentLease()

    let prepared = try runtime.prepareExternal(selectedParentURL: selectedParent)
    XCTAssertEqual(try registry.currentLease().generation, originalLease.generation)
    XCTAssertEqual(runtime.state, .ready(
      preference: CacheLocationPreference(mode: .default),
      rootURL: defaultRoot.standardizedFileURL.resolvingSymlinksInPath()
    ))
    XCTAssertEqual(try preferences.load().mode, .default)
    XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: selectedParent.path), [])

    prepared.cancel()
    prepared.cancel()
    XCTAssertEqual(bookmarks.startCount, 1)
    XCTAssertEqual(bookmarks.stopCount, 1)
  }

  func testPreparationFailurePreservesDefaultReadyWithoutScopeLeak() throws {
    let defaultRoot = temporaryDirectory.appendingPathComponent("default", isDirectory: true)
    let selectedParent = temporaryDirectory.appendingPathComponent("selected", isDirectory: true)
    try FileManager.default.createDirectory(at: selectedParent, withIntermediateDirectories: true)
    let registry = CacheRootRegistry()
    let preferences = FakePreferenceStore(preference: CacheLocationPreference(mode: .default))
    let bookmarks = FakeBookmarkClient(resolvedURL: selectedParent, startSucceeds: false)
    let runtime = CacheRootRuntime(
      registry: registry,
      preferenceStore: preferences,
      activationStore: FakeActivationStore(),
      defaultRootProvider: { defaultRoot },
      bookmarkClient: bookmarks,
      capacityProvider: FixedCapacityProvider(available: 20 * 1024 * 1024 * 1024)
    )
    _ = try runtime.bootstrap()
    let originalLease = try registry.currentLease()

    XCTAssertThrowsError(try runtime.prepareExternal(selectedParentURL: selectedParent))
    XCTAssertEqual(try registry.currentLease().generation, originalLease.generation)
    XCTAssertEqual(try preferences.load().mode, .default)
    XCTAssertEqual(bookmarks.startCount, 1)
    XCTAssertEqual(bookmarks.stopCount, 0)
  }

  func testPayloadPresentRefusesDirectActivationAndRequiresMigration() throws {
    let defaultRoot = temporaryDirectory.appendingPathComponent("default", isDirectory: true)
    let selectedParent = temporaryDirectory.appendingPathComponent("selected", isDirectory: true)
    try FileManager.default.createDirectory(at: selectedParent, withIntermediateDirectories: true)
    let preferences = FakePreferenceStore(preference: CacheLocationPreference(mode: .default))
    let bookmarks = FakeBookmarkClient(resolvedURL: selectedParent)
    let runtime = CacheRootRuntime(
      preferenceStore: preferences,
      activationStore: FakeActivationStore(),
      defaultRootProvider: { defaultRoot },
      bookmarkClient: bookmarks,
      capacityProvider: FixedCapacityProvider(available: 20 * 1024 * 1024 * 1024)
    )
    _ = try runtime.bootstrap()
    let payload = defaultRoot.appendingPathComponent("accounts/server/user/songs/song.flac")
    try FileManager.default.createDirectory(
      at: payload.deletingLastPathComponent(),
      withIntermediateDirectories: true
    )
    try Data("cached".utf8).write(to: payload)
    let prepared = try runtime.prepareExternal(selectedParentURL: selectedParent)

    XCTAssertThrowsError(try runtime.confirmPreparedExternal(prepared)) {
      XCTAssertEqual($0 as? CacheRootError, .migrationRequired)
    }
    guard case let .ready(preference, rootURL) = runtime.state else {
      return XCTFail("Default must remain ready")
    }
    XCTAssertEqual(preference.mode, .default)
    XCTAssertEqual(rootURL, defaultRoot.standardizedFileURL.resolvingSymlinksInPath())
    XCTAssertFalse(FileManager.default.fileExists(
      atPath: selectedParent.appendingPathComponent(CacheMarker.childDirectoryName).path
    ))
    XCTAssertEqual(bookmarks.startCount, 1)
    XCTAssertEqual(bookmarks.stopCount, 0)
    prepared.cancel()
    XCTAssertEqual(bookmarks.stopCount, 1)
  }

  func testCompletedExternalControlFilesPermitDirectActivation() throws {
    let root = temporaryDirectory.appendingPathComponent("current", isDirectory: true)
    try FileManager.default.createDirectory(
      at: root.appendingPathComponent("accounts", isDirectory: true),
      withIntermediateDirectories: true
    )
    let cacheID = UUID()
    let atomicStore = DurableAtomicFileStore()
    try atomicStore.write(
      CacheMarker(cacheID: cacheID),
      to: root.appendingPathComponent(CacheMarker.fileName)
    )
    try atomicStore.write(
      ExternalCacheActivationTransaction(
        cacheID: cacheID,
        oldPreference: CacheLocationPreference(mode: .default),
        oldRootURL: temporaryDirectory.appendingPathComponent("old"),
        newPreference: CacheLocationPreference(mode: .external, cacheID: cacheID),
        newRootURL: root,
        phase: .completed
      ),
      to: root.appendingPathComponent(CacheMigrationEngine.receiptFileName)
    )

    let renamedRoot = temporaryDirectory.appendingPathComponent("renamed", isDirectory: true)
    try FileManager.default.moveItem(at: root, to: renamedRoot)
    XCTAssertNoThrow(try CacheDirectActivationInventoryGate().validate(rootURL: renamedRoot))
  }

  func testUnresolvedExternalControlReceiptRequiresMigration() throws {
    let root = temporaryDirectory.appendingPathComponent("current", isDirectory: true)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    let cacheID = UUID()
    let atomicStore = DurableAtomicFileStore()
    try atomicStore.write(
      CacheMarker(cacheID: cacheID),
      to: root.appendingPathComponent(CacheMarker.fileName)
    )
    try atomicStore.write(
      ExternalCacheActivationTransaction(
        cacheID: cacheID,
        oldPreference: CacheLocationPreference(mode: .default),
        oldRootURL: temporaryDirectory.appendingPathComponent("old"),
        newPreference: CacheLocationPreference(mode: .external, cacheID: cacheID),
        newRootURL: root,
        phase: .preferencePersisted
      ),
      to: root.appendingPathComponent(CacheMigrationEngine.receiptFileName)
    )

    XCTAssertThrowsError(try CacheDirectActivationInventoryGate().validate(rootURL: root)) {
      XCTAssertEqual($0 as? CacheRootError, .migrationRequired)
    }
  }

  func testConfirmedEmptyRootPersistsCompletePreferenceAndMirroredReceipts() throws {
    let defaultRoot = temporaryDirectory.appendingPathComponent("default", isDirectory: true)
    let selectedParent = temporaryDirectory.appendingPathComponent("selected", isDirectory: true)
    try FileManager.default.createDirectory(at: selectedParent, withIntermediateDirectories: true)
    let preferences = FakePreferenceStore(preference: CacheLocationPreference(mode: .default))
    let activations = FakeActivationStore()
    let bookmarks = FakeBookmarkClient(resolvedURL: selectedParent)
    let runtime = CacheRootRuntime(
      preferenceStore: preferences,
      activationStore: activations,
      defaultRootProvider: { defaultRoot },
      bookmarkClient: bookmarks,
      capacityProvider: FixedCapacityProvider(available: 20 * 1024 * 1024 * 1024)
    )
    _ = try runtime.bootstrap()
    try FileManager.default.createDirectory(
      at: defaultRoot.appendingPathComponent("accounts"),
      withIntermediateDirectories: true
    )
    let prepared = try runtime.prepareExternal(selectedParentURL: selectedParent)
    XCTAssertFalse(FileManager.default.fileExists(
      atPath: selectedParent.appendingPathComponent(CacheMarker.childDirectoryName).path
    ))

    let preference = try runtime.confirmPreparedExternal(prepared)
    let root = selectedParent.appendingPathComponent(CacheMarker.childDirectoryName)
    XCTAssertEqual(preference.mode, .external)
    XCTAssertNotNil(preference.bookmarkData)
    XCTAssertNotNil(preference.cacheID)
    XCTAssertEqual(try preferences.load(), preference)
    XCTAssertEqual(try activations.load()?.phase, .completed)
    XCTAssertEqual(
      try DurableAtomicFileStore().read(
        ExternalCacheActivationTransaction.self,
        from: root.appendingPathComponent(CacheMigrationEngine.receiptFileName)
      ),
      try activations.load()
    )
    XCTAssertEqual(
      try DurableAtomicFileStore().read(
        CacheMarker.self,
        from: root.appendingPathComponent(CacheMarker.fileName)
      ).cacheID,
      preference.cacheID
    )
    XCTAssertTrue(FileManager.default.fileExists(atPath: defaultRoot.path))
    XCTAssertEqual(bookmarks.startCount, 1)
    XCTAssertEqual(bookmarks.stopCount, 0)
    runtime.block(reason: "test complete")
    XCTAssertEqual(bookmarks.stopCount, 1)
  }

  func testConfirmedExternalRestartsWithSameCacheIDAndBalancedScope() throws {
    let defaultRoot = temporaryDirectory.appendingPathComponent("default", isDirectory: true)
    let selectedParent = temporaryDirectory.appendingPathComponent("selected", isDirectory: true)
    try FileManager.default.createDirectory(at: selectedParent, withIntermediateDirectories: true)
    let preferences = FakePreferenceStore(preference: CacheLocationPreference(mode: .default))
    let activations = FakeActivationStore()
    let bookmarks = FakeBookmarkClient(resolvedURL: selectedParent)
    let first = CacheRootRuntime(
      preferenceStore: preferences,
      activationStore: activations,
      defaultRootProvider: { defaultRoot },
      bookmarkClient: bookmarks,
      capacityProvider: FixedCapacityProvider(available: 20 * 1024 * 1024 * 1024)
    )
    _ = try first.bootstrap()
    let confirmed = try first.confirmPreparedExternal(
      try first.prepareExternal(selectedParentURL: selectedParent)
    )
    first.block(reason: "simulate quit")
    XCTAssertEqual(bookmarks.startCount, 1)
    XCTAssertEqual(bookmarks.stopCount, 1)

    let second = CacheRootRuntime(
      preferenceStore: preferences,
      activationStore: activations,
      defaultRootProvider: { defaultRoot },
      bookmarkClient: bookmarks,
      capacityProvider: FixedCapacityProvider(available: 20 * 1024 * 1024 * 1024)
    )
    guard case let .ready(restarted, rootURL) = try second.bootstrap() else {
      return XCTFail("External cache must restart ready")
    }
    XCTAssertEqual(restarted.cacheID, confirmed.cacheID)
    XCTAssertEqual(
      rootURL,
      selectedParent.appendingPathComponent(CacheMarker.childDirectoryName)
        .standardizedFileURL.resolvingSymlinksInPath()
    )
    XCTAssertEqual(bookmarks.startCount, 2)
    XCTAssertEqual(bookmarks.stopCount, 1)
    second.block(reason: "test complete")
    XCTAssertEqual(bookmarks.stopCount, 2)
  }

  func testActivationFailuresAtEveryBoundaryRollbackToDefaultReady() throws {
    let boundaries: [ExternalCacheActivationPhase] = [
      .prepared,
      .destinationMaterialized,
      .preferencePersisted,
      .registryActivated,
    ]
    for boundary in boundaries {
      let caseRoot = temporaryDirectory.appendingPathComponent(boundary.rawValue)
      let defaultRoot = caseRoot.appendingPathComponent("default", isDirectory: true)
      let selectedParent = caseRoot.appendingPathComponent("selected", isDirectory: true)
      try FileManager.default.createDirectory(at: selectedParent, withIntermediateDirectories: true)
      let preferences = FakePreferenceStore(preference: CacheLocationPreference(mode: .default))
      let activations = FakeActivationStore()
      let bookmarks = FakeBookmarkClient(resolvedURL: selectedParent)
      let runtime = CacheRootRuntime(
        preferenceStore: preferences,
        activationStore: activations,
        defaultRootProvider: { defaultRoot },
        bookmarkClient: bookmarks,
        capacityProvider: FixedCapacityProvider(available: 20 * 1024 * 1024 * 1024),
        activationBoundary: { phase in
          if phase == boundary { throw InjectedActivationError.boundary }
        }
      )
      _ = try runtime.bootstrap()
      let prepared = try runtime.prepareExternal(selectedParentURL: selectedParent)

      XCTAssertThrowsError(try runtime.confirmPreparedExternal(prepared))
      guard case let .ready(preference, rootURL) = runtime.state else {
        return XCTFail("\(boundary) must rollback to Ready")
      }
      XCTAssertEqual(preference.mode, .default)
      XCTAssertEqual(rootURL, defaultRoot.standardizedFileURL.resolvingSymlinksInPath())
      XCTAssertEqual(try preferences.load().mode, .default)
      XCTAssertEqual(try activations.load()?.phase, .rolledBack)
      XCTAssertFalse(FileManager.default.fileExists(
        atPath: selectedParent.appendingPathComponent(CacheMarker.childDirectoryName).path
      ))
      XCTAssertEqual(bookmarks.startCount, 1)
      XCTAssertEqual(bookmarks.stopCount, 1)
    }
  }

  func testPreferencePersistenceFailureRollsBackWithoutMixedRoots() throws {
    let defaultRoot = temporaryDirectory.appendingPathComponent("default", isDirectory: true)
    let selectedParent = temporaryDirectory.appendingPathComponent("selected", isDirectory: true)
    try FileManager.default.createDirectory(at: selectedParent, withIntermediateDirectories: true)
    let preferences = FailExternalPreferenceStore()
    let bookmarks = FakeBookmarkClient(resolvedURL: selectedParent)
    let runtime = CacheRootRuntime(
      preferenceStore: preferences,
      activationStore: FakeActivationStore(),
      defaultRootProvider: { defaultRoot },
      bookmarkClient: bookmarks,
      capacityProvider: FixedCapacityProvider(available: 20 * 1024 * 1024 * 1024)
    )
    _ = try runtime.bootstrap()

    XCTAssertThrowsError(try runtime.confirmPreparedExternal(
      try runtime.prepareExternal(selectedParentURL: selectedParent)
    ))
    guard case let .ready(preference, rootURL) = runtime.state else {
      return XCTFail("Default must remain ready")
    }
    XCTAssertEqual(preference.mode, .default)
    XCTAssertEqual(rootURL, defaultRoot.standardizedFileURL.resolvingSymlinksInPath())
    XCTAssertEqual(try preferences.load().mode, .default)
    XCTAssertFalse(FileManager.default.fileExists(
      atPath: selectedParent.appendingPathComponent(CacheMarker.childDirectoryName).path
    ))
    XCTAssertEqual(bookmarks.startCount, 1)
    XCTAssertEqual(bookmarks.stopCount, 1)
  }

  func testBookmarkCreationFailurePreservesDefaultReadyAndBalancesScope() throws {
    let defaultRoot = temporaryDirectory.appendingPathComponent("default", isDirectory: true)
    let selectedParent = temporaryDirectory.appendingPathComponent("selected", isDirectory: true)
    try FileManager.default.createDirectory(at: selectedParent, withIntermediateDirectories: true)
    let preferences = FakePreferenceStore(preference: CacheLocationPreference(mode: .default))
    let bookmarks = FakeBookmarkClient(
      resolvedURL: selectedParent,
      bookmarkCreationError: InjectedActivationError.bookmark
    )
    let runtime = CacheRootRuntime(
      preferenceStore: preferences,
      activationStore: FakeActivationStore(),
      defaultRootProvider: { defaultRoot },
      bookmarkClient: bookmarks,
      capacityProvider: FixedCapacityProvider(available: 20 * 1024 * 1024 * 1024)
    )
    _ = try runtime.bootstrap()

    XCTAssertThrowsError(try runtime.prepareExternal(selectedParentURL: selectedParent))
    guard case let .ready(preference, rootURL) = runtime.state else {
      return XCTFail("Default must remain ready")
    }
    XCTAssertEqual(preference.mode, .default)
    XCTAssertEqual(rootURL, defaultRoot.standardizedFileURL.resolvingSymlinksInPath())
    XCTAssertEqual(try preferences.load().mode, .default)
    XCTAssertEqual(bookmarks.startCount, 1)
    XCTAssertEqual(bookmarks.stopCount, 1)
  }

  func testPreexistingDestinationRefusesMaterializationWithoutChangingDefault() throws {
    let defaultRoot = temporaryDirectory.appendingPathComponent("default", isDirectory: true)
    let selectedParent = temporaryDirectory.appendingPathComponent("selected", isDirectory: true)
    let preexistingRoot = selectedParent.appendingPathComponent(CacheMarker.childDirectoryName)
    try FileManager.default.createDirectory(at: preexistingRoot, withIntermediateDirectories: true)
    let sentinel = preexistingRoot.appendingPathComponent("unrelated.txt")
    try Data("preserve".utf8).write(to: sentinel)
    let preferences = FakePreferenceStore(preference: CacheLocationPreference(mode: .default))
    let bookmarks = FakeBookmarkClient(resolvedURL: selectedParent)
    let runtime = CacheRootRuntime(
      preferenceStore: preferences,
      activationStore: FakeActivationStore(),
      defaultRootProvider: { defaultRoot },
      bookmarkClient: bookmarks,
      capacityProvider: FixedCapacityProvider(available: 20 * 1024 * 1024 * 1024)
    )
    _ = try runtime.bootstrap()

    XCTAssertThrowsError(try runtime.confirmPreparedExternal(
      try runtime.prepareExternal(selectedParentURL: selectedParent)
    )) {
      XCTAssertEqual($0 as? CacheRootError, .markerMismatch)
    }
    guard case let .ready(preference, rootURL) = runtime.state else {
      return XCTFail("Default must remain ready")
    }
    XCTAssertEqual(preference.mode, .default)
    XCTAssertEqual(rootURL, defaultRoot.standardizedFileURL.resolvingSymlinksInPath())
    XCTAssertEqual(try Data(contentsOf: sentinel), Data("preserve".utf8))
    XCTAssertEqual(bookmarks.startCount, 1)
    XCTAssertEqual(bookmarks.stopCount, 1)
  }

  func testInterruptedMaterializationReconcilesToOldRootAndRemovesOwnedDestination() throws {
    let defaultRoot = temporaryDirectory.appendingPathComponent("default", isDirectory: true)
    let selectedParent = temporaryDirectory.appendingPathComponent("selected", isDirectory: true)
    let newRoot = selectedParent.appendingPathComponent(CacheMarker.childDirectoryName)
    try FileManager.default.createDirectory(at: newRoot, withIntermediateDirectories: true)
    let cacheID = UUID()
    let newPreference = CacheLocationPreference(
      mode: .external,
      bookmarkData: Data("bookmark".utf8),
      displayName: selectedParent.lastPathComponent,
      cacheID: cacheID
    )
    let transaction = ExternalCacheActivationTransaction(
      cacheID: cacheID,
      oldPreference: CacheLocationPreference(mode: .default),
      oldRootURL: defaultRoot,
      newPreference: newPreference,
      newRootURL: newRoot,
      phase: .destinationMaterialized
    )
    let atomic = DurableAtomicFileStore()
    try atomic.write(
      CacheMarker(cacheID: cacheID),
      to: newRoot.appendingPathComponent(CacheMarker.fileName)
    )
    try atomic.write(
      transaction,
      to: newRoot.appendingPathComponent(CacheMigrationEngine.receiptFileName)
    )
    let preferences = FakePreferenceStore(preference: newPreference)
    let activations = FakeActivationStore(transaction: transaction)
    let runtime = CacheRootRuntime(
      preferenceStore: preferences,
      activationStore: activations,
      defaultRootProvider: { defaultRoot },
      bookmarkClient: FakeBookmarkClient(resolvedURL: selectedParent),
      capacityProvider: FixedCapacityProvider(available: 20 * 1024 * 1024 * 1024)
    )

    guard case let .ready(preference, rootURL) = try runtime.bootstrap() else {
      return XCTFail("Interrupted materialization must reconcile to Default")
    }
    XCTAssertEqual(preference.mode, .default)
    XCTAssertEqual(rootURL, defaultRoot.standardizedFileURL.resolvingSymlinksInPath())
    XCTAssertEqual(try preferences.load().mode, .default)
    XCTAssertEqual(try activations.load()?.phase, .rolledBack)
    XCTAssertFalse(FileManager.default.fileExists(atPath: newRoot.path))
  }

  func testInterruptedRegistryActivationCompletesOnlyFromMatchingReceipts() throws {
    let defaultRoot = temporaryDirectory.appendingPathComponent("default", isDirectory: true)
    let selectedParent = temporaryDirectory.appendingPathComponent("selected", isDirectory: true)
    let newRoot = selectedParent.appendingPathComponent(CacheMarker.childDirectoryName)
    try FileManager.default.createDirectory(at: newRoot, withIntermediateDirectories: true)
    let cacheID = UUID()
    let newPreference = CacheLocationPreference(
      mode: .external,
      bookmarkData: Data("bookmark".utf8),
      displayName: selectedParent.lastPathComponent,
      cacheID: cacheID
    )
    let transaction = ExternalCacheActivationTransaction(
      cacheID: cacheID,
      oldPreference: CacheLocationPreference(mode: .default),
      oldRootURL: defaultRoot,
      newPreference: newPreference,
      newRootURL: newRoot,
      phase: .registryActivated
    )
    let atomic = DurableAtomicFileStore()
    try atomic.write(
      CacheMarker(cacheID: cacheID),
      to: newRoot.appendingPathComponent(CacheMarker.fileName)
    )
    try atomic.write(
      transaction,
      to: newRoot.appendingPathComponent(CacheMigrationEngine.receiptFileName)
    )
    let preferences = FakePreferenceStore(preference: newPreference)
    let activations = FakeActivationStore(transaction: transaction)
    let bookmarks = FakeBookmarkClient(resolvedURL: selectedParent)
    let runtime = CacheRootRuntime(
      preferenceStore: preferences,
      activationStore: activations,
      defaultRootProvider: { defaultRoot },
      bookmarkClient: bookmarks,
      capacityProvider: FixedCapacityProvider(available: 20 * 1024 * 1024 * 1024)
    )

    guard case let .ready(preference, rootURL) = try runtime.bootstrap() else {
      return XCTFail("Matching receipts must complete the external activation")
    }
    XCTAssertEqual(preference, newPreference)
    XCTAssertEqual(rootURL, newRoot.standardizedFileURL.resolvingSymlinksInPath())
    XCTAssertEqual(try activations.load()?.phase, .completed)
    XCTAssertEqual(bookmarks.startCount, 1)
    runtime.block(reason: "test complete")
    XCTAssertEqual(bookmarks.stopCount, 1)
  }

  func testInterruptedActivationReceiptMismatchBlocksWithoutHeuristicCleanup() throws {
    let defaultRoot = temporaryDirectory.appendingPathComponent("default", isDirectory: true)
    let selectedParent = temporaryDirectory.appendingPathComponent("selected", isDirectory: true)
    let newRoot = selectedParent.appendingPathComponent(CacheMarker.childDirectoryName)
    try FileManager.default.createDirectory(at: newRoot, withIntermediateDirectories: true)
    let cacheID = UUID()
    let newPreference = CacheLocationPreference(
      mode: .external,
      bookmarkData: Data("bookmark".utf8),
      displayName: selectedParent.lastPathComponent,
      cacheID: cacheID
    )
    let transaction = ExternalCacheActivationTransaction(
      cacheID: cacheID,
      oldPreference: CacheLocationPreference(mode: .default),
      oldRootURL: defaultRoot,
      newPreference: newPreference,
      newRootURL: newRoot,
      phase: .destinationMaterialized
    )
    var mismatched = transaction
    mismatched.failureDescription = "different receipt"
    let atomic = DurableAtomicFileStore()
    try atomic.write(
      CacheMarker(cacheID: cacheID),
      to: newRoot.appendingPathComponent(CacheMarker.fileName)
    )
    try atomic.write(
      mismatched,
      to: newRoot.appendingPathComponent(CacheMigrationEngine.receiptFileName)
    )
    let preferences = FakePreferenceStore(preference: newPreference)
    let runtime = CacheRootRuntime(
      preferenceStore: preferences,
      activationStore: FakeActivationStore(transaction: transaction),
      defaultRootProvider: { defaultRoot },
      bookmarkClient: FakeBookmarkClient(resolvedURL: selectedParent),
      capacityProvider: FixedCapacityProvider(available: 20 * 1024 * 1024 * 1024)
    )

    XCTAssertThrowsError(try runtime.bootstrap()) {
      XCTAssertEqual($0 as? CacheRootError, .inconsistentActivation)
    }
    guard case .blocked = runtime.state else { return XCTFail("Ambiguity must block") }
    XCTAssertTrue(FileManager.default.fileExists(atPath: newRoot.path))
    XCTAssertEqual(try preferences.load(), newPreference)
  }

  func testDurablePreferenceIsAuthoritativeOverProjection() throws {
    let configurationURL = temporaryDirectory.appendingPathComponent("configuration.json")
    let projectedExternal = CacheLocationPreference(
      mode: .external,
      bookmarkData: Data("projection-only".utf8),
      displayName: "Ignored",
      cacheID: UUID()
    )
    let projection = FakePreferenceStore(preference: projectedExternal)
    let store = DurableCacheLocationPreferenceStore(
      configurationURL: configurationURL,
      projection: projection
    )

    XCTAssertEqual(try store.load(), CacheLocationPreference(mode: .default))
    let authoritative = CacheLocationPreference(
      mode: .external,
      bookmarkData: Data("complete".utf8),
      displayName: "Selected",
      cacheID: UUID()
    )
    try store.save(authoritative)
    XCTAssertEqual(try store.load(), authoritative)
    XCTAssertEqual(try projection.load(), authoritative)
    XCTAssertTrue(FileManager.default.fileExists(atPath: configurationURL.path))
  }

  func testRelativePathsPreserveFilesystemCharactersAndRejectSymlinkEscape() throws {
    let registry = CacheRootRegistry()
    let lease = registry.activate(rootURL: temporaryDirectory)
    let composed = "café.flac"
    let decomposed = "cafe\u{301}.flac"
    let names = [
      "space name.flac",
      "hash#.flac",
      "percent%.flac",
      "query?.flac",
      "colon:.flac",
      composed,
      decomposed,
    ]

    for name in names {
      let relative = try CacheRelativePath("accounts/server/user/songs/\(name)")
      let resolved = try lease.resolve(relativePath: relative)
      XCTAssertEqual(resolved.lastPathComponent, name)
    }
    for traversal in ["../escape", "a/../../escape", "/absolute", "a//b", "a/./b"] {
      XCTAssertThrowsError(try CacheRelativePath(traversal))
    }

    let outside = temporaryDirectory.deletingLastPathComponent()
      .appendingPathComponent("outside-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: outside, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: outside) }
    try FileManager.default.createSymbolicLink(
      at: temporaryDirectory.appendingPathComponent("link"),
      withDestinationURL: outside
    )
    XCTAssertThrowsError(try lease.resolve(relativePath: CacheRelativePath("link/escape"))) {
      XCTAssertEqual($0 as? CacheRootError, .pathEscapesRoot)
    }
  }

  func testInventoryIncludesHiddenFilesAndOnlyExcludesRootControlFiles() throws {
    let nested = temporaryDirectory.appendingPathComponent("nested", isDirectory: true)
    try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)
    try Data("hidden".utf8).write(to: temporaryDirectory.appendingPathComponent(".hidden-media"))
    for controlName in CacheInventoryBuilder.rootControlFileNames {
      try Data("control".utf8).write(to: temporaryDirectory.appendingPathComponent(controlName))
      try Data("user-data".utf8).write(to: nested.appendingPathComponent(controlName))
    }

    let paths = try CacheInventoryBuilder().build(rootURL: temporaryDirectory)
      .map(\.relativePath)
    XCTAssertTrue(paths.contains(".hidden-media"))
    for controlName in CacheInventoryBuilder.rootControlFileNames {
      XCTAssertFalse(paths.contains(controlName))
      XCTAssertTrue(paths.contains("nested/\(controlName)"))
    }
  }

  func testMigrationResumesVerifiedPartialFilesWithFilesystemSafeNames() throws {
    let sourceRoot = temporaryDirectory.appendingPathComponent("resume-source", isDirectory: true)
    let destinationParent = temporaryDirectory.appendingPathComponent("resume-destination")
    let specialDirectory = sourceRoot.appendingPathComponent("accounts/server/user/songs")
    try FileManager.default.createDirectory(at: specialDirectory, withIntermediateDirectories: true)
    try FileManager.default.createDirectory(
      at: destinationParent,
      withIntermediateDirectories: true
    )
    let names = ["space # % ? :.flac", "cafe\u{301}.flac"]
    for name in names {
      try Data("payload-\(name)".utf8).write(to: specialDirectory.appendingPathComponent(name))
    }

    let engine = CacheMigrationEngine(
      capacityProvider: FixedCapacityProvider(available: 20 * 1024 * 1024 * 1024)
    )
    let transactionID = UUID()
    var journal = try engine.makeJournal(
      sourceRoot: sourceRoot,
      sourceCacheID: UUID(),
      transactionID: transactionID
    )
    journal.phase = .copying
    let first = journal.inventory[0]
    let stagingRoot = destinationParent
      .appendingPathComponent(".amperfy-migration-\(transactionID.uuidString)")
      .appendingPathComponent(CacheMarker.childDirectoryName)
    let firstDestination = stagingRoot.appendingPathComponent(first.relativePath)
    try FileManager.default.createDirectory(
      at: firstDestination.deletingLastPathComponent(),
      withIntermediateDirectories: true
    )
    let verifiedPartial = firstDestination.deletingLastPathComponent().appendingPathComponent(
      ".\(firstDestination.lastPathComponent).\(transactionID.uuidString).partial"
    )
    try FileManager.default.copyItem(
      at: sourceRoot.appendingPathComponent(first.relativePath),
      to: verifiedPartial
    )
    let second = journal.inventory[1]
    let secondDestination = stagingRoot.appendingPathComponent(second.relativePath)
    let corruptPartial = secondDestination.deletingLastPathComponent().appendingPathComponent(
      ".\(secondDestination.lastPathComponent).\(transactionID.uuidString).partial"
    )
    try Data("truncated".utf8).write(to: corruptPartial)

    let preference = CacheLocationPreference(
      mode: .external,
      bookmarkData: Data("bookmark".utf8),
      cacheID: journal.destinationCacheID
    )
    let finalRoot = try engine.migrate(
      journal: journal,
      sourceRoot: sourceRoot,
      destinationParent: destinationParent,
      appContainerJournalURL: temporaryDirectory.appendingPathComponent("resume-app/journal"),
      activationPreference: preference,
      projectPreference: { _ in }
    )

    for name in names {
      XCTAssertEqual(
        try Data(
          contentsOf: finalRoot
            .appendingPathComponent("accounts/server/user/songs/\(name)")
        ),
        Data("payload-\(name)".utf8)
      )
    }
    XCTAssertFalse(FileManager.default.fileExists(atPath: verifiedPartial.path))
    XCTAssertFalse(FileManager.default.fileExists(atPath: corruptPartial.path))
  }

  func testMigrationRejectsIncompleteBookmarkProjectionBeforeCopy() throws {
    let source = temporaryDirectory.appendingPathComponent("incomplete-source")
    let destination = temporaryDirectory.appendingPathComponent("incomplete-destination")
    try FileManager.default.createDirectory(at: source, withIntermediateDirectories: true)
    try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
    try Data("media".utf8).write(to: source.appendingPathComponent("song"))
    let engine = CacheMigrationEngine(
      capacityProvider: FixedCapacityProvider(available: 20 * 1024 * 1024 * 1024)
    )
    let journal = try engine.makeJournal(sourceRoot: source, sourceCacheID: UUID())
    XCTAssertThrowsError(try engine.migrate(
      journal: journal,
      sourceRoot: source,
      destinationParent: destination,
      appContainerJournalURL: temporaryDirectory.appendingPathComponent("incomplete-app/journal"),
      activationPreference: CacheLocationPreference(
        mode: .external,
        cacheID: journal.destinationCacheID
      ),
      projectPreference: { _ in XCTFail("Projection must not run") }
    ))
    XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: destination.path), [])
  }

  func testFilesystemCommitRemainsRecoverableWhenGenerationChangesBeforeCoreDataSave() throws {
    let root = temporaryDirectory.appendingPathComponent("race-root", isDirectory: true)
    let staging = temporaryDirectory.appendingPathComponent("race-staging", isDirectory: true)
    let registry = CacheRootRegistry()
    let manager = CacheFileManager(rootRegistry: registry, backgroundStagingRoot: staging)
    let lease = registry.activate(rootURL: root)
    try manager.rootDidActivate(using: lease)
    let source = temporaryDirectory.appendingPathComponent("download.tmp")
    try Data("recoverable media".utf8).write(to: source)
    let relative = try CacheRelativePath("accounts/server/user/songs/song.flac")
    let destination = try manager.getAbsoluteAmperfyPath(relativePath: relative, using: lease)
    let account = AccountInfo(serverHash: "server", userHash: "user", apiType: .notDetected)

    let transaction = try manager.prepareRecoverableFileCommit(
      sourceURL: source,
      destinationURL: destination,
      accountInfo: account,
      using: lease
    )
    registry.block() // injected boundary: filesystem committed, Core Data not yet saved

    XCTAssertTrue(FileManager.default.fileExists(atPath: destination.path))
    XCTAssertTrue(FileManager.default.fileExists(atPath: transaction.recoverableFileURL.path))
    XCTAssertEqual(transaction.receipt.phase, .filesystemCommitted)
    XCTAssertThrowsError(try transaction.cancel())
    XCTAssertTrue(FileManager.default.fileExists(atPath: transaction.recoverableFileURL.path))
  }

  func testExistingMarkerRequiresKnownIDOrExplicitAdoption() throws {
    let parent = temporaryDirectory.appendingPathComponent("existing-parent")
    let root = parent.appendingPathComponent(CacheMarker.childDirectoryName)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    let cacheID = UUID()
    try DurableAtomicFileStore().write(
      CacheMarker(cacheID: cacheID),
      to: root.appendingPathComponent(CacheMarker.fileName)
    )
    let coordinator = CacheRootCoordinator(
      registry: CacheRootRegistry(),
      bookmarkClient: FakeBookmarkClient(resolvedURL: parent),
      capacityProvider: FixedCapacityProvider(available: 20 * 1024 * 1024 * 1024)
    )

    let mismatchedPrepared = try coordinator.prepareExternal(selectedParentURL: parent)
    XCTAssertThrowsError(try coordinator.activateExistingPreparedExternal(
      prepared: mismatchedPrepared,
      expectedCacheID: UUID()
    )) {
      XCTAssertEqual($0 as? CacheRootError, .markerMismatch)
    }
    mismatchedPrepared.cancel()
    let matchingPrepared = try coordinator.prepareExternal(selectedParentURL: parent)
    XCTAssertNoThrow(try coordinator.activateExistingPreparedExternal(
      prepared: matchingPrepared,
      expectedCacheID: cacheID
    ))
  }
}

// MARK: - FixedCapacityProvider

private struct FixedCapacityProvider: CacheCapacityProviding {
  let available: Int64

  func availableCapacity(at url: URL) throws -> Int64 {
    available
  }
}

// MARK: - FakePreferenceStore

private final class FakePreferenceStore: CacheLocationPreferenceStoring, @unchecked Sendable {
  private let lock = NSLock()
  private var preference: CacheLocationPreference

  init(preference: CacheLocationPreference) {
    self.preference = preference
  }

  func load() throws -> CacheLocationPreference {
    lock.withLock { preference }
  }

  func save(_ preference: CacheLocationPreference) throws {
    lock.withLock { self.preference = preference }
  }
}

// MARK: - FailExternalPreferenceStore

private final class FailExternalPreferenceStore: CacheLocationPreferenceStoring,
  @unchecked Sendable {
  private let lock = NSLock()
  private var preference = CacheLocationPreference(mode: .default)

  func load() throws -> CacheLocationPreference {
    lock.withLock { preference }
  }

  func save(_ preference: CacheLocationPreference) throws {
    if preference.mode == .external { throw InjectedActivationError.preference }
    lock.withLock { self.preference = preference }
  }
}

// MARK: - FakeActivationStore

private final class FakeActivationStore: ExternalCacheActivationStoring, @unchecked Sendable {
  private let lock = NSLock()
  private var transaction: ExternalCacheActivationTransaction?

  init(transaction: ExternalCacheActivationTransaction? = nil) {
    self.transaction = transaction
  }

  func load() throws -> ExternalCacheActivationTransaction? {
    lock.withLock { transaction }
  }

  func save(_ transaction: ExternalCacheActivationTransaction) throws {
    lock.withLock { self.transaction = transaction }
  }
}

// MARK: - InjectedActivationError

private enum InjectedActivationError: Error {
  case boundary
  case bookmark
  case preference
}

// MARK: - LockedPreferenceProjection

private final class LockedPreferenceProjection: @unchecked Sendable {
  private let lock = NSLock()
  private var preference: CacheLocationPreference?

  func set(_ value: CacheLocationPreference) {
    lock.withLock { preference = value }
  }

  func value() -> CacheLocationPreference? {
    lock.withLock { preference }
  }
}

// MARK: - FakeBookmarkClient

private final class FakeBookmarkClient: SecurityScopedBookmarkClient, @unchecked Sendable {
  static let refreshedBookmark = Data("refreshed".utf8)

  private let lock = NSLock()
  private let resolvedURL: URL
  private let isStale: Bool
  private let startSucceeds: Bool
  private let bookmarkCreationError: Error?
  private var _createCount = 0
  private var _startCount = 0
  private var _stopCount = 0

  init(
    resolvedURL: URL,
    isStale: Bool = false,
    startSucceeds: Bool = true,
    bookmarkCreationError: Error? = nil
  ) {
    self.resolvedURL = resolvedURL
    self.isStale = isStale
    self.startSucceeds = startSucceeds
    self.bookmarkCreationError = bookmarkCreationError
  }

  var createCount: Int { lock.withLock { _createCount } }
  var startCount: Int { lock.withLock { _startCount } }
  var stopCount: Int { lock.withLock { _stopCount } }

  func createBookmark(for url: URL) throws -> Data {
    if let bookmarkCreationError { throw bookmarkCreationError }
    lock.withLock { _createCount += 1 }
    return Self.refreshedBookmark
  }

  func resolveBookmark(_ data: Data) throws -> ResolvedCacheBookmark {
    ResolvedCacheBookmark(url: resolvedURL, isStale: isStale)
  }

  func startAccessing(_ url: URL) -> Bool {
    lock.withLock { _startCount += 1 }
    return startSucceeds
  }

  func stopAccessing(_ url: URL) {
    lock.withLock { _stopCount += 1 }
  }
}
