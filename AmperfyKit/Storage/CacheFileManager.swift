//
//  CacheFileManager.swift
//  AmperfyKit
//
//  Created by Maximilian Bauer on 24.04.24.
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

import CryptoKit
import Darwin
import Foundation
import UniformTypeIdentifiers

// MARK: - MimeFileConverter

public class MimeFileConverter {
  static let filenameExtensionUnknown = "unknown"
  static let mimeTypeUnknown = "application/octet-stream"

  static let mimeTypes = [
    "ogg": "audio/ogg",
    "ogx": "application/ogg",
    "flac": "audio/x-flac", // the case "audio/flac" is already covered by UTType
  ]

  static let iOSIncompatibleMimeTypes = [
    "audio/x-ms-wma",
    mimeTypeUnknown,
  ]

  static let conversionNeededMimeTypes = [
    "audio/x-flac": "audio/flac",
    "audio/m4a": "audio/mp4",
  ]

  static func convertToValidMimeTypeWhenNeccessary(mimeType: String) -> String {
    let mimeTypeLowerCased = mimeType.lowercased()
    return Self.conversionNeededMimeTypes[mimeTypeLowerCased] ?? mimeTypeLowerCased
  }

  static func isMimeTypePlayableOniOS(mimeType: String) -> Bool {
    !iOSIncompatibleMimeTypes.contains(where: { $0 == mimeType.lowercased() })
  }

  static func getMIMEType(filenameExtension: String?) -> String? {
    guard let filenameExtension = filenameExtension?.lowercased(),
          filenameExtension != "raw"
    else { return nil }

    let mimeType = UTType(filenameExtension: filenameExtension)?.preferredMIMEType ??
      mimeTypes[filenameExtension] ??
      Self.mimeTypeUnknown
    return mimeType
  }

  static func getFilenameExtension(mimeType: String?) -> String {
    guard let mimeType = mimeType?.lowercased()
    else { return Self.filenameExtensionUnknown }

    let fileExt = UTType(mimeType: mimeType)?.preferredFilenameExtension ??
      mimeTypes.findKey(forValue: mimeType) ??
      Self.filenameExtensionUnknown
    return fileExt
  }
}

// MARK: - PreparedCacheFileCommit

public final class PreparedCacheFileCommit: @unchecked Sendable {
  public let receipt: CacheFileCommitReceipt
  public let recoverableFileURL: URL
  public let destinationURL: URL

  private let finishOperation: @Sendable () throws -> ()
  private let cancelOperation: @Sendable () throws -> ()

  init(
    receipt: CacheFileCommitReceipt,
    recoverableFileURL: URL,
    destinationURL: URL,
    finishOperation: @escaping @Sendable () throws -> (),
    cancelOperation: @escaping @Sendable () throws -> ()
  ) {
    self.receipt = receipt
    self.recoverableFileURL = recoverableFileURL
    self.destinationURL = destinationURL
    self.finishOperation = finishOperation
    self.cancelOperation = cancelOperation
  }

  /// Removes recovery evidence only after the caller has committed Core Data successfully.
  public func finishAfterCoreDataCommit() throws {
    try finishOperation()
  }

  /// Explicitly cancels retry state. It succeeds only while the original root lease is current.
  public func cancel() throws {
    try cancelOperation()
  }
}

// MARK: - CacheFileManager

final public class CacheFileManager: Sendable {
  public static var shared: CacheFileManager { CacheRootRuntime.shared.fileManager }

  private let rootRegistry: CacheRootRegistry
  private let backgroundStagingRoot: URL?
  private let backgroundStagingPolicy: BackgroundStagingPolicy
  private let atomicStore: DurableAtomicFileStore
  // Get the currently active cache root. External roots can only become visible through the
  // registry, which invalidates all leases from the previous generation.
  private var amperfyLibraryDirectory: URL? {
    try? rootRegistry.currentLease().rootURL
  }

  // Complete playable directory size
  nonisolated(unsafe) private var _completePlayableCacheSize: Int64 = 0
  private let _completePlayableCacheSizeLock = NSLock()
  nonisolated public var completePlayableCacheSize: Int64 {
    guard let lease = try? rootRegistry.currentLease() else { return 0 }
    return (try? lease.performAtCommitBoundary {
      _completePlayableCacheSizeLock.withLock { _completePlayableCacheSize }
    }) ?? 0
  }

  // Account playable directory size
  nonisolated(unsafe) private var _accountPlayableCacheSize = [AccountInfo: Int64]()
  private let _accountPlayableCacheSizeLock = NSLock()
  nonisolated public func getPlayableCacheSize(for accountInfo: AccountInfo) -> Int64 {
    guard let lease = try? rootRegistry.currentLease() else { return 0 }
    return (try? lease.performAtCommitBoundary {
      _accountPlayableCacheSizeLock.withLock { _accountPlayableCacheSize[accountInfo] ?? 0 }
    }) ?? 0
  }

  init(
    rootRegistry: CacheRootRegistry,
    backgroundStagingRoot: URL? = nil,
    backgroundStagingPolicy: BackgroundStagingPolicy = BackgroundStagingPolicy(),
    atomicStore: DurableAtomicFileStore = DurableAtomicFileStore()
  ) {
    self.rootRegistry = rootRegistry
    self.backgroundStagingRoot = backgroundStagingRoot
    self.backgroundStagingPolicy = backgroundStagingPolicy
    self.atomicStore = atomicStore
  }

  public func currentRootLease() throws -> CacheRootLease {
    try rootRegistry.currentLease()
  }

  /// Called only by the bootstrap authority after preference resolution and health checks.
  func rootDidActivate(using lease: CacheRootLease) throws {
    try lease.performAtCommitBoundary {
      let root = try lease.secureContainedURL(CacheRelativePath(".bootstrap-root"))
        .deletingLastPathComponent()
      try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
      try markItemAsExcludedFromBackup(at: root)
    }
    recalculatePlayableCacheSizes()
  }

  func rootDidBlock() {
    _accountPlayableCacheSizeLock.withLock { _accountPlayableCacheSize.removeAll() }
    _completePlayableCacheSizeLock.withLock { _completePlayableCacheSize = 0 }
  }

