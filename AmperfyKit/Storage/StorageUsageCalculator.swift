//
//  StorageUsageCalculator.swift
//  AmperfyKit
//
//  Created by David Masek on 22.08.26.
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

import Foundation

// MARK: - StorageUsage

public struct StorageUsage: Sendable {
  public struct AlbumUsage: Sendable, Identifiable, Hashable {
    public let id: String
    public let albumName: String
    public let artistName: String
    public let songCount: Int
    public let sizeInByte: Int64
  }

  public let songsSize: Int64
  public let episodesSize: Int64
  public let artworkSize: Int64
  public let embeddedArtworkSize: Int64
  public let lyricsSize: Int64
  /// size of the Core Data store, shared across all accounts
  public let databaseSize: Int64
  /// cached albums sorted by size descending
  public let albums: [AlbumUsage]

  public var cacheTotal: Int64 {
    songsSize + episodesSize + artworkSize + embeddedArtworkSize + lyricsSize
  }

  /// cacheTotal + databaseSize for this account. Does NOT include the app bundle itself
  /// or other accounts' caches, so it will read lower than the OS-reported app size.
  public var totalSize: Int64 {
    cacheTotal + databaseSize
  }
}

// MARK: - StorageUsageCalculator

public enum StorageUsageCalculator {
  @MainActor
  public static func calculate(
    storage: PersistentStorage,
    accountInfo: AccountInfo
  ) async throws
    -> StorageUsage {
    let accountObjectId = storage.main.library.getAccount(info: accountInfo).managedObject
      .objectID
    let databaseStoreURL = storage.databaseStoreURL
    let albumFilesInfos = try await storage.async.performAndGet { asyncCompanion in
      let accountAsync = asyncCompanion.library.getAccount(managedObjectId: accountObjectId)
      return asyncCompanion.library.getCachedSongsFileInfosGroupedByAlbum(for: accountAsync)
    }
    return await Task.detached(priority: .utility) {
      createUsage(
        accountInfo: accountInfo,
        databaseStoreURL: databaseStoreURL,
        albumFilesInfos: albumFilesInfos
      )
    }.value
  }

  private static func createUsage(
    accountInfo: AccountInfo,
    databaseStoreURL: URL?,
    albumFilesInfos: [LibraryStorage.CachedAlbumFilesInfo]
  )
    -> StorageUsage {
    let fileManager = CacheFileManager.shared
    let albums = albumFilesInfos.map { info in
      let sizeInByte = info.relFilePaths.reduce(Int64(0)) { size, relFilePath in
        guard let absFilePath = fileManager.getAbsoluteAmperfyPath(relFilePath: relFilePath)
        else { return size }
        return size + (fileManager.getFileSize(url: absFilePath) ?? 0)
      }
      return StorageUsage.AlbumUsage(
        id: info.albumId,
        albumName: info.albumName,
        artistName: info.artistName,
        songCount: info.songCount,
        sizeInByte: sizeInByte
      )
    }.sorted { $0.sizeInByte > $1.sizeInByte }

    let databaseSize = databaseStoreURL
      .map { PersistentStorage.getDatabaseSizeInByte(storeURL: $0) } ?? 0

    return StorageUsage(
      songsSize: fileManager.getSongsCacheSize(for: accountInfo),
      episodesSize: fileManager.getEpisodesCacheSize(for: accountInfo),
      artworkSize: fileManager.getArtworkCacheSize(for: accountInfo),
      embeddedArtworkSize: fileManager.getEmbeddedArtworkCacheSize(for: accountInfo),
      lyricsSize: fileManager.getLyricsCacheSize(for: accountInfo),
      databaseSize: databaseSize,
      albums: albums
    )
  }
}
