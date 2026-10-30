//
//  ExternalCache.swift
//  AmperfyKit
//
//  Copyright (c) 2026 Amperfy contributors. All rights reserved.
//
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//

import CryptoKit
import Darwin
import Foundation

// MARK: - CacheRootError

public enum CacheRootError: Error, Equatable, Sendable {
  case unavailable
  case staleGeneration
  case pathEscapesRoot
  case markerMismatch
  case insufficientCapacity(required: Int64, available: Int64)
  case inconsistentActivation
  case unsupportedBookmarkPlatform
  case stagingLimitExceeded
  case migrationRequired
  case invalidPreparedSelection
  case rollbackFailed
}

// MARK: - CacheRootGeneration

public struct CacheRootGeneration: Codable, Equatable, Hashable, Sendable {
  public let id: UUID

  public init(id: UUID = UUID()) {
    self.id = id
  }
}

// MARK: - CacheRootRegistry

/// Thread-safe runtime authority for the active cache root.
///
/// A root transition invalidates every previously issued lease. Final filesystem and Core Data
/// commit boundaries must validate their lease against this registry again.
public final class CacheRootRegistry: @unchecked Sendable {
  private struct ActiveRoot {
    let rootURL: URL
    let generation: CacheRootGeneration
    let stopAccessing: (@Sendable () -> ())?
    let validateRoot: (@Sendable () throws -> ())?
  }

  private let lock = NSRecursiveLock()
  private var activeRoot: ActiveRoot?
  private var isSuspended = false

  public init() {}

  deinit {
    lock.withLock {
      activeRoot?.stopAccessing?()
      activeRoot = nil
    }
  }

  @discardableResult
  public func activate(
    rootURL: URL,
    generation: CacheRootGeneration = CacheRootGeneration(),
    stopAccessing: (@Sendable () -> ())? = nil,
    validateRoot: (@Sendable () throws -> ())? = nil
  )
    -> CacheRootLease {
    let standardizedRoot = rootURL.standardizedFileURL.resolvingSymlinksInPath()
    lock.withLock {
      activeRoot?.stopAccessing?()
      isSuspended = false
      activeRoot = ActiveRoot(
        rootURL: standardizedRoot,
        generation: generation,
        stopAccessing: stopAccessing,
        validateRoot: validateRoot
      )
    }
    return CacheRootLease(
      rootURL: standardizedRoot,
      generation: generation,
      registry: self
    )
  }

  public func block() {
    lock.withLock {
      activeRoot?.stopAccessing?()
      activeRoot = nil
    }
  }

  /// Stop new cache operations while retaining the source security scope for a move.
  public func suspend() {
    lock.withLock { isSuspended = true }
  }

  public func currentLease() throws -> CacheRootLease {
    try lock.withLock {
      guard let activeRoot, !isSuspended else { throw CacheRootError.unavailable }
      try activeRoot.validateRoot?()
      return CacheRootLease(
        rootURL: activeRoot.rootURL,
        generation: activeRoot.generation,
        registry: self
      )
    }
  }

  fileprivate func validate(_ generation: CacheRootGeneration) throws {
    try lock.withLock {
      guard let activeRoot, !isSuspended else { throw CacheRootError.unavailable }
      guard activeRoot.generation == generation else { throw CacheRootError.staleGeneration }
      try activeRoot.validateRoot?()
    }
  }

  fileprivate func performIfCurrent<T>(
    generation: CacheRootGeneration,
    operation: () throws -> T
  ) throws
    -> T {
    try lock.withLock {
      guard let activeRoot, !isSuspended else { throw CacheRootError.unavailable }
      guard activeRoot.generation == generation else { throw CacheRootError.staleGeneration }
      try activeRoot.validateRoot?()
      return try operation()
    }
  }
}

// MARK: - CacheRelativePath

/// A filesystem-relative cache path. It deliberately does not use URL parsing, so legal filename
/// characters such as spaces, `#`, `%`, `?`, `:`, and composed/decomposed Unicode are preserved.
public struct CacheRelativePath: Codable, Equatable, Hashable, Sendable {
  public let string: String
  public let components: [String]

  public init(_ string: String) throws {
    guard !string.isEmpty,
          !string.hasPrefix("/"),
          !string.contains("\0")
    else { throw CacheRootError.pathEscapesRoot }
    let components = string.split(separator: "/", omittingEmptySubsequences: false).map(String.init)
    guard components.allSatisfy({ !$0.isEmpty && $0 != "." && $0 != ".." }) else {
      throw CacheRootError.pathEscapesRoot
    }
    self.string = string
    self.components = components
  }

  public init(url: URL) throws {
    try self.init(url.path)
  }

  fileprivate func appending(to rootURL: URL) -> URL {
    components.reduce(rootURL) { partial, component in
      partial.appendingPathComponent(component, isDirectory: false)
    }
  }
}

// MARK: - CacheRootLease

public final class CacheRootLease: @unchecked Sendable {
  public let rootURL: URL
  public let generation: CacheRootGeneration
  private let registry: CacheRootRegistry

  fileprivate init(
    rootURL: URL,
    generation: CacheRootGeneration,
    registry: CacheRootRegistry
  ) {
    self.rootURL = rootURL
    self.generation = generation
    self.registry = registry
  }

  public func validateCurrent() throws {
    try registry.validate(generation)
  }

  public func performAtCommitBoundary<T>(_ operation: () throws -> T) throws -> T {
    try registry.performIfCurrent(generation: generation, operation: operation)
  }

  public func resolve(relativePath: URL) throws -> URL {
    try resolve(relativePath: CacheRelativePath(url: relativePath))
  }

  public func resolve(relativePath: CacheRelativePath) throws -> URL {
    try validateCurrent()
    return try secureContainedURL(relativePath)
  }

  /// Rejects every existing symbolic-link component and proves each resolved component remains
  /// below the real leased root. Call again inside the final commit boundary to close ordinary
  /// time-of-check/time-of-use windows against root transitions.
  public func secureContainedURL(_ relativePath: CacheRelativePath) throws -> URL {
    let realRoot = rootURL.standardizedFileURL.resolvingSymlinksInPath()
    var candidate = realRoot
    for component in relativePath.components {
      candidate.appendPathComponent(component, isDirectory: false)
      var statBuffer = stat()
      if lstat(candidate.path, &statBuffer) == 0 {
        guard statBuffer.st_mode & S_IFMT != S_IFLNK else {
          throw CacheRootError.pathEscapesRoot
        }
        let resolvedExisting = candidate.resolvingSymlinksInPath().standardizedFileURL
        guard Self.isContained(resolvedExisting, by: realRoot) else {
          throw CacheRootError.pathEscapesRoot
        }
      } else if errno != ENOENT {
        throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
      }
    }
    let standardized = candidate.standardizedFileURL
    guard Self.isContained(standardized, by: realRoot) else {
      throw CacheRootError.pathEscapesRoot
    }
    return standardized
  }

  private static func isContained(_ candidate: URL, by root: URL) -> Bool {
    if candidate.path == root.path { return true }
    let rootPrefix = root.path.hasSuffix("/") ? root.path : root.path + "/"
    return candidate.path.hasPrefix(rootPrefix)
  }
}

// MARK: - CacheLocationPreference

public struct CacheLocationPreference: Codable, Equatable, Sendable {
  public enum Mode: String, Codable, Sendable {
    case `default`
    case external
  }

  public static let currentSchemaVersion = 1

  public var schemaVersion: Int
  public var mode: Mode
  public var bookmarkData: Data?
  public var displayName: String?
  public var cacheID: UUID?

  public init(
    schemaVersion: Int = Self.currentSchemaVersion,
    mode: Mode,
    bookmarkData: Data? = nil,
    displayName: String? = nil,
    cacheID: UUID? = nil
  ) {
    self.schemaVersion = schemaVersion
    self.mode = mode
    self.bookmarkData = bookmarkData
    self.displayName = displayName
    self.cacheID = cacheID
  }
}

// MARK: - CacheMarker

public struct CacheMarker: Codable, Equatable, Sendable {
  public static let childDirectoryName = "Amperfy Cache"
  public static let fileName = ".amperfy-cache.json"
  public static let currentSchemaVersion = 1

  public let schemaVersion: Int
  public let cacheID: UUID

  public init(schemaVersion: Int = Self.currentSchemaVersion, cacheID: UUID) {
    self.schemaVersion = schemaVersion
    self.cacheID = cacheID
  }
}

// MARK: - ResolvedCacheBookmark

public struct ResolvedCacheBookmark: Sendable {
  public let url: URL
  public let isStale: Bool

  public init(url: URL, isStale: Bool) {
    self.url = url
    self.isStale = isStale
  }
}

// MARK: - PreparedExternalCacheSelection

/// A security-scoped, in-memory folder candidate. It owns exactly one scope access until it is
/// cancelled or atomically transferred to the active root registry.
public final class PreparedExternalCacheSelection: @unchecked Sendable {
  public let parentURL: URL
  public let bookmarkData: Data
  public let availableCapacity: Int64

  private enum ScopeState: Equatable {
    case active
    case transferred
    case stopped
  }

