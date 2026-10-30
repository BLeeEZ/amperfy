//
//  CacheRelocation.swift
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

// MARK: - CacheMoveProgress

public struct CacheMoveProgress: Sendable {
  public let message: String
  public let completedBytes: Int64
  public let totalBytes: Int64

  public init(message: String, completedBytes: Int64 = 0, totalBytes: Int64 = 0) {
    self.message = message
    self.completedBytes = completedBytes
    self.totalBytes = totalBytes
  }
}

// MARK: - CacheRelocationRecord

struct CacheRelocationRecord: Codable, Sendable {
  let id: UUID
  let source: URL
  let destination: URL
  let oldPreference: CacheLocationPreference
  let newPreference: CacheLocationPreference
  let cacheID: UUID
  let inventory: [CacheInventoryEntry]

  init(
    source: URL,
    destination: URL,
    oldPreference: CacheLocationPreference,
    newPreference: CacheLocationPreference,
    cacheID: UUID,
    inventory: [CacheInventoryEntry]
  ) {
    self.id = UUID()
    self.source = source
    self.destination = destination
    self.oldPreference = oldPreference
    self.newPreference = newPreference
    self.cacheID = cacheID
    self.inventory = inventory
  }

  var staging: URL {
    destination.deletingLastPathComponent().appendingPathComponent(".amperfy-move-\(id.uuidString)")
  }
}

// MARK: - CacheRelocationCopy

/// Filesystem half of a relocation. The caller owns security scopes and suspends cache
/// consumers. No existing destination containing payload is overwritten or adopted.
enum CacheRelocationCopy {
  static func copy(
    _ move: CacheRelocationRecord,
    progress: @Sendable (CacheMoveProgress) -> (),
    checkCancellation: @Sendable () throws -> ()
  ) throws {
    let fm = FileManager.default
    let total = move.inventory.reduce(Int64(0)) { $0 + $1.byteCount }
    let parent = move.destination.deletingLastPathComponent()
    try CacheCapacityPolicy().validate(
      available: VolumeImportantUsageCapacityProvider().availableCapacity(at: parent),
      inventoryBytes: total
    )
    if fm.fileExists(atPath: move.destination.path) {
      // An empty root previously created by Amperfy can be reused. Arbitrary
      // pre-existing folders and populated caches are never overwritten.
      if move.newPreference.mode == .external {
        _ = try DurableAtomicFileStore().read(
          CacheMarker.self,
          from: move.destination
            .appendingPathComponent(CacheMarker.fileName)
        )
      }
      guard try CacheInventoryBuilder().build(rootURL: move.destination).isEmpty
      else { throw CacheRootError.migrationRequired }
    }
    guard !fm.fileExists(atPath: move.staging.path)
    else { throw CacheRootError.inconsistentActivation }
    try fm.createDirectory(at: move.staging, withIntermediateDirectories: false)
    try DurableAtomicFileStore().write(
      CacheMarker(cacheID: move.cacheID),
      to: move.staging
        .appendingPathComponent(CacheMarker.fileName)
    )
    var copied: Int64 = 0
    for entry in move.inventory {
      try checkCancellation()
      let source = try contained(entry.relativePath, in: move.source)
      let destination = try contained(entry.relativePath, in: move.staging)
      try fm.createDirectory(
        at: destination.deletingLastPathComponent(),
        withIntermediateDirectories: true
      )
      let input = try FileHandle(forReadingFrom: source)
      defer { try? input.close() }
      guard fm.createFile(atPath: destination.path, contents: nil)
      else { throw CocoaError(.fileWriteUnknown) }
      let output = try FileHandle(forWritingTo: destination)
      defer { try? output.close() }
      var hash = SHA256()
      var size: Int64 = 0
      while let data = try input.read(upToCount: 1024 * 1024), !data.isEmpty {
        try checkCancellation()
        try output.write(contentsOf: data)
        hash.update(data: data)
        size += Int64(data.count)
        progress(CacheMoveProgress(
          message: "Moving downloaded files…",
          completedBytes: copied + size,
          totalBytes: total
        ))
      }
      try output.synchronize()
      let digest = hash.finalize().map { String(format: "%02x", $0) }.joined()
      guard size == entry.byteCount,
            digest == entry.sha256 else { throw CacheRootError.inconsistentActivation }
      copied += size
    }
    progress(CacheMoveProgress(
      message: "Verifying the new copy…",
      completedBytes: total,
      totalBytes: total
    ))
    guard try CacheInventoryBuilder().build(
      rootURL: move.staging,
      checkCancellation: checkCancellation
    ) == move.inventory else {
      throw CacheRootError.inconsistentActivation
    }
    try checkCancellation()
    if fm.fileExists(atPath: move.destination.path) {
      guard try CacheInventoryBuilder().build(rootURL: move.destination).isEmpty
      else { throw CacheRootError.migrationRequired }
      try fm.removeItem(at: move.destination)
    }
    try syncDirectories(move.staging)
    try fm.moveItem(at: move.staging, to: move.destination)
    try syncDirectory(parent)
  }

