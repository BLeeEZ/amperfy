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
    "audio/ogg",
    "application/ogg",
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

// MARK: - CacheFileManager

final public class CacheFileManager: Sendable {
  public static let shared = CacheFileManager()

  // Get the URL to the app container's 'Library' directory.
  private let amperfyLibraryDirectory: URL?
  // Complete playable directory size
  nonisolated(unsafe) private var _completePlayableCacheSize: Int64 = 0
  private let _completePlayableCacheSizeLock = NSLock()
  nonisolated public var completePlayableCacheSize: Int64 {
    _completePlayableCacheSizeLock.withLock { _completePlayableCacheSize }
  }

  // Account playable directory size
  nonisolated(unsafe) private var _accountPlayableCacheSize = [AccountInfo: Int64]()
  private let _accountPlayableCacheSizeLock = NSLock()
  nonisolated public func getPlayableCacheSize(for accountInfo: AccountInfo) -> Int64 {
    var size = Int64(0)
    _accountPlayableCacheSizeLock.withLock { size = _accountPlayableCacheSize[accountInfo] ?? 0 }
    return size
  }

  init() {
    // the action to get Amperfy's library directory takes long -> save it in cache
    if let bundleIdentifier = Bundle.main.bundleIdentifier,
       // Get the URL to the app container's 'Library' directory.
       var url = try? FileManager.default.url(
         for: .libraryDirectory,
         in: .userDomainMask,
         appropriateFor: nil,
         create: true
       ) {
      // Append the bundle identifier to the retrieved URL.
      url.appendPathComponent(bundleIdentifier, isDirectory: true)
      self.amperfyLibraryDirectory = url
    } else {
      self.amperfyLibraryDirectory = nil
    }

    checkAmperfyDirectory()
    recalculatePlayableCacheSizes()
  }

  public func recalculatePlayableCacheSizes() {
    var completeCacheSize = Int64(0)
    let accounts = getAccounts()
    for account in accounts {
      let accountCache = calculatePlayableCacheSize(for: account)
      _accountPlayableCacheSizeLock.withLock {
        _accountPlayableCacheSize[account] = accountCache
      }
      completeCacheSize += accountCache
    }
    _completePlayableCacheSizeLock.withLock {
      _completePlayableCacheSize = completeCacheSize
    }
  }

  func checkAmperfyDirectory() {
    guard let amperfyLibraryDirectory else { return }
    if createDirectoryIfNeeded(at: amperfyLibraryDirectory) {
      try? markItemAsExcludedFromBackup(at: amperfyLibraryDirectory)
    }
  }

  nonisolated public func moveItemToTempDirectoryWithUniqueName(at: URL) throws -> URL {
    // Get the URL to the app container's 'tmp' directory.
    var tmpFileURL = FileManager.default.temporaryDirectory
    tmpFileURL.appendPathComponent(UUID().uuidString, isDirectory: false)
    try FileManager.default.moveItem(at: at, to: tmpFileURL)
    return tmpFileURL
  }

  public func moveExcludedFromBackupItem(at: URL, to: URL, accountInfo: AccountInfo) throws {
    let subDir = to.deletingLastPathComponent()
    if createDirectoryIfNeeded(at: subDir) {
      try? markItemAsExcludedFromBackup(at: subDir)
    }
    if FileManager.default.fileExists(atPath: to.path) {
      try? removeItem(at: to, accountInfo: accountInfo)
    }
    try FileManager.default.moveItem(at: at, to: to)
    try markItemAsExcludedFromBackup(at: to)

    updateCachedDirectorySize(itemUrl: to, isAdded: true, accountInfo: accountInfo)
  }

  public func move(from: URL?, to: URL?) throws {
    guard let from, let to else { return }
    if createDirectoryIfNeeded(at: to) {
      try? markItemAsExcludedFromBackup(at: to)
    }
    let items = contentsOfDirectory(url: from)
    for file in items {
      let destinationFileURL = to.appendingPathComponent(file.lastPathComponent)
      try FileManager.default.moveItem(at: file, to: destinationFileURL)
    }
    try markItemAsExcludedFromBackup(at: to)
  }

  @discardableResult
  public func createDirectoryIfNeeded(at url: URL) -> Bool {
    guard !FileManager.default.fileExists(atPath: url.path) else { return false }
    try? FileManager.default.createDirectory(
      at: url,
      withIntermediateDirectories: true,
      attributes: [:]
    )
    return true
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
    updateCachedDirectorySize(itemUrl: itemUrl, isAdded: false, accountInfo: accountInfo)
    try FileManager.default.removeItem(at: itemUrl)
  }

  private func updateCachedDirectorySize(itemUrl: URL, isAdded: Bool, accountInfo: AccountInfo) {
    guard let absSongsDir = getOrCreateAbsoluteSongsDirectory(for: accountInfo),
          let absEpisodesDir = getOrCreateAbsolutePodcastEpisodesDirectory(for: accountInfo),
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
    var url: URL? = amperfyLibraryDirectory
    for subDirName in subDirectoryNames {
      url = url?.appendingPathComponent(
        subDirName,
        isDirectory: true
      )
      guard let url else { continue }
      if createDirectoryIfNeeded(at: url) {
        try? markItemAsExcludedFromBackup(at: url)
      }
    }
    return url
  }