  public func recalculatePlayableCacheSizes() {
    guard let lease = try? currentRootLease() else { return }
    var completeCacheSize = Int64(0)
    let accounts = getAccounts(using: lease)
    for account in accounts {
      let accountCache = calculatePlayableCacheSize(for: account, using: lease)
      _accountPlayableCacheSizeLock.withLock {
        _accountPlayableCacheSize[account] = accountCache
      }
      completeCacheSize += accountCache
    }
    _completePlayableCacheSizeLock.withLock {
      _completePlayableCacheSize = completeCacheSize
    }
  }

  nonisolated public func moveItemToTempDirectoryWithUniqueName(at: URL) throws -> URL {
    // Get the URL to the app container's 'tmp' directory.
    var tmpFileURL = FileManager.default.temporaryDirectory
    tmpFileURL.appendPathComponent(UUID().uuidString, isDirectory: false)
    try FileManager.default.moveItem(at: at, to: tmpFileURL)
    return tmpFileURL
  }

  /// Stages a completed background download in the app container, writes a durable receipt, then
  /// copies it into the leased cache root using a verified temporary file and atomic rename. The
  /// recoverable app-container copy is retained until `finishAfterCoreDataCommit()` is called.
  public func prepareRecoverableFileCommit(
    sourceURL: URL,
    destinationURL: URL,
    accountInfo: AccountInfo,
    using lease: CacheRootLease
  ) throws
    -> PreparedCacheFileCommit {
    let stagingRoot = try resolvedBackgroundStagingRoot()
    try FileManager.default.createDirectory(at: stagingRoot, withIntermediateDirectories: true)
    try validateStagingCapacity(adding: getFileSize(url: sourceURL) ?? 0, at: stagingRoot)

    let transactionID = UUID()
    let transactionRoot = stagingRoot.appendingPathComponent(
      transactionID.uuidString,
      isDirectory: true
    )
    try FileManager.default.createDirectory(at: transactionRoot, withIntermediateDirectories: true)
    let recoverableURL = transactionRoot.appendingPathComponent("payload", isDirectory: false)
    let incomingURL = transactionRoot.appendingPathComponent("payload.incoming", isDirectory: false)
    let receiptURL = transactionRoot.appendingPathComponent("receipt.json", isDirectory: false)

    do {
      try FileManager.default.copyItem(at: sourceURL, to: incomingURL)
      try synchronizeFile(at: incomingURL)
      let sourceDigest = try sha256AndSize(of: sourceURL)
      let incomingDigest = try sha256AndSize(of: incomingURL)
      guard incomingDigest == sourceDigest else { throw CacheRootError.inconsistentActivation }
      guard Darwin.rename(incomingURL.path, recoverableURL.path) == 0 else {
        throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
      }

      let safeDestination = try ensureInsideRoot(destinationURL, lease: lease)
      let rootPrefix = lease.rootURL.path.hasSuffix("/")
        ? lease.rootURL.path
        : lease.rootURL.path + "/"
      let relativeDestination = try CacheRelativePath(
        String(safeDestination.path.dropFirst(rootPrefix.count))
      )
      var receipt = CacheFileCommitReceipt(
        transactionID: transactionID,
        relativeDestinationPath: relativeDestination.string,
        stagedFileName: recoverableURL.lastPathComponent,
        byteCount: sourceDigest.size,
        sha256: sourceDigest.sha256,
        phase: .staged
      )
      try atomicStore.write(receipt, to: receiptURL)
      try? FileManager.default.removeItem(at: sourceURL)

      try lease.performAtCommitBoundary {
        let finalDestination = try lease.secureContainedURL(relativeDestination)
        let parent = finalDestination.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)
        _ = try ensureInsideRoot(parent, lease: lease)
        let partialURL = parent.appendingPathComponent(
          ".\(finalDestination.lastPathComponent).\(transactionID.uuidString).partial"
        )
        try? FileManager.default.removeItem(at: partialURL)
        try FileManager.default.copyItem(at: recoverableURL, to: partialURL)
        try synchronizeFile(at: partialURL)
        guard try sha256AndSize(of: partialURL) == sourceDigest else {
          throw CacheRootError.inconsistentActivation
        }
        _ = try ensureInsideRoot(partialURL, lease: lease)
        guard Darwin.rename(partialURL.path, finalDestination.path) == 0 else {
          throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
        }
        try markItemAsExcludedFromBackup(at: finalDestination)
        updateCachedDirectorySize(
          itemUrl: finalDestination,
          isAdded: true,
          accountInfo: accountInfo,
          using: lease
        )
      }

      receipt.phase = .filesystemCommitted
      try atomicStore.write(receipt, to: receiptURL)
      return PreparedCacheFileCommit(
        receipt: receipt,
        recoverableFileURL: recoverableURL,
        destinationURL: safeDestination,
        finishOperation: {
          try FileManager.default.removeItem(at: transactionRoot)
        },
        cancelOperation: { [weak self] in
          guard let self else { throw CacheRootError.unavailable }
          try lease.performAtCommitBoundary {
            let destination = try lease.secureContainedURL(relativeDestination)
            if FileManager.default.fileExists(atPath: destination.path) {
              try self.removeItem(at: destination, accountInfo: accountInfo, using: lease)
            }
            try FileManager.default.removeItem(at: transactionRoot)
          }
        }
      )
    } catch {
      try? FileManager.default.removeItem(at: incomingURL)
      throw error
    }
  }

  private func resolvedBackgroundStagingRoot() throws -> URL {
    if let backgroundStagingRoot { return backgroundStagingRoot }
    let applicationSupport = try FileManager.default.url(
      for: .applicationSupportDirectory,
      in: .userDomainMask,
      appropriateFor: nil,
      create: true
    )
    let bundle = Bundle.main.bundleIdentifier ?? "Amperfy"
    return applicationSupport.appendingPathComponent(bundle, isDirectory: true)
      .appendingPathComponent("Cache Commit Staging", isDirectory: true)
  }

  private func validateStagingCapacity(adding bytes: Int64, at stagingRoot: URL) throws {
    var stagedBytes: Int64 = 0
    var oldestDate = Date()
    if let enumerator = FileManager.default.enumerator(
      at: stagingRoot,
      includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey, .isRegularFileKey]
    ) {
      while let url = enumerator.nextObject() as? URL {
        let values = try url.resourceValues(forKeys: [
          .fileSizeKey,
          .contentModificationDateKey,
          .isRegularFileKey,
        ])
        guard values.isRegularFile == true else { continue }
        stagedBytes += Int64(values.fileSize ?? 0)
        oldestDate = min(oldestDate, values.contentModificationDate ?? oldestDate)
      }
    }
    let available = try stagingRoot.resourceValues(forKeys: [
      .volumeAvailableCapacityForImportantUsageKey,
    ]).volumeAvailableCapacityForImportantUsage ?? 0
    guard backgroundStagingPolicy.permits(
      stagedBytes: stagedBytes + bytes,
      oldestItemAge: Date().timeIntervalSince(oldestDate),
      containerAvailableCapacity: available
    ) else { throw CacheRootError.stagingLimitExceeded }
  }

  private func sha256AndSize(of url: URL) throws -> (sha256: String, size: Int64) {
    let handle = try FileHandle(forReadingFrom: url)
    defer { try? handle.close() }
    var hasher = SHA256()
    var size: Int64 = 0
    while true {
      let data = try handle.read(upToCount: 1024 * 1024) ?? Data()
      guard !data.isEmpty else { break }
      hasher.update(data: data)
      size += Int64(data.count)
    }
    return (hasher.finalize().map { String(format: "%02x", $0) }.joined(), size)
  }

  private func synchronizeFile(at url: URL) throws {
    let handle = try FileHandle(forWritingTo: url)
    defer { try? handle.close() }
    try handle.synchronize()
  }

  public func moveExcludedFromBackupItem(at: URL, to: URL, accountInfo: AccountInfo) throws {
    let lease = try currentRootLease()
    try moveExcludedFromBackupItem(at: at, to: to, accountInfo: accountInfo, using: lease)
  }

  /// Moves a completed download only while `lease` is still the active root generation.
  public func moveExcludedFromBackupItem(
    at sourceURL: URL,
    to destinationURL: URL,
    accountInfo: AccountInfo,
    using lease: CacheRootLease
  ) throws {
    try lease.performAtCommitBoundary {
      let expectedDestination = try ensureInsideRoot(destinationURL, lease: lease)
      let subdirectory = expectedDestination.deletingLastPathComponent()
      try FileManager.default.createDirectory(
        at: subdirectory,
        withIntermediateDirectories: true
      )
      try markItemAsExcludedFromBackup(at: subdirectory)
      if FileManager.default.fileExists(atPath: expectedDestination.path) {
        try removeItem(at: expectedDestination, accountInfo: accountInfo, using: lease)
      }
      try FileManager.default.moveItem(at: sourceURL, to: expectedDestination)
      try markItemAsExcludedFromBackup(at: expectedDestination)
      updateCachedDirectorySize(
        itemUrl: expectedDestination,
        isAdded: true,
        accountInfo: accountInfo,
        using: lease
      )
    }
  }

  public func move(from: URL?, to: URL?) throws {
    guard let from, let to else { return }
    let lease = try currentRootLease()
    try lease.performAtCommitBoundary {
      let safeFrom = try ensureInsideRoot(from, lease: lease)
      let safeTo = try ensureInsideRoot(to, lease: lease)
      try FileManager.default.createDirectory(at: safeTo, withIntermediateDirectories: true)
      try markItemAsExcludedFromBackup(at: safeTo)
      let items = try contentsOfDirectory(url: safeFrom, using: lease)
      for file in items {
        let destinationFileURL = safeTo.appendingPathComponent(file.lastPathComponent)
        _ = try ensureInsideRoot(destinationFileURL, lease: lease)
        try FileManager.default.moveItem(at: file, to: destinationFileURL)
      }
      try markItemAsExcludedFromBackup(at: safeTo)
    }
  }

  @discardableResult
  public func createDirectoryIfNeeded(at url: URL) -> Bool {
    guard let lease = try? currentRootLease() else { return false }
    return (try? lease.performAtCommitBoundary {
      let safeURL = try ensureInsideRoot(url, lease: lease)
      guard !FileManager.default.fileExists(atPath: safeURL.path) else { return false }
      try FileManager.default.createDirectory(
        at: safeURL,
        withIntermediateDirectories: true,
        attributes: [:]
      )
      return true
    }) ?? false
  }

  nonisolated private func resetPlayableCacheSize(for accountInfo: AccountInfo) {
    var newCompleteSize = Int64(0)
    _accountPlayableCacheSizeLock.withLock {
      _accountPlayableCacheSize[accountInfo] = 0
      newCompleteSize = _accountPlayableCacheSize.reduce(0) { $0 + $1.value }
    }
    _completePlayableCacheSizeLock.withLock {
      _completePlayableCacheSize = newCompleteSize
    }
  }

  nonisolated private func playableCacheSize(
    addItemSize itemSize: Int64,
    to accountInfo: AccountInfo
  ) {
    _completePlayableCacheSizeLock.withLock {
      _completePlayableCacheSize += itemSize
    }
    _accountPlayableCacheSizeLock.withLock {
      _accountPlayableCacheSize[accountInfo] = (_accountPlayableCacheSize[accountInfo] ?? 0) +
        itemSize
    }
  }

  nonisolated private func playableCacheSize(
    subtractItemSize itemSize: Int64,
    to accountInfo: AccountInfo
  ) {
    _completePlayableCacheSizeLock.withLock {
      _completePlayableCacheSize -= itemSize
    }
    _accountPlayableCacheSizeLock.withLock {
      _accountPlayableCacheSize[accountInfo] = (_accountPlayableCacheSize[accountInfo] ?? 0) -
        itemSize
    }
  }

  private func isFileURLInsideDirectory(fileURL: URL, directoryURL: URL) -> Bool {
    let standardizedFileURL = fileURL.standardizedFileURL
    var standardizedDirectoryURL = directoryURL.standardizedFileURL

    // Ensure directory URL ends with a slash to prevent false positives
    if !standardizedDirectoryURL.path.hasSuffix("/") {
      standardizedDirectoryURL.appendPathComponent("")
    }

    return standardizedFileURL.path.hasPrefix(standardizedDirectoryURL.path)
  }

  public func removeItem(at itemUrl: URL, accountInfo: AccountInfo) throws {
    let lease = try currentRootLease()
    try removeItem(at: itemUrl, accountInfo: accountInfo, using: lease)
  }

  private func removeItem(
    at itemURL: URL,
    accountInfo: AccountInfo,
    using lease: CacheRootLease
  ) throws {
    try lease.performAtCommitBoundary {
      let safeURL = try ensureInsideRoot(itemURL, lease: lease)
      updateCachedDirectorySize(
        itemUrl: safeURL,
        isAdded: false,
        accountInfo: accountInfo,
        using: lease
      )
      try FileManager.default.removeItem(at: safeURL)
    }
  }

  private func updateCachedDirectorySize(
    itemUrl: URL,
    isAdded: Bool,
    accountInfo: AccountInfo,
    using lease: CacheRootLease
  ) {
    guard let absSongsDir = getOrCreateAbsoluteSongsDirectory(for: accountInfo, using: lease),
          let absEpisodesDir = getOrCreateAbsolutePodcastEpisodesDirectory(
            for: accountInfo,
            using: lease
          ),
          let itemSize = getFileSize(url: itemUrl),
          isFileURLInsideDirectory(fileURL: itemUrl, directoryURL: absSongsDir) ||
          isFileURLInsideDirectory(fileURL: itemUrl, directoryURL: absEpisodesDir)
    else { return }

    if isAdded {
      playableCacheSize(addItemSize: itemSize, to: accountInfo)
    } else {
      playableCacheSize(subtractItemSize: itemSize, to: accountInfo)
    }
  }

  private func getOrCreateSubDirectory(subDirectoryNames: [String]) -> URL? {
    guard let lease = try? currentRootLease() else { return nil }
    return getOrCreateSubDirectory(subDirectoryNames: subDirectoryNames, using: lease)
  }

  private func getOrCreateSubDirectory(
    subDirectoryNames: [String],
    using lease: CacheRootLease
  )
    -> URL? {
    guard let relativePath = try? CacheRelativePath(subDirectoryNames.joined(separator: "/"))
    else { return nil }
    return try? lease.performAtCommitBoundary {
      let url = try lease.secureContainedURL(relativePath)
      if !FileManager.default.fileExists(atPath: url.path) {
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        try markItemAsExcludedFromBackup(at: url)
      }
      return try lease.secureContainedURL(relativePath)
    }
  }

  public func deleteAccountCache(accountInfo: AccountInfo) {
    guard let lease = try? currentRootLease(),
          let absAccountDir = getOrCreateAbsoluteAccountDirectory(for: accountInfo, using: lease)
    else { return }
    try? lease.performAtCommitBoundary {
      try FileManager.default.removeItem(at: try ensureInsideRoot(absAccountDir, lease: lease))
    }
  }

  public func deletePlayableCache(accountInfo: AccountInfo) {
    guard let lease = try? currentRootLease() else { return }
    try? lease.performAtCommitBoundary {
      let directories = [
        getOrCreateAbsoluteSongsDirectory(for: accountInfo, using: lease),
        getOrCreateAbsolutePodcastEpisodesDirectory(for: accountInfo, using: lease),
        getOrCreateAbsoluteEmbeddedArtworksDirectory(for: accountInfo, using: lease),
      ].compactMap { $0 }
      for directory in directories {
        try? FileManager.default.removeItem(at: try ensureInsideRoot(directory, lease: lease))
      }
      resetPlayableCacheSize(for: accountInfo)
    }
  }

  public func deleteRemoteArtworkCache(accountInfo: AccountInfo) {
    guard let lease = try? currentRootLease(),
          let absArtworksDir = getOrCreateAbsoluteArtworksDirectory(for: accountInfo, using: lease)
    else { return }
    try? lease.performAtCommitBoundary {
      try FileManager.default.removeItem(at: try ensureInsideRoot(absArtworksDir, lease: lease))
    }
  }

  private func calculatePlayableCacheSize(
    for accountInfo: AccountInfo,
    using lease: CacheRootLease
  )
    -> Int64 {
    (try? lease.performAtCommitBoundary {
      var bytes = Int64(0)
      if let absSongsDir = getOrCreateAbsoluteSongsDirectory(for: accountInfo, using: lease) {
        bytes += try directorySize(url: absSongsDir, using: lease)
      }
      if let absEpisodesDir = getOrCreateAbsolutePodcastEpisodesDirectory(
        for: accountInfo,
        using: lease
      ) {
        bytes += try directorySize(url: absEpisodesDir, using: lease)
      }
      return bytes
    }) ?? 0
  }

  private static let artworkFileExtension = "png"
  private static let lyricsFileExtension = "xml"
  private static let accountsDir = URL(string: "accounts")!
  private static let songsDir = URL(string: "songs")!
  private static let episodesDir = URL(string: "episodes")!
  private static let artworksDir = URL(string: "artworks")!
  private static let embeddedArtworksDir = URL(string: "embedded-artworks")!
  private static let lyricsDir = URL(string: "lyrics")!

  public func getOrCreateAbsoluteServerDirectory() -> URL? {
    getOrCreateSubDirectory(subDirectoryNames: [Self.accountsDir.path])
  }

  public func getOrCreateAbsoluteUserDirectory(server: String) -> URL? {
    getOrCreateSubDirectory(subDirectoryNames: [Self.accountsDir.path, server])
  }

  private func getRelAccountPaths(for account: AccountInfo, dirName: String?) -> [String] {
    if let dirName {
      return [Self.accountsDir.path, account.serverHash, account.userHash, dirName]
    } else {
      return [Self.accountsDir.path, account.serverHash, account.userHash]
    }
  }

  public func getOrCreateAbsoluteAccountDirectory(for account: AccountInfo) -> URL? {
    getOrCreateSubDirectory(subDirectoryNames: getRelAccountPaths(
      for: account,
      dirName: nil
    ))
  }

  private func getOrCreateAbsoluteAccountDirectory(
    for account: AccountInfo,
    using lease: CacheRootLease
  )
    -> URL? {
    getOrCreateSubDirectory(
      subDirectoryNames: getRelAccountPaths(for: account, dirName: nil),
      using: lease
    )
  }

  public func getRelPath(for account: AccountInfo) -> URL? {
    Self.accountsDir.appendingPathComponent(account.serverHash)
      .appendingPathComponent(account.userHash)
  }

  public func getOrCreateAbsoluteSongsDirectory(for account: AccountInfo) -> URL? {
    getOrCreateSubDirectory(subDirectoryNames: getRelAccountPaths(
      for: account,
      dirName: Self.songsDir.path
    ))
  }

  private func getOrCreateAbsoluteSongsDirectory(
    for account: AccountInfo,
    using lease: CacheRootLease
  )
    -> URL? {
    getOrCreateSubDirectory(
      subDirectoryNames: getRelAccountPaths(for: account, dirName: Self.songsDir.path),
      using: lease
    )
  }

  public func getRelSongsDirectory(for account: AccountInfo) -> URL? {
    getRelPath(for: account)?.appendingPathComponent(Self.songsDir.path)
  }

  public func getOrCreateAbsolutePodcastEpisodesDirectory(for account: AccountInfo) -> URL? {
    getOrCreateSubDirectory(subDirectoryNames: getRelAccountPaths(
      for: account,
      dirName: Self.episodesDir.path
    ))
  }

  private func getOrCreateAbsolutePodcastEpisodesDirectory(
    for account: AccountInfo,
    using lease: CacheRootLease
  )
    -> URL? {
    getOrCreateSubDirectory(
      subDirectoryNames: getRelAccountPaths(for: account, dirName: Self.episodesDir.path),
      using: lease
    )
  }

  public func getRelPodcastEpisodesDirectory(for account: AccountInfo) -> URL? {
    getRelPath(for: account)?.appendingPathComponent(Self.episodesDir.path)
  }

  public func getOrCreateAbsoluteArtworksDirectory(for account: AccountInfo) -> URL? {
    getOrCreateSubDirectory(subDirectoryNames: getRelAccountPaths(
      for: account,
      dirName: Self.artworksDir.path
    ))
  }

  private func getOrCreateAbsoluteArtworksDirectory(
    for account: AccountInfo,
    using lease: CacheRootLease
  )
    -> URL? {
    getOrCreateSubDirectory(
      subDirectoryNames: getRelAccountPaths(for: account, dirName: Self.artworksDir.path),
      using: lease
    )
  }

  public func getRelArtworkDirectory(for account: AccountInfo) -> URL? {
    getRelPath(for: account)?.appendingPathComponent(Self.artworksDir.path)
  }

  public func getOrCreateAbsoluteEmbeddedArtworksDirectory(for account: AccountInfo) -> URL? {
    getOrCreateSubDirectory(subDirectoryNames: getRelAccountPaths(
      for: account,
      dirName: Self.embeddedArtworksDir.path
    ))
  }

  private func getOrCreateAbsoluteEmbeddedArtworksDirectory(
    for account: AccountInfo,
    using lease: CacheRootLease
  )
    -> URL? {
    getOrCreateSubDirectory(
      subDirectoryNames: getRelAccountPaths(for: account, dirName: Self.embeddedArtworksDir.path),
      using: lease
    )
  }

  public func getRelEmbeddedArtworkDirectory(for account: AccountInfo) -> URL? {
    getRelPath(for: account)?.appendingPathComponent(Self.embeddedArtworksDir.path)
  }

  public func getOrCreateAbsoluteLyricsDirectory(for account: AccountInfo) -> URL? {
    getOrCreateSubDirectory(subDirectoryNames: getRelAccountPaths(
      for: account,
      dirName: Self.lyricsDir.path
    ))
  }

  public func getRelLyricsDirectory(for account: AccountInfo) -> URL? {
    getRelPath(for: account)?.appendingPathComponent(Self.lyricsDir.path)
  }

  public func getAccounts() -> [AccountInfo] {
    guard let lease = try? currentRootLease() else { return [] }
    return getAccounts(using: lease)
  }

  private func getAccounts(using lease: CacheRootLease) -> [AccountInfo] {
    var URLs = [URL]()
    var accountInfo = [AccountInfo]()
    var serverHashes = [String]()
    if let accountsDir = getOrCreateSubDirectory(
      subDirectoryNames: [Self.accountsDir.path],
      using: lease
    ) {
      URLs = (try? contentsOfDirectory(url: accountsDir, using: lease)) ?? []
    }
    // get all server hashes
    for url in URLs {
      let isDirectoryResourceValue: URLResourceValues
      do {
        isDirectoryResourceValue = try url.resourceValues(forKeys: [.isDirectoryKey])
      } catch {
        continue
      }
      guard isDirectoryResourceValue.isDirectory == true else {
        continue
      }
      serverHashes.append(url.lastPathComponent)
    }
    for serverHash in serverHashes {
      if let usersDir = getOrCreateSubDirectory(
        subDirectoryNames: [Self.accountsDir.path, serverHash],
        using: lease
      ) {
        URLs = (try? contentsOfDirectory(url: usersDir, using: lease)) ?? []
      }
      // get all users hashes for the server hashes
      for url in URLs {
        let isDirectoryResourceValue: URLResourceValues
        do {
          isDirectoryResourceValue = try url.resourceValues(forKeys: [.isDirectoryKey])
        } catch {
          continue
        }
        guard isDirectoryResourceValue.isDirectory == true else {
          continue
        }
        accountInfo.append(AccountInfo(
          serverHash: serverHash,
          userHash: url.lastPathComponent,
          apiType: .notDetected
        ))
      }
    }
    return accountInfo
  }

  public struct PlayableCacheInfo: Sendable {
    let url: URL
    let id: String
    let fileType: String
    let mimeType: String?
    let relFilePath: URL?
  }

  public func getCachedSongs(for account: AccountInfo) -> [PlayableCacheInfo] {
    var URLs = [URL]()
    var cacheInfo = [PlayableCacheInfo]()
    if let songsDir = getOrCreateAbsoluteSongsDirectory(for: account) {
      URLs = contentsOfDirectory(url: songsDir)
    }
    for url in URLs {
      let isDirectoryResourceValue: URLResourceValues
      do {
        isDirectoryResourceValue = try url.resourceValues(forKeys: [.isDirectoryKey])
      } catch {
        continue
      }
      guard isDirectoryResourceValue.isDirectory == nil || isDirectoryResourceValue
        .isDirectory == false else {
        continue
      }

      let fileName = url.lastPathComponent
      var id = fileName
      let pathExtension = url.pathExtension
      var mimeType: String?
      if !pathExtension.isEmpty {
        id = (fileName as NSString).deletingPathExtension
        mimeType = MimeFileConverter.getMIMEType(filenameExtension: pathExtension)
      }
      cacheInfo.append(PlayableCacheInfo(
        url: url,
        id: id,
        fileType: pathExtension,
        mimeType: mimeType,
        relFilePath: getRelSongsDirectory(for: account)?.appendingPathComponent(fileName)
      ))
    }
    return cacheInfo
  }

  public func getCachedEpisodes(for account: AccountInfo) -> [PlayableCacheInfo] {
    var URLs = [URL]()
    var cacheInfo = [PlayableCacheInfo]()
    if let episodesDir = getOrCreateAbsolutePodcastEpisodesDirectory(for: account) {
      URLs = contentsOfDirectory(url: episodesDir)
    }
    for url in URLs {
      let isDirectoryResourceValue: URLResourceValues
      do {
        isDirectoryResourceValue = try url.resourceValues(forKeys: [.isDirectoryKey])
      } catch {
        continue
      }
      guard isDirectoryResourceValue.isDirectory == nil || isDirectoryResourceValue
        .isDirectory == false else {
        continue
      }

      let fileName = url.lastPathComponent
      var id = fileName
      let pathExtension = url.pathExtension
      var mimeType: String?
      if !pathExtension.isEmpty {
        id = (fileName as NSString).deletingPathExtension
        mimeType = MimeFileConverter.getMIMEType(filenameExtension: pathExtension)
      }
      cacheInfo.append(PlayableCacheInfo(
        url: url,
        id: id,
        fileType: pathExtension,
        mimeType: mimeType,
        relFilePath: getRelPodcastEpisodesDirectory(for: account)?.appendingPathComponent(fileName)
      ))
    }
    return cacheInfo
  }

  public struct EmbeddedArtworkCacheInfo: Sendable {
    let url: URL
    let id: String
    let isSong: Bool
    let relFilePath: URL?
  }

  public func getCachedEmbeddedArtworks(for account: AccountInfo) -> [EmbeddedArtworkCacheInfo] {
    var cacheInfo = [EmbeddedArtworkCacheInfo]()
    if let embeddedArtworksDir = getOrCreateAbsoluteEmbeddedArtworksDirectory(for: account) {
      cacheInfo.append(contentsOf: getCachedEmbeddedArtworks(
        for: account,
        in: embeddedArtworksDir.appendingPathComponent(Self.songsDir.path),
        isSong: true
      ))
      cacheInfo.append(contentsOf: getCachedEmbeddedArtworks(
        for: account,
        in: embeddedArtworksDir.appendingPathComponent(Self.episodesDir.path),
        isSong: false
      ))
    }
    return cacheInfo
  }

  private func getCachedEmbeddedArtworks(
    for account: AccountInfo,
    in dir: URL,
    isSong: Bool
  )
    -> [EmbeddedArtworkCacheInfo] {
    let URLs = contentsOfDirectory(url: dir)
    var cacheInfo = [EmbeddedArtworkCacheInfo]()
    for url in URLs {
      let isDirectoryResourceValue: URLResourceValues
      do {
        isDirectoryResourceValue = try url.resourceValues(forKeys: [.isDirectoryKey])
      } catch {
        continue
      }

      guard isDirectoryResourceValue.isDirectory == nil || isDirectoryResourceValue
        .isDirectory == false else {
        continue
      }

      let fileName = url.lastPathComponent
      var id = fileName
      let pathExtension = url.pathExtension
      if !pathExtension.isEmpty {
        id = (fileName as NSString).deletingPathExtension
      }
      let relFilePath = isSong ?
        getRelEmbeddedArtworkDirectory(for: account)!.appendingPathComponent(Self.songsDir.path)
        .appendingPathComponent(fileName) :
        getRelEmbeddedArtworkDirectory(for: account)!.appendingPathComponent(Self.episodesDir.path)
        .appendingPathComponent(fileName)
      cacheInfo.append(EmbeddedArtworkCacheInfo(
        url: url,
        id: id,
        isSong: isSong,
        relFilePath: relFilePath
      ))
    }
    return cacheInfo
  }

  public struct ArtworkCacheInfo: Sendable {
    let url: URL
    let id: String
    let type: String
    let relFilePath: URL?
  }

  public func getCachedArtworks(for account: AccountInfo) -> [ArtworkCacheInfo] {
    var cacheInfo = [ArtworkCacheInfo]()
    if let artworksDir = getOrCreateAbsoluteArtworksDirectory(for: account) {
      cacheInfo.append(contentsOf: getCachedArtworks(for: account, in: artworksDir, type: ""))
    }
    return cacheInfo
  }

  private func getCachedArtworks(
    for account: AccountInfo,
    in dir: URL,
    type: String
  )
    -> [ArtworkCacheInfo] {
    let URLs = contentsOfDirectory(url: dir)
    var cacheInfo = [ArtworkCacheInfo]()
    for url in URLs {
      let isDirectoryResourceValue: URLResourceValues
      do {
        isDirectoryResourceValue = try url.resourceValues(forKeys: [.isDirectoryKey])
      } catch {
        continue
      }

      if isDirectoryResourceValue.isDirectory == true {
        let newType = url.lastPathComponent
        cacheInfo.append(contentsOf: getCachedArtworks(for: account, in: url, type: newType))
      } else {
        let fileName = url.lastPathComponent
        var id = fileName
        let pathExtension = url.pathExtension
        if !pathExtension.isEmpty {
          id = (fileName as NSString).deletingPathExtension
        }
        let relFilePath = !type.isEmpty ?
          getRelArtworkDirectory(for: account)!.appendingPathComponent(type)
          .appendingPathComponent(fileName) :
          getRelArtworkDirectory(for: account)!.appendingPathComponent(fileName)
        cacheInfo.append(ArtworkCacheInfo(url: url, id: id, type: type, relFilePath: relFilePath))
      }
    }
    return cacheInfo
  }

  public struct LyricsCacheInfo: Sendable {
    let url: URL
    let id: String
    let isSong: Bool
    let relFilePath: URL?
  }

  public struct AccountCacheSnapshot: Sendable {
    let artworks: [ArtworkCacheInfo]
    let embeddedArtworks: [EmbeddedArtworkCacheInfo]
    let lyrics: [LyricsCacheInfo]
    let songs: [PlayableCacheInfo]
    let episodes: [PlayableCacheInfo]
  }

  public func accountCacheSnapshot(
    for account: AccountInfo,
    using lease: CacheRootLease
  ) throws
    -> AccountCacheSnapshot {
    try lease.performAtCommitBoundary {
      AccountCacheSnapshot(
        artworks: getCachedArtworks(for: account),
        embeddedArtworks: getCachedEmbeddedArtworks(for: account),
        lyrics: getCachedLyrics(for: account),
        songs: getCachedSongs(for: account),
        episodes: getCachedEpisodes(for: account)
      )
    }
  }

  public func getCachedLyrics(for account: AccountInfo) -> [LyricsCacheInfo] {
    var cacheInfo = [LyricsCacheInfo]()
    if let lyricsDir = getOrCreateAbsoluteLyricsDirectory(for: account) {
      cacheInfo.append(contentsOf: getCachedLyrics(
        for: account,
        in: lyricsDir.appendingPathComponent(Self.songsDir.path),
        isSong: true
      ))
      cacheInfo.append(contentsOf: getCachedLyrics(
        for: account,
        in: lyricsDir.appendingPathComponent(Self.episodesDir.path),
        isSong: false
      ))
    }
    return cacheInfo
  }

  private func getCachedLyrics(
    for account: AccountInfo,
    in dir: URL,
    isSong: Bool
  )
    -> [LyricsCacheInfo] {
    let URLs = contentsOfDirectory(url: dir)
    var cacheInfo = [LyricsCacheInfo]()
    for url in URLs {
      let isDirectoryResourceValue: URLResourceValues
      do {
        isDirectoryResourceValue = try url.resourceValues(forKeys: [.isDirectoryKey])
      } catch {
        continue
      }

      guard isDirectoryResourceValue.isDirectory == nil || isDirectoryResourceValue
        .isDirectory == false else {
        continue
      }

      let fileName = url.lastPathComponent
      var id = fileName
      let pathExtension = url.pathExtension
      if !pathExtension.isEmpty {
        id = (fileName as NSString).deletingPathExtension
      }
      let relFilePath = isSong ?
        getRelLyricsDirectory(for: account)?.appendingPathComponent(Self.songsDir.path)
        .appendingPathComponent(fileName) :
        getRelLyricsDirectory(for: account)?.appendingPathComponent(Self.episodesDir.path)
        .appendingPathComponent(fileName)
      cacheInfo.append(LyricsCacheInfo(url: url, id: id, isSong: isSong, relFilePath: relFilePath))
    }
    return cacheInfo
  }

  public func createRelPath(forLyricsOf song: Song) -> URL? {
    guard let ownerRelFilePath = createRelPath(for: song),
          let account = song.account
    else { return nil }
    var lyricsRelFilePath = ownerRelFilePath.deletingPathExtension()
      .appendingPathExtension(Self.lyricsFileExtension)
    let components = lyricsRelFilePath.standardized.pathComponents

    guard let directoryCount = getRelPath(for: account.info)?.standardized.pathComponents.count,
          components.count > directoryCount
    else { return nil }
    let trimmed = components.dropFirst(directoryCount)
    let newPath = NSString.path(withComponents: Array(trimmed))
    lyricsRelFilePath = URL(fileURLWithPath: newPath, isDirectory: false)

    return getRelLyricsDirectory(for: account.info)?.appendingPathComponent(lyricsRelFilePath.path)
  }

  public func createRelPath(for playable: AbstractPlayable) -> URL? {
    guard !playable.playableManagedObject.id.isEmpty,
          let account = playable.account else { return nil }

    let fileExtension: String = {
      if let mimeType = playable.contentTypeTranscoded {
        return MimeFileConverter.getFilenameExtension(mimeType: mimeType)
      } else if let mimeType = playable.contentType {
        return MimeFileConverter.getFilenameExtension(mimeType: mimeType)
      } else {
        return MimeFileConverter.filenameExtensionUnknown
      }
    }()

    if playable.isSong {
      return getRelSongsDirectory(for: account.info)?
        .appendingPathComponent(playable.playableManagedObject.id)
        .appendingPathExtension(fileExtension)
    } else {
      return getRelPodcastEpisodesDirectory(for: account.info)?
        .appendingPathComponent(playable.playableManagedObject.id)
        .appendingPathExtension(fileExtension)
    }
  }

  public func createRelPath(
    for artworkRemoteInfo: ArtworkRemoteInfo,
    account: AccountInfo
  )
    -> URL? {
    guard !artworkRemoteInfo.id.isEmpty else { return nil }
    if !artworkRemoteInfo.type.isEmpty {
      return getRelArtworkDirectory(for: account)?.appendingPathComponent(artworkRemoteInfo.type)
        .appendingPathComponent(artworkRemoteInfo.id)
        .appendingPathExtension(Self.artworkFileExtension)
    } else {
      return getRelArtworkDirectory(for: account)?.appendingPathComponent(artworkRemoteInfo.id)
        .appendingPathExtension(Self.artworkFileExtension)
    }
  }

  public func createRelPath(for embeddedArtwork: EmbeddedArtwork) -> URL? {
    guard let owner = embeddedArtwork.owner,
          let ownerRelFilePath = createRelPath(for: owner),
          let account = embeddedArtwork.account
    else { return nil }
    var embeddedArtworkOwnerRelFilePath = ownerRelFilePath.deletingPathExtension()
      .appendingPathExtension(Self.artworkFileExtension)
    let components = embeddedArtworkOwnerRelFilePath.standardized.pathComponents

    guard let directoryCount = getRelPath(for: account.info)?.standardized.pathComponents.count,
          components.count > directoryCount
    else { return nil }
    let trimmed = components.dropFirst(directoryCount)
    let newPath = NSString.path(withComponents: Array(trimmed))
    embeddedArtworkOwnerRelFilePath = URL(fileURLWithPath: newPath, isDirectory: false)

    return getRelEmbeddedArtworkDirectory(for: account.info)?
      .appendingPathComponent(embeddedArtworkOwnerRelFilePath.path)
  }

  public func getAmperfyPath() -> String? {
    amperfyLibraryDirectory?.path
  }

  public func getAbsoluteAmperfyPath(relFilePath: URL) -> URL? {
    guard let lease = try? currentRootLease() else { return nil }
    return try? lease.resolve(relativePath: relFilePath)
  }

  public func getAbsoluteAmperfyPath(
    relFilePath: URL,
    using lease: CacheRootLease
  ) throws
    -> URL {
    try lease.resolve(relativePath: relFilePath)
  }

  public func getAbsoluteAmperfyPath(
    relativePath: CacheRelativePath,
    using lease: CacheRootLease
  ) throws
    -> URL {
    try lease.resolve(relativePath: relativePath)
  }

  public func withCacheFile<T>(
    relativePath: URL,
    operation: (URL) throws -> T
  ) throws
    -> T {
    let lease = try currentRootLease()
    return try lease.performAtCommitBoundary {
      let absoluteURL = try lease.resolve(relativePath: relativePath)
      guard FileManager.default.fileExists(atPath: absoluteURL.path) else {
        throw CocoaError(.fileNoSuchFile)
      }
      return try operation(absoluteURL)
    }
  }

  public func readCacheData(at absoluteURL: URL) throws -> Data {
    let lease = try currentRootLease()
    return try lease.performAtCommitBoundary {
      let safeURL = try ensureInsideRoot(absoluteURL, lease: lease)
      return try Data(contentsOf: safeURL)
    }
  }

  public func copyCacheItem(at absoluteURL: URL, to destinationURL: URL) throws {
    let lease = try currentRootLease()
    try lease.performAtCommitBoundary {
      let safeURL = try ensureInsideRoot(absoluteURL, lease: lease)
      try FileManager.default.copyItem(at: safeURL, to: destinationURL)
    }
  }

  public func fileExits(relFilePath: URL) -> Bool {
    guard let lease = try? currentRootLease() else { return false }
    return (try? lease.performAtCommitBoundary {
      let absolutePath = try lease.resolve(relativePath: relFilePath)
      return FileManager.default.fileExists(atPath: absolutePath.path)
    }) ?? false
  }

  public func writeDataExcludedFromBackup(data: Data, to: URL, accountInfo: AccountInfo?) throws {
    let lease = try currentRootLease()
    try writeDataExcludedFromBackup(data: data, to: to, accountInfo: accountInfo, using: lease)
  }

  public func writeDataExcludedFromBackup(
    data: Data,
    to destinationURL: URL,
    accountInfo: AccountInfo?,
    using lease: CacheRootLease
  ) throws {
    try lease.performAtCommitBoundary {
      let expectedDestination = try ensureInsideRoot(destinationURL, lease: lease)
      let subdirectory = expectedDestination.deletingLastPathComponent()
      try FileManager.default.createDirectory(
        at: subdirectory,
        withIntermediateDirectories: true
      )
      try markItemAsExcludedFromBackup(at: subdirectory)
      try data.write(to: expectedDestination, options: [.atomic])
      try markItemAsExcludedFromBackup(at: expectedDestination)
      if let accountInfo {
        updateCachedDirectorySize(
          itemUrl: expectedDestination,
          isAdded: true,
          accountInfo: accountInfo,
          using: lease
        )
      }
    }
  }

  private func ensureInsideRoot(_ url: URL, lease: CacheRootLease) throws -> URL {
    let standardizedURL = url.standardizedFileURL
    let standardizedRoot = lease.rootURL.standardizedFileURL
    if standardizedURL.path == standardizedRoot.path {
      try lease.validateCurrent()
      return standardizedRoot.resolvingSymlinksInPath()
    }
    let rootPath = standardizedRoot.path.hasSuffix("/")
      ? standardizedRoot.path
      : standardizedRoot.path + "/"
    guard standardizedURL.path.hasPrefix(rootPath) else {
      throw CacheRootError.pathEscapesRoot
    }
    let relative = try CacheRelativePath(String(standardizedURL.path.dropFirst(rootPath.count)))
    return try lease.secureContainedURL(relative)
  }

  private func markItemAsExcludedFromBackup(at: URL) throws {
    var values = URLResourceValues()
    values.isExcludedFromBackup = true
    // Apply those values to the URL.
    var url = at
    try url.setResourceValues(values)
  }

  private func contentsOfDirectory(url: URL) -> [URL] {
    guard let lease = try? currentRootLease() else { return [] }
    return (try? contentsOfDirectory(url: url, using: lease)) ?? []
  }

  private func contentsOfDirectory(url: URL, using lease: CacheRootLease) throws -> [URL] {
    try lease.performAtCommitBoundary {
      let safeURL = try ensureInsideRoot(url, lease: lease)
      let contents = try FileManager.default.contentsOfDirectory(
        at: safeURL,
        includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey]
      )
      for item in contents {
        _ = try ensureInsideRoot(item, lease: lease)
      }
      return contents
    }
  }

  private func directorySize(url: URL, using lease: CacheRootLease) throws -> Int64 {
    let safeURL = try ensureInsideRoot(url, lease: lease)
    let contents = try FileManager.default.contentsOfDirectory(
      at: safeURL,
      includingPropertiesForKeys: [.fileSizeKey, .isDirectoryKey, .isSymbolicLinkKey]
    )

    var size: Int64 = 0

    for url in contents {
      let isDirectoryResourceValue: URLResourceValues
      do {
        _ = try ensureInsideRoot(url, lease: lease)
        isDirectoryResourceValue = try url.resourceValues(forKeys: [
          .isDirectoryKey,
          .isSymbolicLinkKey,
        ])
      } catch {
        throw error
      }

      guard isDirectoryResourceValue.isSymbolicLink != true else {
        throw CacheRootError.pathEscapesRoot
      }

      if isDirectoryResourceValue.isDirectory == true {
        size += try directorySize(url: url, using: lease)
      } else {
        if let fileSize = getFileSize(url: url) {
          size += fileSize
        }
      }
    }
    try lease.validateCurrent()
    return size
  }

  nonisolated public func getFileSize(url: URL) -> Int64? {
    guard let fileSizeResourceValue = try? url.resourceValues(forKeys: [.fileSizeKey]),
          let intSize = fileSizeResourceValue.fileSize
    else { return nil }
    return Int64(intSize)
  }

  /// maximum file size that is allowed to load directly into memory to avoid memory overflow
  public static let maxFileSizeToHandleDataInMemory = 50_000_000

  public func getFileDataIfNotToBig(
    url: URL?,
    maxFileSize: Int = maxFileSizeToHandleDataInMemory
  )
    -> Data? {
    guard let fileURL = url,
          let fileSize = getFileSize(url: fileURL),
          fileSize < maxFileSize
    else { return nil }
    return try? Data(contentsOf: fileURL)
  }
}