  static func finish(_ move: CacheRelocationRecord, committed: Bool) throws {
    let fm = FileManager.default
    if committed {
      // Cleanup removes only inventoried source files whose bytes still match. A
      // partial cleanup can be repeated; new/unrecognized files are always retained.
      guard fm.fileExists(atPath: move.destination.path) else { throw CacheRootError.unavailable }
      let marker = try DurableAtomicFileStore().read(
        CacheMarker.self,
        from: move.destination
          .appendingPathComponent(CacheMarker.fileName)
      )
      guard marker.cacheID == move.cacheID else { throw CacheRootError.markerMismatch }
      for entry in move.inventory {
        let source = try contained(entry.relativePath, in: move.source)
        guard fm.fileExists(atPath: source.path) else { continue }
        let destination = try contained(entry.relativePath, in: move.destination)
        guard try matches(source, entry), try matches(destination, entry) else {
          throw CacheRootError.inconsistentActivation
        }
        try fm.removeItem(at: source)
      }
      // Preserve the old root and its control files. Removing empty account directories
      // makes it usable again without deleting a user-selected folder or its siblings.
      try pruneEmptyDirectories(move.source)
    } else {
      for url in [move.staging, move.destination] where fm.fileExists(atPath: url.path) {
        let marker = try? DurableAtomicFileStore().read(
          CacheMarker.self,
          from: url
            .appendingPathComponent(
              CacheMarker
                .fileName
            )
        )
        guard marker?.cacheID == move.cacheID else {
          // An existing destination rejected before copying belongs to somebody else.
          if url == move.destination { continue }
          throw CacheRootError.markerMismatch
        }
        try fm.removeItem(at: url)
      }
    }
  }

  private static func syncDirectory(_ url: URL) throws {
    let descriptor = Darwin.open(url.path, O_RDONLY)
    guard descriptor >= 0 else { throw POSIXError(.EIO) }
    defer { Darwin.close(descriptor) }
    guard Darwin.fsync(descriptor) == 0 else { throw POSIXError(.EIO) }
  }

  private static func syncDirectories(_ root: URL) throws {
    for url in try FileManager.default.contentsOfDirectory(
      at: root,
      includingPropertiesForKeys: [
        .isDirectoryKey,
        .isSymbolicLinkKey,
      ]
    ) {
      let values = try url.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
      if values.isDirectory == true, values.isSymbolicLink != true { try syncDirectories(url) }
    }
    try syncDirectory(root)
  }

  private static func pruneEmptyDirectories(_ root: URL) throws {
    let fm = FileManager.default
    guard fm.fileExists(atPath: root.path) else { return }
    for url in try fm.contentsOfDirectory(
      at: root,
      includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey]
    ) {
      let values = try url.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
      guard values.isDirectory == true, values.isSymbolicLink != true else { continue }
      try pruneEmptyDirectories(url)
      if try fm.contentsOfDirectory(atPath: url.path).isEmpty { try fm.removeItem(at: url) }
    }
  }

  private static func matches(_ url: URL, _ entry: CacheInventoryEntry) throws -> Bool {
    let handle = try FileHandle(forReadingFrom: url)
    defer { try? handle.close() }
    var hash = SHA256()
    var bytes: Int64 = 0
    while let data = try handle.read(upToCount: 1024 * 1024), !data.isEmpty {
      hash.update(data: data)
      bytes += Int64(data.count)
    }
    return bytes == entry.byteCount && hash.finalize().map { String(format: "%02x", $0) }
      .joined() == entry.sha256
  }

  private static func contained(_ path: String, in root: URL) throws -> URL {
    let relative = try CacheRelativePath(path)
    var url = root.standardizedFileURL
    for component in relative.components {
      url.appendPathComponent(component)
      if let values = try? url.resourceValues(forKeys: [.isSymbolicLinkKey]),
         values.isSymbolicLink == true {
        throw CacheRootError.pathEscapesRoot
      }
    }
    return url
  }
}