  public func deleteAccountCache(accountInfo: AccountInfo) {
    if let absAccountDir = getOrCreateAbsoluteAccountDirectory(for: accountInfo) {
      try? FileManager.default.removeItem(at: absAccountDir)
    }
  }

  public func deletePlayableCache(accountInfo: AccountInfo) {
    if let absSongsDir = getOrCreateAbsoluteSongsDirectory(for: accountInfo) {
      try? FileManager.default.removeItem(at: absSongsDir)
    }
    if let absEpisodesDir = getOrCreateAbsolutePodcastEpisodesDirectory(for: accountInfo) {
      try? FileManager.default.removeItem(at: absEpisodesDir)
    }
    if let absEmbeddedArtworksDir = getOrCreateAbsoluteEmbeddedArtworksDirectory(for: accountInfo) {
      try? FileManager.default.removeItem(at: absEmbeddedArtworksDir)
    }
    resetPlayableCacheSize(for: accountInfo)
  }

  public func deleteRemoteArtworkCache(accountInfo: AccountInfo) {
    if let absArtworksDir = getOrCreateAbsoluteArtworksDirectory(for: accountInfo) {
      try? FileManager.default.removeItem(at: absArtworksDir)
    }
  }

  private func calculatePlayableCacheSize(for accountInfo: AccountInfo) -> Int64 {
    var bytes = Int64(0)
    if let absSongsDir = getOrCreateAbsoluteSongsDirectory(for: accountInfo) {
      bytes += directorySize(url: absSongsDir)
    }
    if let absEpisodesDir = getOrCreateAbsolutePodcastEpisodesDirectory(for: accountInfo) {
      bytes += directorySize(url: absEpisodesDir)
    }
    return bytes
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

  public func getRelSongsDirectory(for account: AccountInfo) -> URL? {
    getRelPath(for: account)?.appendingPathComponent(Self.songsDir.path)
  }

  public func getOrCreateAbsolutePodcastEpisodesDirectory(for account: AccountInfo) -> URL? {
    getOrCreateSubDirectory(subDirectoryNames: getRelAccountPaths(
      for: account,
      dirName: Self.episodesDir.path
    ))
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

  public func getRelArtworkDirectory(for account: AccountInfo) -> URL? {
    getRelPath(for: account)?.appendingPathComponent(Self.artworksDir.path)
  }

  public func getOrCreateAbsoluteEmbeddedArtworksDirectory(for account: AccountInfo) -> URL? {
    getOrCreateSubDirectory(subDirectoryNames: getRelAccountPaths(
      for: account,
      dirName: Self.embeddedArtworksDir.path
    ))
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
    var URLs = [URL]()
    var accountInfo = [AccountInfo]()
    var serverHashes = [String]()
    if let accountsDir = getOrCreateAbsoluteServerDirectory() {
      URLs = contentsOfDirectory(url: accountsDir)
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
      if let usersDir = getOrCreateAbsoluteUserDirectory(server: serverHash) {
        URLs = contentsOfDirectory(url: usersDir)
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
    guard let amperfyDir = amperfyLibraryDirectory else { return nil }
    return amperfyDir.appendingPathComponent(relFilePath.path)
  }

  public func fileExits(relFilePath: URL) -> Bool {
    guard let absFilePath = amperfyLibraryDirectory?.appendingPathComponent(relFilePath.path)
    else { return false }
    return FileManager.default.fileExists(atPath: absFilePath.path)
  }

  public func writeDataExcludedFromBackup(data: Data, to: URL, accountInfo: AccountInfo?) throws {
    let subDir = to.deletingLastPathComponent()
    if createDirectoryIfNeeded(at: subDir) {
      try? markItemAsExcludedFromBackup(at: subDir)
    }
    try data.write(to: to, options: [.atomic])
    try markItemAsExcludedFromBackup(at: to)
    // account info is nil when written to Amperfy directory directly
    if let accountInfo {
      updateCachedDirectorySize(itemUrl: to, isAdded: true, accountInfo: accountInfo)
    }
  }

  private func markItemAsExcludedFromBackup(at: URL) throws {
    var values = URLResourceValues()
    values.isExcludedFromBackup = true
    // Apply those values to the URL.
    var url = at
    try url.setResourceValues(values)
  }

  private func contentsOfDirectory(url: URL) -> [URL] {
    let contents = try? FileManager.default.contentsOfDirectory(
      at: url,
      includingPropertiesForKeys: [.isDirectoryKey]
    )
    return contents ?? [URL]()
  }

  private func directorySize(url: URL) -> Int64 {
    let contents: [URL]
    do {
      contents = try FileManager.default.contentsOfDirectory(
        at: url,
        includingPropertiesForKeys: [.fileSizeKey, .isDirectoryKey]
      )
    } catch {
      return 0
    }

    var size: Int64 = 0

    for url in contents {
      let isDirectoryResourceValue: URLResourceValues
      do {
        isDirectoryResourceValue = try url.resourceValues(forKeys: [.isDirectoryKey])
      } catch {
        continue
      }

      if isDirectoryResourceValue.isDirectory == true {
        size += directorySize(url: url)
      } else {
        if let fileSize = getFileSize(url: url) {
          size += fileSize
        }
      }
    }
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