  private let bookmarkClient: any SecurityScopedBookmarkClient
  private let lock = NSLock()
  private var scopeState: ScopeState = .active

  fileprivate init(
    parentURL: URL,
    bookmarkData: Data,
    availableCapacity: Int64,
    bookmarkClient: any SecurityScopedBookmarkClient
  ) {
    self.parentURL = parentURL
    self.bookmarkData = bookmarkData
    self.availableCapacity = availableCapacity
    self.bookmarkClient = bookmarkClient
  }

  deinit {
    cancel()
  }

  public func cancel() {
    let shouldStop = lock.withLock {
      guard scopeState == .active else { return false }
      scopeState = .stopped
      return true
    }
    if shouldStop {
      bookmarkClient.stopAccessing(parentURL)
    }
  }

  fileprivate func transferScope() throws -> @Sendable () -> () {
    try lock.withLock {
      guard scopeState == .active else { throw CacheRootError.invalidPreparedSelection }
      scopeState = .transferred
      return { [bookmarkClient, parentURL] in
        bookmarkClient.stopAccessing(parentURL)
      }
    }
  }
}

// MARK: - SecurityScopedBookmarkClient

public protocol SecurityScopedBookmarkClient: Sendable {
  func createBookmark(for url: URL) throws -> Data
  func resolveBookmark(_ data: Data) throws -> ResolvedCacheBookmark
  func startAccessing(_ url: URL) -> Bool
  func stopAccessing(_ url: URL)
}

// MARK: - FoundationSecurityScopedBookmarkClient

public struct FoundationSecurityScopedBookmarkClient: SecurityScopedBookmarkClient {
  public init() {}

  public func createBookmark(for url: URL) throws -> Data {
    #if targetEnvironment(macCatalyst) || os(macOS)
      try url.bookmarkData(
        options: [.withSecurityScope],
        includingResourceValuesForKeys: nil,
        relativeTo: nil
      )
    #else
      throw CacheRootError.unsupportedBookmarkPlatform
    #endif
  }

  public func resolveBookmark(_ data: Data) throws -> ResolvedCacheBookmark {
    #if targetEnvironment(macCatalyst) || os(macOS)
      var isStale = false
      let url = try URL(
        resolvingBookmarkData: data,
        options: [.withSecurityScope, .withoutUI, .withoutMounting],
        relativeTo: nil,
        bookmarkDataIsStale: &isStale
      )
      return ResolvedCacheBookmark(url: url, isStale: isStale)
    #else
      throw CacheRootError.unsupportedBookmarkPlatform
    #endif
  }

  public func startAccessing(_ url: URL) -> Bool {
    url.startAccessingSecurityScopedResource()
  }

  public func stopAccessing(_ url: URL) {
    url.stopAccessingSecurityScopedResource()
  }
}

// MARK: - CacheRootHealth

public enum CacheRootHealth: Equatable, Sendable {
  case notConfigured
  case resolving
  case ready(rootURL: URL, availableCapacity: Int64)
  case unavailable(reason: String)
}

// MARK: - CacheRootCoordinator

/// Fail-closed bookmark and root bootstrap coordinator.
///
/// UIKit owns folder presentation. This coordinator owns the returned URL from selection through marker,
/// bookmark, scope, health, and root-generation activation.
public final class CacheRootCoordinator: @unchecked Sendable {
  nonisolated(unsafe) private var _health: CacheRootHealth = .notConfigured
  private let healthLock = NSLock()
  public var health: CacheRootHealth { healthLock.withLock { _health } }

  private let registry: CacheRootRegistry
  private let bookmarkClient: any SecurityScopedBookmarkClient
  private let capacityProvider: any CacheCapacityProviding
  private let atomicStore: DurableAtomicFileStore

  public init(
    registry: CacheRootRegistry,
    bookmarkClient: any SecurityScopedBookmarkClient = FoundationSecurityScopedBookmarkClient(),
    capacityProvider: any CacheCapacityProviding = VolumeImportantUsageCapacityProvider(),
    atomicStore: DurableAtomicFileStore = DurableAtomicFileStore()
  ) {
    self.registry = registry
    self.bookmarkClient = bookmarkClient
    self.capacityProvider = capacityProvider
    self.atomicStore = atomicStore
  }

  func accessParent(for preference: CacheLocationPreference) throws
    -> PreparedExternalCacheSelection {
    guard let bookmark = preference.bookmarkData else { throw CacheRootError.unavailable }
    let resolved = try bookmarkClient.resolveBookmark(bookmark)
    return try prepareExternal(selectedParentURL: resolved.url)
  }

  private func setHealth(_ health: CacheRootHealth) {
    healthLock.withLock { _health = health }
  }

  @discardableResult
  public func activateDefault(rootURL: URL) throws -> CacheRootLease {
    setHealth(.resolving)
    do {
      try verifyWritableDirectory(rootURL)
      let availableCapacity = try capacityProvider.availableCapacity(at: rootURL)
      let lease = registry.activate(rootURL: rootURL)
      setHealth(.ready(rootURL: rootURL.standardizedFileURL, availableCapacity: availableCapacity))
      return lease
    } catch {
      registry.block()
      setHealth(.unavailable(reason: String(describing: error)))
      throw error
    }
  }

  /// Acquires a scoped, complete bookmark candidate without changing root health, registry state,
  /// filesystem ownership, or durable preferences.
  public func prepareExternal(selectedParentURL: URL) throws
    -> PreparedExternalCacheSelection {
    guard bookmarkClient.startAccessing(selectedParentURL) else {
      throw CacheRootError.unavailable
    }

    do {
      try verifyExistingWritableDirectory(selectedParentURL)
      let availableCapacity = try capacityProvider.availableCapacity(at: selectedParentURL)
      let bookmarkData = try bookmarkClient.createBookmark(for: selectedParentURL)
      return PreparedExternalCacheSelection(
        parentURL: selectedParentURL,
        bookmarkData: bookmarkData,
        availableCapacity: availableCapacity,
        bookmarkClient: bookmarkClient
      )
    } catch {
      bookmarkClient.stopAccessing(selectedParentURL)
      throw error
    }
  }

  /// Materializes a newly owned empty cache root after explicit user confirmation. Existing roots
  /// are never adopted implicitly.
  public func materializeExternal(
    prepared: PreparedExternalCacheSelection,
    transaction: ExternalCacheActivationTransaction
  ) throws
    -> CacheLocationPreference {
    let rootURL = prepared.parentURL.appendingPathComponent(
      CacheMarker.childDirectoryName,
      isDirectory: true
    )
    guard rootURL.standardizedFileURL.path == transaction.newRootURL.standardizedFileURL.path else {
      throw CacheRootError.inconsistentActivation
    }
    guard !FileManager.default.fileExists(atPath: rootURL.path) else {
      throw CacheRootError.markerMismatch
    }

    try FileManager.default.createDirectory(at: rootURL, withIntermediateDirectories: false)
    do {
      let marker = CacheMarker(cacheID: transaction.cacheID)
      try atomicStore.write(marker, to: rootURL.appendingPathComponent(CacheMarker.fileName))
      try atomicStore.write(
        transaction,
        to: rootURL.appendingPathComponent(CacheMigrationEngine.receiptFileName)
      )
      try verifyWritableDirectory(rootURL)
      return CacheLocationPreference(
        mode: .external,
        bookmarkData: prepared.bookmarkData,
        displayName: prepared.parentURL.lastPathComponent,
        cacheID: transaction.cacheID
      )
    } catch {
      try? FileManager.default.removeItem(at: rootURL)
      throw error
    }
  }

  @discardableResult
  public func activatePreparedExternal(
    prepared: PreparedExternalCacheSelection,
    preference: CacheLocationPreference
  ) throws
    -> CacheRootLease {
    guard preference.mode == .external,
          preference.bookmarkData == prepared.bookmarkData,
          let expectedCacheID = preference.cacheID
    else { throw CacheRootError.inconsistentActivation }
    let rootURL = prepared.parentURL.appendingPathComponent(
      CacheMarker.childDirectoryName,
      isDirectory: true
    )
    let marker = try atomicStore.read(
      CacheMarker.self,
      from: rootURL.appendingPathComponent(CacheMarker.fileName)
    )
    guard marker.cacheID == expectedCacheID else { throw CacheRootError.markerMismatch }
    try verifyWritableDirectory(rootURL)
    let stopAccessing = try prepared.transferScope()
    let lease = registry.activate(
      rootURL: rootURL,
      stopAccessing: stopAccessing,
      validateRoot: Self.markerValidator(
        rootURL: rootURL,
        cacheID: expectedCacheID
      )
    )
    setHealth(.ready(rootURL: lease.rootURL, availableCapacity: prepared.availableCapacity))
    return lease
  }

  @discardableResult
  public func activateExistingPreparedExternal(
    prepared: PreparedExternalCacheSelection,
    expectedCacheID: UUID
  ) throws
    -> (preference: CacheLocationPreference, lease: CacheRootLease) {
    let rootURL = prepared.parentURL.appendingPathComponent(
      CacheMarker.childDirectoryName,
      isDirectory: true
    )
    let marker = try atomicStore.read(
      CacheMarker.self,
      from: rootURL.appendingPathComponent(CacheMarker.fileName)
    )
    guard marker.cacheID == expectedCacheID else { throw CacheRootError.markerMismatch }
    let preference = CacheLocationPreference(
      mode: .external,
      bookmarkData: prepared.bookmarkData,
      displayName: prepared.parentURL.lastPathComponent,
      cacheID: marker.cacheID
    )
    let lease = try activatePreparedExternal(prepared: prepared, preference: preference)
    return (preference, lease)
  }

  public func resolveExternal(
    preference: CacheLocationPreference
  ) throws
    -> CacheLocationPreference {
    setHealth(.resolving)
    guard preference.mode == .external,
          let bookmarkData = preference.bookmarkData,
          let expectedCacheID = preference.cacheID
    else {
      registry.block()
      setHealth(.unavailable(reason: "external cache preference is incomplete"))
      throw CacheRootError.unavailable
    }

    do {
      let resolved = try bookmarkClient.resolveBookmark(bookmarkData)
      guard bookmarkClient.startAccessing(resolved.url) else {
        throw CacheRootError.unavailable
      }
      do {
        let rootURL = resolved.url.appendingPathComponent(
          CacheMarker.childDirectoryName,
          isDirectory: true
        )
        let marker = try atomicStore.read(
          CacheMarker.self,
          from: rootURL.appendingPathComponent(CacheMarker.fileName)
        )
        guard marker.cacheID == expectedCacheID else { throw CacheRootError.markerMismatch }
        try verifyWritableDirectory(rootURL)
        let availableCapacity = try capacityProvider.availableCapacity(at: rootURL)
        let refreshedBookmark = resolved.isStale
          ? try bookmarkClient.createBookmark(for: resolved.url)
          : bookmarkData
        registry.activate(rootURL: rootURL, stopAccessing: { [bookmarkClient] in
          bookmarkClient.stopAccessing(resolved.url)
        }, validateRoot: Self.markerValidator(rootURL: rootURL, cacheID: expectedCacheID))
        setHealth(.ready(
          rootURL: rootURL.standardizedFileURL,
          availableCapacity: availableCapacity
        ))
        return CacheLocationPreference(
          mode: .external,
          bookmarkData: refreshedBookmark,
          displayName: resolved.url.lastPathComponent,
          cacheID: marker.cacheID
        )
      } catch {
        bookmarkClient.stopAccessing(resolved.url)
        throw error
      }
    } catch {
      registry.block()
      setHealth(.unavailable(reason: String(describing: error)))
      throw error
    }
  }

  private static func markerValidator(rootURL: URL, cacheID: UUID) -> @Sendable () throws -> () {
    {
      let marker = try DurableAtomicFileStore().read(
        CacheMarker.self,
        from: rootURL
          .appendingPathComponent(CacheMarker.fileName)
      )
      guard marker.cacheID == cacheID else { throw CacheRootError.markerMismatch }
    }
  }

  public func block(reason: String) {
    registry.block()
    setHealth(.unavailable(reason: reason))
  }

  private func verifyWritableDirectory(_ directoryURL: URL) throws {
    try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
    let probeURL = directoryURL.appendingPathComponent(".amperfy-write-probe-\(UUID().uuidString)")
    do {
      try Data().write(to: probeURL, options: [.atomic])
      try FileManager.default.removeItem(at: probeURL)
    } catch {
      try? FileManager.default.removeItem(at: probeURL)
      throw error
    }
  }

  private func verifyExistingWritableDirectory(_ directoryURL: URL) throws {
    var isDirectory: ObjCBool = false
    guard FileManager.default.fileExists(atPath: directoryURL.path, isDirectory: &isDirectory),
          isDirectory.boolValue
    else { throw CacheRootError.unavailable }
    let probeURL = directoryURL.appendingPathComponent(
      ".amperfy-selection-probe-\(UUID().uuidString)"
    )
    do {
      try Data().write(to: probeURL, options: [.atomic])
      try FileManager.default.removeItem(at: probeURL)
    } catch {
      try? FileManager.default.removeItem(at: probeURL)
      throw error
    }
  }
}

// MARK: - CacheLocationPreferenceStoring

public protocol CacheLocationPreferenceStoring: Sendable {
  func load() throws -> CacheLocationPreference
  func save(_ preference: CacheLocationPreference) throws
}

// MARK: - UserDefaultsCacheLocationPreferenceStore

public final class UserDefaultsCacheLocationPreferenceStore: @unchecked Sendable,
  CacheLocationPreferenceStoring {
  public static let key = "cache.location.preference.v1"

  private let defaults: UserDefaults
  private let key: String

  public init(
    defaults: UserDefaults = .standard,
    key: String = UserDefaultsCacheLocationPreferenceStore.key
  ) {
    self.defaults = defaults
    self.key = key
  }

  public func load() throws -> CacheLocationPreference {
    guard let data = defaults.data(forKey: key) else {
      return CacheLocationPreference(mode: .default)
    }
    return try JSONDecoder().decode(CacheLocationPreference.self, from: data)
  }

  public func save(_ preference: CacheLocationPreference) throws {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    defaults.set(try encoder.encode(preference), forKey: key)
  }
}

// MARK: - CacheLocationConfigurationPaths

public enum CacheLocationConfigurationPaths {
  public static var directoryURL: URL {
    let applicationSupport = FileManager.default.urls(
      for: .applicationSupportDirectory,
      in: .userDomainMask
    ).first ?? FileManager.default.temporaryDirectory
    return applicationSupport
      .appendingPathComponent("Amperfy", isDirectory: true)
      .appendingPathComponent("CacheLocation", isDirectory: true)
  }

  public static var preferenceURL: URL {
    directoryURL.appendingPathComponent("configuration.json")
  }

  public static var activationURL: URL {
    directoryURL.appendingPathComponent("activation.json")
  }
}

// MARK: - DurableCacheLocationPreferenceStore

/// Authoritative app-container configuration. UserDefaults is written only as a UI projection and
/// is never consulted when the durable file is absent or inconsistent.
public final class DurableCacheLocationPreferenceStore: @unchecked Sendable,
  CacheLocationPreferenceStoring {
  public let configurationURL: URL

  private let atomicStore: DurableAtomicFileStore
  private let projection: (any CacheLocationPreferenceStoring)?

  public init(
    configurationURL: URL = CacheLocationConfigurationPaths.preferenceURL,
    atomicStore: DurableAtomicFileStore = DurableAtomicFileStore(),
    projection: (any CacheLocationPreferenceStoring)? = UserDefaultsCacheLocationPreferenceStore()
  ) {
    self.configurationURL = configurationURL
    self.atomicStore = atomicStore
    self.projection = projection
  }

  public func load() throws -> CacheLocationPreference {
    guard FileManager.default.fileExists(atPath: configurationURL.path) else {
      return CacheLocationPreference(mode: .default)
    }
    return try atomicStore.read(CacheLocationPreference.self, from: configurationURL)
  }

  public func save(_ preference: CacheLocationPreference) throws {
    try atomicStore.write(preference, to: configurationURL)
    try projection?.save(preference)
  }
}

// MARK: - ExternalCacheActivationPhase

public enum ExternalCacheActivationPhase: String, Codable, Sendable {
  case prepared
  case destinationMaterialized
  case preferencePersisted
  case registryActivated
  case completed
  case rolledBack
  case blocked
}

// MARK: - ExternalCacheActivationTransaction

public struct ExternalCacheActivationTransaction: Codable, Equatable, Sendable {
  public let transactionID: UUID
  public let cacheID: UUID
  public let oldPreference: CacheLocationPreference
  public let oldRootURL: URL
  public let newPreference: CacheLocationPreference
  public let newRootURL: URL
  public var phase: ExternalCacheActivationPhase
  public var failureDescription: String?

  public init(
    transactionID: UUID = UUID(),
    cacheID: UUID,
    oldPreference: CacheLocationPreference,
    oldRootURL: URL,
    newPreference: CacheLocationPreference,
    newRootURL: URL,
    phase: ExternalCacheActivationPhase,
    failureDescription: String? = nil
  ) {
    self.transactionID = transactionID
    self.cacheID = cacheID
    self.oldPreference = oldPreference
    self.oldRootURL = oldRootURL
    self.newPreference = newPreference
    self.newRootURL = newRootURL
    self.phase = phase
    self.failureDescription = failureDescription
  }
}

// MARK: - ExternalCacheActivationStoring

public protocol ExternalCacheActivationStoring: Sendable {
  func load() throws -> ExternalCacheActivationTransaction?
  func save(_ transaction: ExternalCacheActivationTransaction) throws
}

// MARK: - DurableExternalCacheActivationStore

public final class DurableExternalCacheActivationStore: @unchecked Sendable,
  ExternalCacheActivationStoring {
  public let transactionURL: URL
  private let atomicStore: DurableAtomicFileStore

  public init(
    transactionURL: URL = CacheLocationConfigurationPaths.activationURL,
    atomicStore: DurableAtomicFileStore = DurableAtomicFileStore()
  ) {
    self.transactionURL = transactionURL
    self.atomicStore = atomicStore
  }

  public func load() throws -> ExternalCacheActivationTransaction? {
    guard FileManager.default.fileExists(atPath: transactionURL.path) else { return nil }
    return try atomicStore.read(ExternalCacheActivationTransaction.self, from: transactionURL)
  }

  public func save(_ transaction: ExternalCacheActivationTransaction) throws {
    try atomicStore.write(transaction, to: transactionURL)
  }
}

// MARK: - CacheDirectActivationInventoryGate

/// Direct activation is allowed only for a structurally empty root. An empty top-level `accounts`
/// directory is an initialized layout, not an account subtree; anything below it requires migration.
public struct CacheDirectActivationInventoryGate: Sendable {
  private let atomicStore: DurableAtomicFileStore

  public init(atomicStore: DurableAtomicFileStore = DurableAtomicFileStore()) {
    self.atomicStore = atomicStore
  }

  public func validate(rootURL: URL) throws {
    guard FileManager.default.fileExists(atPath: rootURL.path) else { return }
    guard let enumerator = FileManager.default.enumerator(
      at: rootURL,
      includingPropertiesForKeys: [.isDirectoryKey, .isRegularFileKey, .isSymbolicLinkKey],
      options: []
    ) else { return }

    let rootPrefix = rootURL.standardizedFileURL.path + "/"
    var markerURL: URL?
    var receiptURL: URL?
    while let itemURL = enumerator.nextObject() as? URL {
      let itemPath = itemURL.standardizedFileURL.path
      guard itemPath.hasPrefix(rootPrefix) else { throw CacheRootError.pathEscapesRoot }
      let relative = try CacheRelativePath(String(itemPath.dropFirst(rootPrefix.count)))
      let values = try itemURL.resourceValues(forKeys: [
        .isDirectoryKey,
        .isRegularFileKey,
        .isSymbolicLinkKey,
      ])
      guard values.isSymbolicLink != true else { throw CacheRootError.migrationRequired }
      if values.isDirectory == true,
         relative.components == ["accounts"] {
        continue
      }
      if values.isRegularFile == true,
         relative.components == [CacheMarker.fileName] {
        markerURL = itemURL
        continue
      }
      if values.isRegularFile == true,
         relative.components == [CacheMigrationEngine.receiptFileName] {
        receiptURL = itemURL
        continue
      }
      throw CacheRootError.migrationRequired
    }

    guard markerURL != nil || receiptURL != nil else { return }
    guard let markerURL, let receiptURL else { throw CacheRootError.migrationRequired }
    let marker = try atomicStore.read(CacheMarker.self, from: markerURL)
    guard marker.schemaVersion == CacheMarker.currentSchemaVersion,
          try isResolvedReceipt(receiptURL, marker: marker)
    else { throw CacheRootError.migrationRequired }
  }

  private func isResolvedReceipt(_ receiptURL: URL, marker: CacheMarker) throws -> Bool {
    if let transaction = try? atomicStore.read(
      ExternalCacheActivationTransaction.self,
      from: receiptURL
    ) {
      return transaction.phase == .completed &&
        transaction.cacheID == marker.cacheID
    }
    if let receipt = try? atomicStore.read(CacheActivationReceipt.self, from: receiptURL) {
      return receipt.phase == .activated && receipt.cacheID == marker.cacheID
    }
    return false
  }
}

// MARK: - CacheBootstrapState

public enum CacheBootstrapState: Equatable, Sendable {
  case unresolved
  case resolving
  case ready(preference: CacheLocationPreference, rootURL: URL)
  case blocked(reason: String)
}

// MARK: - CacheLocationPresentation

/// Deterministic, dependency-free presentation state shared by Settings and the blocked shell.
public struct CacheLocationPresentation: Equatable, Sendable {
  public let statusText: String
  public let blocksNormalOperation: Bool

  public init(state: CacheBootstrapState) {
    switch state {
    case let .ready(preference, rootURL):
      let label = preference.mode == .default ? "Default" : "External"
      self.init(statusText: "\(label) — \(rootURL.path)", blocksNormalOperation: false)
    case let .blocked(reason):
      self.init(statusText: "Unavailable — \(reason)", blocksNormalOperation: true)
    case .resolving:
      self.init(statusText: "Checking cache location…", blocksNormalOperation: true)
    case .unresolved:
      self.init(statusText: "Not checked", blocksNormalOperation: true)
    }
  }

  private init(statusText: String, blocksNormalOperation: Bool) {
    self.statusText = statusText
    self.blocksNormalOperation = blocksNormalOperation
  }
}

// MARK: - PendingCacheLocationSelection

/// Ephemeral folder-picker state. Choosing a folder records only an in-memory candidate; durable
/// bookmark creation, root activation, and migration belong to a separately confirmed workflow.
public struct PendingCacheLocationSelection: Equatable, Sendable {
  public private(set) var isPickerPresented = false
  public private(set) var parentURL: URL?

  public init() {}

  public mutating func beginChoosing() {
    isPickerPresented = true
  }

  public mutating func select(_ url: URL) {
    parentURL = url
    isPickerPresented = false
  }

  public mutating func cancel() {
    isPickerPresented = false
  }

  public mutating func clear() {
    isPickerPresented = false
    parentURL = nil
  }
}

// MARK: - CacheRootRuntime

/// The sole production bootstrap authority. Its registry begins blocked. Neither the default root
/// nor an external root becomes visible to any cache consumer until `bootstrap()` resolves the
/// persisted preference and the coordinator completes its health checks.
public final class CacheRootRuntime: @unchecked Sendable {
  public static let shared = CacheRootRuntime()

  public let registry: CacheRootRegistry
  public let coordinator: CacheRootCoordinator
  public let fileManager: CacheFileManager

  private let preferenceStore: any CacheLocationPreferenceStoring
  private let activationStore: any ExternalCacheActivationStoring
  private let inventoryGate: CacheDirectActivationInventoryGate
  private let atomicStore: DurableAtomicFileStore
  private let activationBoundary: @Sendable (ExternalCacheActivationPhase) throws -> ()
  private let defaultRootProvider: @Sendable () throws -> URL
  private let stateLock = NSLock()
  private let operationLock = NSLock()
  private let relocationURL: URL
  nonisolated(unsafe) private var _state: CacheBootstrapState = .unresolved

  public var state: CacheBootstrapState { stateLock.withLock { _state } }

  public init(
    registry: CacheRootRegistry = CacheRootRegistry(),
    preferenceStore: any CacheLocationPreferenceStoring =
      DurableCacheLocationPreferenceStore(),
    activationStore: any ExternalCacheActivationStoring =
      DurableExternalCacheActivationStore(),
    inventoryGate: CacheDirectActivationInventoryGate = CacheDirectActivationInventoryGate(),
    defaultRootProvider: @escaping @Sendable () throws -> URL = CacheRootRuntime
      .defaultInternalRoot,
    bookmarkClient: any SecurityScopedBookmarkClient = FoundationSecurityScopedBookmarkClient(),
    capacityProvider: any CacheCapacityProviding = VolumeImportantUsageCapacityProvider(),
    atomicStore: DurableAtomicFileStore = DurableAtomicFileStore(),
    backgroundStagingRoot: URL? = nil,
    relocationURL: URL = CacheLocationConfigurationPaths.preferenceURL.deletingLastPathComponent()
      .appendingPathComponent("relocation.json"),
    activationBoundary: @escaping @Sendable (ExternalCacheActivationPhase) throws -> () = { _ in }
  ) {
    self.registry = registry
    self.relocationURL = relocationURL
    self.preferenceStore = preferenceStore
    self.activationStore = activationStore
    self.inventoryGate = inventoryGate
    self.atomicStore = atomicStore
    self.activationBoundary = activationBoundary
    self.defaultRootProvider = defaultRootProvider
    self.coordinator = CacheRootCoordinator(
      registry: registry,
      bookmarkClient: bookmarkClient,
      capacityProvider: capacityProvider,
      atomicStore: atomicStore
    )
    self.fileManager = CacheFileManager(
      rootRegistry: registry,
      backgroundStagingRoot: backgroundStagingRoot
    )
  }

  @discardableResult
  public func bootstrap() throws -> CacheBootstrapState {
    setState(.resolving)
    registry.block()
    do {
      try reconcileInterruptedActivation()
      let storedPreference = try preferenceStore.load()
      let resolvedPreference: CacheLocationPreference
      let lease: CacheRootLease
      switch storedPreference.mode {
      case .default:
        lease = try coordinator.activateDefault(rootURL: defaultRootProvider())
        resolvedPreference = CacheLocationPreference(mode: .default)
      case .external:
        resolvedPreference = try coordinator.resolveExternal(preference: storedPreference)
        lease = try registry.currentLease()
        if resolvedPreference != storedPreference {
          try preferenceStore.save(resolvedPreference)
        }
      }
      try fileManager.rootDidActivate(using: lease)
      let ready = CacheBootstrapState.ready(
        preference: resolvedPreference,
        rootURL: lease.rootURL
      )
      setState(ready)
      return ready
    } catch {
      registry.block()
      fileManager.rootDidBlock()
      let blocked = CacheBootstrapState.blocked(reason: String(describing: error))
      setState(blocked)
      throw error
    }
  }

  /// Preflights a UIKit-selected folder while the current Ready root remains active.
  @discardableResult
  public func prepareExternal(selectedParentURL: URL) throws
    -> PreparedExternalCacheSelection {
    guard operationLock.try() else { throw CacheRootError.unavailable }
    defer { operationLock.unlock() }
    guard case .ready = state else { throw CacheRootError.unavailable }
    return try coordinator.prepareExternal(selectedParentURL: selectedParentURL)
  }

  /// Confirms a prepared selection using a durable app-container transaction and mirrored
  /// destination receipt. Every ordinary failure restores the prior complete Ready root.
  @discardableResult
  public func confirmPreparedExternal(
    _ prepared: PreparedExternalCacheSelection
  ) throws
    -> CacheLocationPreference {
    guard operationLock.try() else { throw CacheRootError.unavailable }
    defer { operationLock.unlock() }
    guard case let .ready(oldPreference, oldRootURL) = state else {
      throw CacheRootError.unavailable
    }
    let oldLease = try registry.currentLease()
    try oldLease.validateCurrent()
    try inventoryGate.validate(rootURL: oldRootURL)

    let cacheID = UUID()
    let newRootURL = prepared.parentURL.appendingPathComponent(
      CacheMarker.childDirectoryName,
      isDirectory: true
    )
    let newPreference = CacheLocationPreference(
      mode: .external,
      bookmarkData: prepared.bookmarkData,
      displayName: prepared.parentURL.lastPathComponent,
      cacheID: cacheID
    )
    var transaction = ExternalCacheActivationTransaction(
      cacheID: cacheID,
      oldPreference: oldPreference,
      oldRootURL: oldRootURL,
      newPreference: newPreference,
      newRootURL: newRootURL,
      phase: .prepared
    )
    var destinationWasMaterialized = false

    do {
      try persist(transaction, mirrorToDestination: false)
      try activationBoundary(.prepared)

      let materializedPreference = try coordinator.materializeExternal(
        prepared: prepared,
        transaction: transaction
      )
      destinationWasMaterialized = true
      guard materializedPreference == newPreference else {
        throw CacheRootError.inconsistentActivation
      }
      transaction.phase = .destinationMaterialized
      try persist(transaction, mirrorToDestination: true)
      try activationBoundary(.destinationMaterialized)

      try preferenceStore.save(newPreference)
      transaction.phase = .preferencePersisted
      try persist(transaction, mirrorToDestination: true)
      try activationBoundary(.preferencePersisted)

      let lease = try coordinator.activatePreparedExternal(
        prepared: prepared,
        preference: newPreference
      )
      transaction.phase = .registryActivated
      try persist(transaction, mirrorToDestination: true)
      try activationBoundary(.registryActivated)

      try fileManager.rootDidActivate(using: lease)
      transaction.phase = .completed
      try persist(transaction, mirrorToDestination: true)
      try activationBoundary(.completed)

      setState(.ready(preference: newPreference, rootURL: lease.rootURL))
      return newPreference
    } catch {
      do {
        try rollbackActivation(
          transaction: &transaction,
          destinationWasMaterialized: destinationWasMaterialized,
          originalError: error
        )
        prepared.cancel()
      } catch {
        prepared.cancel()
        coordinator.block(reason: "external cache activation rollback failed")
        fileManager.rootDidBlock()
        transaction.phase = .blocked
        transaction.failureDescription = String(describing: error)
        try? persist(transaction, mirrorToDestination: destinationWasMaterialized)
        setState(.blocked(reason: "external cache activation rollback failed"))
        throw CacheRootError.rollbackFailed
      }
      throw error
    }
  }

  /// Re-selects the already configured cache after a stale bookmark or reconnect. A different
  /// cache ID is rejected; selecting a new destination belongs to the migration workflow.
  @discardableResult
  public func reselectConfiguredExternal(selectedParentURL: URL) throws
    -> CacheLocationPreference {
    guard operationLock.try() else { throw CacheRootError.unavailable }
    defer { operationLock.unlock() }
    let stored = try preferenceStore.load()
    guard stored.mode == .external, let cacheID = stored.cacheID else {
      throw CacheRootError.unavailable
    }
    let prepared = try coordinator.prepareExternal(selectedParentURL: selectedParentURL)
    do {
      let activated = try coordinator.activateExistingPreparedExternal(
        prepared: prepared,
        expectedCacheID: cacheID
      )
      try preferenceStore.save(activated.preference)
      try fileManager.rootDidActivate(using: activated.lease)
      setState(.ready(preference: activated.preference, rootURL: activated.lease.rootURL))
      return activated.preference
    } catch {
      prepared.cancel()
      coordinator.block(reason: String(describing: error))
      fileManager.rootDidBlock()
      setState(.blocked(reason: String(describing: error)))
      throw error
    }
  }

  public func block(reason: String) {
    coordinator.block(reason: reason)
    fileManager.rootDidBlock()
    setState(.blocked(reason: reason))
  }

  private func setState(_ state: CacheBootstrapState) {
    let changed = stateLock.withLock {
      let changed = _state != state
      _state = state
      return changed
    }
    if changed { NotificationCenter.default.post(name: Self.didChangeNotification, object: nil) }
  }

  private func persist(
    _ transaction: ExternalCacheActivationTransaction,
    mirrorToDestination: Bool
  ) throws {
    try activationStore.save(transaction)
    if mirrorToDestination {
      try atomicStore.write(
        transaction,
        to: transaction.newRootURL.appendingPathComponent(
          CacheMigrationEngine.receiptFileName
        )
      )
    }
  }

  private func rollbackActivation(
    transaction: inout ExternalCacheActivationTransaction,
    destinationWasMaterialized: Bool,
    originalError: Error
  ) throws {
    try preferenceStore.save(transaction.oldPreference)
    try restoreRoot(
      preference: transaction.oldPreference,
      rootURL: transaction.oldRootURL
    )
    if destinationWasMaterialized {
      try removeOwnedDestination(transaction)
    }
    transaction.phase = .rolledBack
    transaction.failureDescription = String(describing: originalError)
    try persist(transaction, mirrorToDestination: false)
    setState(.ready(
      preference: transaction.oldPreference,
      rootURL: transaction.oldRootURL.standardizedFileURL.resolvingSymlinksInPath()
    ))
  }

  private func restoreRoot(preference: CacheLocationPreference, rootURL: URL) throws {
    let lease: CacheRootLease
    switch preference.mode {
    case .default:
      lease = try coordinator.activateDefault(rootURL: rootURL)
    case .external:
      _ = try coordinator.resolveExternal(preference: preference)
      lease = try registry.currentLease()
    }
    try fileManager.rootDidActivate(using: lease)
  }

  private func removeOwnedDestination(_ transaction: ExternalCacheActivationTransaction) throws {
    guard FileManager.default.fileExists(atPath: transaction.newRootURL.path) else { return }
    let marker = try atomicStore.read(
      CacheMarker.self,
      from: transaction.newRootURL.appendingPathComponent(CacheMarker.fileName)
    )
    guard marker.cacheID == transaction.cacheID else { throw CacheRootError.markerMismatch }
    let allowed = Set([CacheMarker.fileName, CacheMigrationEngine.receiptFileName])
    let contents = try FileManager.default.contentsOfDirectory(atPath: transaction.newRootURL.path)
    guard Set(contents).isSubset(of: allowed) else { throw CacheRootError.rollbackFailed }
    try FileManager.default.removeItem(at: transaction.newRootURL)
  }

  private func reconcileInterruptedActivation() throws {
    guard var transaction = try activationStore.load() else { return }
    switch transaction.phase {
    case .completed:
      return
    case .rolledBack:
      try preferenceStore.save(transaction.oldPreference)
    case .blocked:
      throw CacheRootError.inconsistentActivation
    case .prepared:
      try preferenceStore.save(transaction.oldPreference)
      transaction.phase = .rolledBack
      try persist(transaction, mirrorToDestination: false)
    case .destinationMaterialized, .preferencePersisted:
      let mirrored = try atomicStore.read(
        ExternalCacheActivationTransaction.self,
        from: transaction.newRootURL.appendingPathComponent(
          CacheMigrationEngine.receiptFileName
        )
      )
      guard mirrored == transaction else { throw CacheRootError.inconsistentActivation }
      try preferenceStore.save(transaction.oldPreference)
      try removeOwnedDestination(transaction)
      transaction.phase = .rolledBack
      try persist(transaction, mirrorToDestination: false)
    case .registryActivated:
      let mirrored = try atomicStore.read(
        ExternalCacheActivationTransaction.self,
        from: transaction.newRootURL.appendingPathComponent(
          CacheMigrationEngine.receiptFileName
        )
      )
      guard mirrored == transaction,
            try preferenceStore.load() == transaction.newPreference
      else { throw CacheRootError.inconsistentActivation }
      transaction.phase = .completed
      try persist(transaction, mirrorToDestination: true)
    }
  }

  public static let didChangeNotification = Notification.Name("AmperfyCacheLocationDidChange")

  public var isCacheAvailable: Bool {
    if case .ready = state { return true }
    return false
  }

  public func configuredPreference() throws -> CacheLocationPreference {
    try preferenceStore.load()
  }

  public func availableCapacity() throws -> Int64 {
    try VolumeImportantUsageCapacityProvider()
      .availableCapacity(at: registry.currentLease().rootURL)
  }

  public func cacheInventorySize() throws -> Int64 {
    let lease = try registry.currentLease()
    return try lease.performAtCommitBoundary {
      var scanError: Error?
      guard let files = FileManager.default.enumerator(
        at: lease.rootURL,
        includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey],
        errorHandler: { _, error in scanError = error; return false }
      ) else {
        throw CacheRootError.unavailable
      }
      var size: Int64 = 0
      for case let url as URL in files {
        let values = try url.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey])
        if values.isRegularFile == true { size += Int64(values.fileSize ?? 0) }
      }
      if let scanError { throw scanError }
      return size
    }
  }

  /// Polling checks the identity rather than trusting a mount path that may have been reused.
  public func refreshAvailability() {
    guard operationLock.try() else { return }
    defer { operationLock.unlock() }
    if case let .ready(preference, root) = state {
      guard preference.mode == .external else { return }
      do {
        let marker = try atomicStore.read(
          CacheMarker.self,
          from: root.appendingPathComponent(CacheMarker.fileName)
        )
        guard marker.cacheID == preference.cacheID else { throw CacheRootError.markerMismatch }
        return
      } catch {
        coordinator.block(reason: "Reconnect the drive containing your cache.")
        setState(.blocked(reason: "Reconnect the drive containing your cache."))
      }
    } else if case .blocked = state {
      _ = try? bootstrap()
    }
  }

  public var hasUnfinishedMove: Bool {
    FileManager.default.fileExists(atPath: relocationURL.path)
  }

  /// A failed or interrupted copy never changes the authoritative preference. A committed
  /// copy is authoritative even if removing the old copy was interrupted.
  public func finishInterruptedMove() throws {
    guard operationLock.try() else { throw CacheRootError.unavailable }
    defer { operationLock.unlock() }
    try finishRelocation()
  }

  private func finishRelocation() throws {
    guard hasUnfinishedMove else { return }
    let move = try atomicStore.read(CacheRelocationRecord.self, from: relocationURL)
    let current = try preferenceStore.load()
    let committed = current.mode == move.newPreference.mode && current.cacheID == move.newPreference
      .cacheID
    guard committed || current == move.oldPreference
    else { throw CacheRootError.inconsistentActivation }
    let preference = committed ? move.oldPreference : move.newPreference
    let access = preference.mode == .external ? try coordinator.accessParent(for: preference) : nil
    defer { access?.cancel() }
    let expectedRoot = committed ? move.source : move.destination
    let resolvedRoot = try access?.parentURL.appendingPathComponent(CacheMarker.childDirectoryName)
      ?? defaultRootProvider()
    guard resolvedRoot.standardizedFileURL.resolvingSymlinksInPath().path == expectedRoot
      .standardizedFileURL.resolvingSymlinksInPath().path else {
      throw CacheRootError.markerMismatch
    }
    try CacheRelocationCopy.finish(move, committed: committed)
    try FileManager.default.removeItem(at: relocationURL)
  }

  /// Run away from the main actor. The registry excludes all cache consumers during the
  /// copy; the original security scope remains alive until activation has completed.
  public func relocateCache(
    to prepared: PreparedExternalCacheSelection?,
    progress: @escaping @Sendable (CacheMoveProgress) -> (),
    checkCancellation: @escaping @Sendable () throws -> () = {}
  ) throws {
    guard operationLock.try() else { throw CacheRootError.unavailable }
    defer { operationLock.unlock(); prepared?.cancel() }
    try finishRelocation()
    guard case let .ready(oldPreference, source) = state else { throw CacheRootError.unavailable }
    let destination = try prepared?.parentURL.appendingPathComponent(CacheMarker.childDirectoryName)
      ?? defaultRootProvider()
    guard source.standardizedFileURL != destination.standardizedFileURL,
          !destination.path.hasPrefix(source.path + "/"),
          !source.path.hasPrefix(destination.path + "/")
    else { throw CacheRootError.invalidPreparedSelection }
    let cacheID = UUID()
    let preference = prepared.map {
      CacheLocationPreference(
        mode: .external,
        bookmarkData: $0.bookmarkData,
        displayName: $0.parentURL.lastPathComponent,
        cacheID: cacheID
      )
    } ?? CacheLocationPreference(mode: .default)
    // Keep independent access to the old drive until verified cleanup has finished.
    let sourceAccess = oldPreference.mode == .external ? try coordinator
      .accessParent(for: oldPreference) : nil
    defer { sourceAccess?.cancel() }
    _ = try registry.currentLease()
    registry.suspend()
    setState(.resolving)
    do {
      progress(CacheMoveProgress(message: "Checking downloaded files…"))
      let inventory = try CacheInventoryBuilder().build(
        rootURL: source,
        checkCancellation: checkCancellation
      )
      try checkCancellation()
      let move = CacheRelocationRecord(
        source: source,
        destination: destination,
        oldPreference: oldPreference,
        newPreference: preference,
        cacheID: cacheID,
        inventory: inventory
      )
      try atomicStore.write(move, to: relocationURL)
      try CacheRelocationCopy.copy(move, progress: progress, checkCancellation: checkCancellation)
      try checkCancellation()
      progress(CacheMoveProgress(message: "Switching cache location…"))
      // The single durable preference write is the commit point. On either side of a
      // crash, finishRelocation can identify the authoritative copy without guessing.
      try preferenceStore.save(preference)
      _ = try bootstrap()
      progress(CacheMoveProgress(message: "Removing the previous copy…"))
      try CacheRelocationCopy.finish(move, committed: true)
      try FileManager.default.removeItem(at: relocationURL)
    } catch {
      _ = try? bootstrap()
      // Cleanup is idempotent. If a drive disappeared, retain the journal for Retry.
      try? finishRelocation()
      throw error
    }
  }

  public static func defaultInternalRoot() throws -> URL {
    if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil,
       let injectedTestRoot = ProcessInfo.processInfo.environment["AMPERFY_CACHE_TEST_ROOT"],
       !injectedTestRoot.isEmpty {
      return URL(fileURLWithPath: injectedTestRoot, isDirectory: true)
    }
    guard let bundleIdentifier = Bundle.main.bundleIdentifier else {
      throw CacheRootError.unavailable
    }
    let libraryURL = try FileManager.default.url(
      for: .libraryDirectory,
      in: .userDomainMask,
      appropriateFor: nil,
      create: false
    )
    return libraryURL.appendingPathComponent(bundleIdentifier, isDirectory: true)
  }
}

// MARK: - DurableAtomicFileStore

public struct DurableAtomicFileStore: Sendable {
  public init() {}

  public func write<T: Encodable>(_ value: T, to url: URL) throws {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    try write(encoder.encode(value), to: url)
  }

  public func read<T: Decodable>(_ type: T.Type, from url: URL) throws -> T {
    try JSONDecoder().decode(type, from: Data(contentsOf: url))
  }

  public func write(_ data: Data, to url: URL) throws {
    let fileManager = FileManager.default
    let directory = url.deletingLastPathComponent()
    try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
    let temporaryURL = directory
      .appendingPathComponent(".\(url.lastPathComponent).\(UUID().uuidString).tmp")

    guard fileManager.createFile(atPath: temporaryURL.path, contents: nil) else {
      throw CocoaError(.fileWriteUnknown)
    }

    do {
      let handle = try FileHandle(forWritingTo: temporaryURL)
      try handle.write(contentsOf: data)
      try handle.synchronize()
      try handle.close()

      guard Darwin.rename(temporaryURL.path, url.path) == 0 else {
        throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
      }
      try synchronizeDirectory(at: directory)
    } catch {
      try? fileManager.removeItem(at: temporaryURL)
      throw error
    }
  }

  private func synchronizeDirectory(at url: URL) throws {
    let descriptor = Darwin.open(url.path, O_RDONLY)
    guard descriptor >= 0 else {
      throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
    }
    defer { Darwin.close(descriptor) }
    guard Darwin.fsync(descriptor) == 0 else {
      throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
    }
  }
}

// MARK: - CacheMigrationPhase

public enum CacheMigrationPhase: String, Codable, Sendable {
  case planned
  case copying
  case verifying
  case readyToActivate
  case activated
  case accepted
  case sourceRetired
}

// MARK: - CacheInventoryEntry

public struct CacheInventoryEntry: Codable, Equatable, Sendable {
  public let relativePath: String
  public let byteCount: Int64
  public let sha256: String

  public init(relativePath: String, byteCount: Int64, sha256: String) {
    self.relativePath = relativePath
    self.byteCount = byteCount
    self.sha256 = sha256
  }
}

// MARK: - CacheMigrationJournal

public struct CacheMigrationJournal: Codable, Equatable, Sendable {
  public let transactionID: UUID
  public let sourceCacheID: UUID
  public let destinationCacheID: UUID
  public var phase: CacheMigrationPhase
  public let inventory: [CacheInventoryEntry]

  public init(
    transactionID: UUID,
    sourceCacheID: UUID,
    destinationCacheID: UUID,
    phase: CacheMigrationPhase,
    inventory: [CacheInventoryEntry]
  ) {
    self.transactionID = transactionID
    self.sourceCacheID = sourceCacheID
    self.destinationCacheID = destinationCacheID
    self.phase = phase
    self.inventory = inventory
  }

  public var inventoryBytes: Int64 {
    inventory.reduce(0) { $0 + $1.byteCount }
  }

  public var inventoryDigest: String {
    let canonical = inventory.sorted { $0.relativePath < $1.relativePath }
      .map { "\($0.relativePath)\u{0}\($0.byteCount)\u{0}\($0.sha256)" }
      .joined(separator: "\n")
    return SHA256.hash(data: Data(canonical.utf8)).map { String(format: "%02x", $0) }.joined()
  }
}

// MARK: - CacheActivationReceipt

public struct CacheActivationReceipt: Codable, Equatable, Sendable {
  public let transactionID: UUID
  public let cacheID: UUID
  public let inventoryDigest: String
  public let phase: CacheMigrationPhase

  public init(
    transactionID: UUID,
    cacheID: UUID,
    inventoryDigest: String,
    phase: CacheMigrationPhase = .activated
  ) {
    self.transactionID = transactionID
    self.cacheID = cacheID
    self.inventoryDigest = inventoryDigest
    self.phase = phase
  }
}

// MARK: - CacheActivationReconciliation

public enum CacheActivationReconciliation: Equatable, Sendable {
  case sourceActiveResumeOrAbandon
  case blockCompleteReceiptsOrRollback
  case destinationActive
  case blockedInconsistent
}

// MARK: - CacheActivationEvidence

public struct CacheActivationEvidence: Sendable {
  public var finalDirectoryExists: Bool
  public var destinationMarker: CacheMarker?
  public var appReceipt: CacheActivationReceipt?
  public var destinationReceipt: CacheActivationReceipt?
  public var preferenceCacheID: UUID?

  public init(
    finalDirectoryExists: Bool,
    destinationMarker: CacheMarker?,
    appReceipt: CacheActivationReceipt?,
    destinationReceipt: CacheActivationReceipt?,
    preferenceCacheID: UUID?
  ) {
    self.finalDirectoryExists = finalDirectoryExists
    self.destinationMarker = destinationMarker
    self.appReceipt = appReceipt
    self.destinationReceipt = destinationReceipt
    self.preferenceCacheID = preferenceCacheID
  }
}

// MARK: - CacheActivationReconciler

public struct CacheActivationReconciler: Sendable {
  public init() {}

  public func reconcile(
    journal: CacheMigrationJournal,
    evidence: CacheActivationEvidence
  )
    -> CacheActivationReconciliation {
    let expectedReceipt = CacheActivationReceipt(
      transactionID: journal.transactionID,
      cacheID: journal.destinationCacheID,
      inventoryDigest: journal.inventoryDigest
    )
    let markerMatches = evidence.destinationMarker?.cacheID == journal.destinationCacheID
    let appMatches = evidence.appReceipt == expectedReceipt
    let destinationMatches = evidence.destinationReceipt == expectedReceipt

    if !evidence.finalDirectoryExists,
       evidence.destinationMarker == nil,
       evidence.appReceipt == nil,
       evidence.destinationReceipt == nil,
       evidence.preferenceCacheID != journal.destinationCacheID {
      return .sourceActiveResumeOrAbandon
    }

    if evidence.finalDirectoryExists,
       markerMatches,
       appMatches,
       destinationMatches {
      return .destinationActive
    }

    if evidence.finalDirectoryExists,
       markerMatches,
       appMatches || destinationMatches || evidence.preferenceCacheID == journal
       .destinationCacheID {
      return .blockCompleteReceiptsOrRollback
    }

    return .blockedInconsistent
  }
}

// MARK: - CacheCapacityPolicy

public struct CacheCapacityPolicy: Sendable {
  public static let fiveGiB: Int64 = 5 * 1024 * 1024 * 1024

  public init() {}

  public func reserveBytes(for inventoryBytes: Int64) -> Int64 {
    max(Self.fiveGiB, inventoryBytes / 10)
  }

  public func requiredCapacity(for inventoryBytes: Int64) -> Int64 {
    inventoryBytes + reserveBytes(for: inventoryBytes)
  }

  public func validate(available: Int64, inventoryBytes: Int64) throws {
    let required = requiredCapacity(for: inventoryBytes)
    guard available >= required else {
      throw CacheRootError.insufficientCapacity(required: required, available: available)
    }
  }
}

// MARK: - BackgroundStagingPolicy

public struct BackgroundStagingPolicy: Sendable {
  public static let twoGiB: Int64 = 2 * 1024 * 1024 * 1024
  public static let maximumAge: TimeInterval = 24 * 60 * 60

  public let absoluteByteLimit: Int64
  public let containerCapacityFractionDivisor: Int64
  public let maximumAge: TimeInterval

  public init(
    absoluteByteLimit: Int64 = Self.twoGiB,
    containerCapacityFractionDivisor: Int64 = 10,
    maximumAge: TimeInterval = Self.maximumAge
  ) {
    self.absoluteByteLimit = absoluteByteLimit
    self.containerCapacityFractionDivisor = containerCapacityFractionDivisor
    self.maximumAge = maximumAge
  }

  public func byteLimit(containerAvailableCapacity: Int64) -> Int64 {
    min(absoluteByteLimit, containerAvailableCapacity / containerCapacityFractionDivisor)
  }

  public func permits(
    stagedBytes: Int64,
    oldestItemAge: TimeInterval,
    containerAvailableCapacity: Int64
  )
    -> Bool {
    stagedBytes <= byteLimit(containerAvailableCapacity: containerAvailableCapacity) &&
      oldestItemAge <= maximumAge
  }
}

// MARK: - CacheFileCommitReceipt

/// Durable app-container evidence for the filesystem half of a cache/Core Data transaction.
/// The recoverable staging file remains present until the Core Data commit succeeds.
public struct CacheFileCommitReceipt: Codable, Equatable, Sendable {
  public enum Phase: String, Codable, Sendable {
    case staged
    case filesystemCommitted
  }

  public let transactionID: UUID
  public let relativeDestinationPath: String
  public let stagedFileName: String
  public let byteCount: Int64
  public let sha256: String
  public var phase: Phase

  public init(
    transactionID: UUID,
    relativeDestinationPath: String,
    stagedFileName: String,
    byteCount: Int64,
    sha256: String,
    phase: Phase
  ) {
    self.transactionID = transactionID
    self.relativeDestinationPath = relativeDestinationPath
    self.stagedFileName = stagedFileName
    self.byteCount = byteCount
    self.sha256 = sha256
    self.phase = phase
  }
}

// MARK: - CacheInventoryBuilder

public struct CacheInventoryBuilder: Sendable {
  public static let rootControlFileNames: Set<String> = [
    CacheMarker.fileName,
    CacheMigrationEngine.journalFileName,
    CacheMigrationEngine.receiptFileName,
  ]

  private let excludedRootControlFileNames: Set<String>

  public init(excludedRootControlFileNames: Set<String> = Self.rootControlFileNames) {
    self.excludedRootControlFileNames = excludedRootControlFileNames
  }

  public func build(
    rootURL: URL,
    checkCancellation: @Sendable () throws -> () = {}
  ) throws
    -> [CacheInventoryEntry] {
    try checkCancellation()
    let fileManager = FileManager.default
    let rootValues = try rootURL.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
    guard rootValues.isDirectory == true, rootValues.isSymbolicLink != true else {
      throw CacheRootError.pathEscapesRoot
    }
    var enumerationError: Error?
    guard let enumerator = fileManager.enumerator(
      at: rootURL,
      includingPropertiesForKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey],
      options: [], errorHandler: { _, error in enumerationError = error; return false }
    ) else { throw CacheRootError.unavailable }

    var entries = [CacheInventoryEntry]()
    while let itemURL = enumerator.nextObject() as? URL {
      try checkCancellation()
      let values = try itemURL.resourceValues(forKeys: [
        .isRegularFileKey,
        .isSymbolicLinkKey,
        .fileSizeKey,
      ])
      guard values.isSymbolicLink != true else { throw CacheRootError.pathEscapesRoot }
      guard values.isRegularFile == true else { continue }

      let rootPath = rootURL.standardizedFileURL.path.hasSuffix("/")
        ? rootURL.standardizedFileURL.path
        : rootURL.standardizedFileURL.path + "/"
      let itemPath = itemURL.standardizedFileURL.path
      guard itemPath.hasPrefix(rootPath) else { throw CacheRootError.pathEscapesRoot }
      let relativePath = String(itemPath.dropFirst(rootPath.count))
      let safeRelativePath = try CacheRelativePath(relativePath)
      if safeRelativePath.components.count == 1,
         excludedRootControlFileNames.contains(safeRelativePath.components[0]) {
        continue
      }
      let handle = try FileHandle(forReadingFrom: itemURL)
      defer { try? handle.close() }
      var hash = SHA256()
      var byteCount: Int64 = 0
      while let data = try handle.read(upToCount: 1024 * 1024), !data.isEmpty {
        try checkCancellation()
        hash.update(data: data)
        byteCount += Int64(data.count)
      }
      let digest = hash.finalize().map { String(format: "%02x", $0) }.joined()
      entries.append(CacheInventoryEntry(
        relativePath: safeRelativePath.string,
        byteCount: byteCount,
        sha256: digest
      ))
    }
    if let enumerationError { throw enumerationError }
    return entries.sorted { $0.relativePath < $1.relativePath }
  }
}

// MARK: - CacheCapacityProviding

public protocol CacheCapacityProviding: Sendable {
  func availableCapacity(at url: URL) throws -> Int64
}

// MARK: - VolumeImportantUsageCapacityProvider

public struct VolumeImportantUsageCapacityProvider: CacheCapacityProviding {
  public init() {}

  public func availableCapacity(at url: URL) throws -> Int64 {
    let values = try url.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
    return values.volumeAvailableCapacityForImportantUsage ?? 0
  }
}

// MARK: - CacheMigrationEngine

/// Copy/verify/activate engine. Callers must quiesce all cache consumers before invoking it.
/// The source is never deleted by this type.
public struct CacheMigrationEngine: Sendable {
  public static let journalFileName = ".amperfy-migration.json"
  public static let receiptFileName = ".amperfy-activation.json"

  private let inventoryBuilder: CacheInventoryBuilder
  private let capacityProvider: any CacheCapacityProviding
  private let capacityPolicy: CacheCapacityPolicy
  private let atomicStore: DurableAtomicFileStore

  public init(
    inventoryBuilder: CacheInventoryBuilder = CacheInventoryBuilder(),
    capacityProvider: any CacheCapacityProviding = VolumeImportantUsageCapacityProvider(),
    capacityPolicy: CacheCapacityPolicy = CacheCapacityPolicy(),
    atomicStore: DurableAtomicFileStore = DurableAtomicFileStore()
  ) {
    self.inventoryBuilder = inventoryBuilder
    self.capacityProvider = capacityProvider
    self.capacityPolicy = capacityPolicy
    self.atomicStore = atomicStore
  }

  public func makeJournal(
    sourceRoot: URL,
    sourceCacheID: UUID,
    destinationCacheID: UUID = UUID(),
    transactionID: UUID = UUID()
  ) throws
    -> CacheMigrationJournal {
    CacheMigrationJournal(
      transactionID: transactionID,
      sourceCacheID: sourceCacheID,
      destinationCacheID: destinationCacheID,
      phase: .planned,
      inventory: try inventoryBuilder.build(rootURL: sourceRoot)
    )
  }

  /// Copies and verifies a planned journal, atomically renames the final cache directory, writes
  /// authoritative receipts, then updates the non-authoritative preference projection.
  public func migrate(
    journal initialJournal: CacheMigrationJournal,
    sourceRoot: URL,
    destinationParent: URL,
    appContainerJournalURL: URL,
    activationPreference: CacheLocationPreference,
    projectPreference: @Sendable (CacheLocationPreference) throws -> ()
  ) throws
    -> URL {
    let fileManager = FileManager.default
    let finalRoot = destinationParent.appendingPathComponent(
      CacheMarker.childDirectoryName,
      isDirectory: true
    )
    guard !fileManager.fileExists(atPath: finalRoot.path) else {
      throw CocoaError(.fileWriteFileExists)
    }
    guard activationPreference.mode == .external,
          activationPreference.bookmarkData != nil,
          activationPreference.cacheID == initialJournal.destinationCacheID
    else { throw CacheRootError.inconsistentActivation }

    var journal = initialJournal
    let reserve = capacityPolicy.reserveBytes(for: journal.inventoryBytes)
    try capacityPolicy.validate(
      available: capacityProvider.availableCapacity(at: destinationParent),
      inventoryBytes: journal.inventoryBytes
    )

    let stagingContainer = destinationParent.appendingPathComponent(
      ".amperfy-migration-\(journal.transactionID.uuidString)",
      isDirectory: true
    )
    let stagingRoot = stagingContainer.appendingPathComponent(
      CacheMarker.childDirectoryName,
      isDirectory: true
    )
    let destinationJournalURL = stagingContainer.appendingPathComponent(Self.journalFileName)
    try fileManager.createDirectory(at: stagingRoot, withIntermediateDirectories: true)

    journal.phase = .copying
    try atomicStore.write(journal, to: appContainerJournalURL)
    try atomicStore.write(journal, to: destinationJournalURL)

    var copiedBytes: Int64 = 0
    for entry in journal.inventory {
      let remainingBytes = journal.inventoryBytes - copiedBytes
      let available = try capacityProvider.availableCapacity(at: destinationParent)
      guard available >= remainingBytes + reserve else {
        throw CacheRootError.insufficientCapacity(
          required: remainingBytes + reserve,
          available: available
        )
      }

      let relativePath = try CacheRelativePath(entry.relativePath)
      let sourceURL = try containedURL(relativePath, below: sourceRoot)
      let destinationURL = try containedURL(relativePath, below: stagingRoot)
      try fileManager.createDirectory(
        at: destinationURL.deletingLastPathComponent(),
        withIntermediateDirectories: true
      )
      if fileManager.fileExists(atPath: destinationURL.path),
         try fileMatchesInventory(destinationURL, entry: entry) {
        copiedBytes += entry.byteCount
        continue
      }
      try? fileManager.removeItem(at: destinationURL)
      let partialURL = destinationURL.deletingLastPathComponent().appendingPathComponent(
        ".\(destinationURL.lastPathComponent).\(journal.transactionID.uuidString).partial"
      )
      if fileManager.fileExists(atPath: partialURL.path) {
        if try fileMatchesInventory(partialURL, entry: entry) {
          guard Darwin.rename(partialURL.path, destinationURL.path) == 0 else {
            throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
          }
          copiedBytes += entry.byteCount
          continue
        }
        try fileManager.removeItem(at: partialURL)
      }
      try fileManager.copyItem(at: sourceURL, to: partialURL)
      let partialHandle = try FileHandle(forWritingTo: partialURL)
      try partialHandle.synchronize()
      try partialHandle.close()
      guard try fileMatchesInventory(partialURL, entry: entry) else {
        throw CacheRootError.inconsistentActivation
      }
      guard Darwin.rename(partialURL.path, destinationURL.path) == 0 else {
        throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
      }
      copiedBytes += entry.byteCount
    }

    journal.phase = .verifying
    try atomicStore.write(journal, to: appContainerJournalURL)
    try atomicStore.write(journal, to: destinationJournalURL)
    let copiedInventory = try inventoryBuilder.build(rootURL: stagingRoot)
    guard copiedInventory == journal.inventory else { throw CacheRootError.inconsistentActivation }

    let marker = CacheMarker(cacheID: journal.destinationCacheID)
    try atomicStore.write(marker, to: stagingRoot.appendingPathComponent(CacheMarker.fileName))
    journal.phase = .readyToActivate
    try atomicStore.write(journal, to: appContainerJournalURL)
    try atomicStore.write(journal, to: destinationJournalURL)

    try fileManager.moveItem(at: stagingRoot, to: finalRoot)
    let finalDestinationJournalURL = finalRoot.appendingPathComponent(Self.journalFileName)
    journal.phase = .activated
    try atomicStore.write(journal, to: finalDestinationJournalURL)
    let receipt = CacheActivationReceipt(
      transactionID: journal.transactionID,
      cacheID: journal.destinationCacheID,
      inventoryDigest: journal.inventoryDigest
    )
    try atomicStore.write(receipt, to: finalRoot.appendingPathComponent(Self.receiptFileName))

    try projectPreference(activationPreference)
    try atomicStore.write(
      receipt,
      to: appContainerJournalURL.deletingLastPathComponent()
        .appendingPathComponent(Self.receiptFileName)
    )
    try atomicStore.write(journal, to: appContainerJournalURL)
    try? fileManager.removeItem(at: stagingContainer)
    return finalRoot
  }

  private func containedURL(_ relativePath: CacheRelativePath, below rootURL: URL) throws -> URL {
    let standardizedRoot = rootURL.standardizedFileURL.resolvingSymlinksInPath()
    let rootPath = standardizedRoot.path.hasSuffix("/")
      ? standardizedRoot.path
      : standardizedRoot.path + "/"
    var result = standardizedRoot
    for component in relativePath.components {
      result.appendPathComponent(component, isDirectory: false)
      var statBuffer = stat()
      if lstat(result.path, &statBuffer) == 0,
         statBuffer.st_mode & S_IFMT == S_IFLNK {
        throw CacheRootError.pathEscapesRoot
      }
    }
    result = result.standardizedFileURL
    guard result.path.hasPrefix(rootPath) else { throw CacheRootError.pathEscapesRoot }
    return result
  }

  private func fileMatchesInventory(_ url: URL, entry: CacheInventoryEntry) throws -> Bool {
    let data = try Data(contentsOf: url, options: [.mappedIfSafe])
    guard Int64(data.count) == entry.byteCount else { return false }
    let digest = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    return digest == entry.sha256
  }
}
