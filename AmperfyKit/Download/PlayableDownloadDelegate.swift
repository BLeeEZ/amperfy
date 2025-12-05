//
//  PlayableDownloadDelegate.swift
//  AmperfyKit
//
//  Created by Maximilian Bauer on 09.03.19.
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

import CoreData
import Foundation

final class PlayableDownloadDelegate: DownloadManagerDelegate {
  /// max file size of an error response from an API
  private static let maxFileSizeOfErrorResponse = 2_000

  private let backendApi: BackendApi
  private let artworkExtractor: EmbeddedArtworkExtractor
  private let networkMonitor: NetworkMonitorFacade
  private let fileManager = CacheFileManager.shared

  init(
    backendApi: BackendApi,
    artworkExtractor: EmbeddedArtworkExtractor,
    networkMonitor: NetworkMonitorFacade
  ) {
    self.backendApi = backendApi
    self.artworkExtractor = artworkExtractor
    self.networkMonitor = networkMonitor
  }

  var requestPredicate: NSPredicate {
    DownloadMO.onlyPlayablesPredicate
  }

  var parallelDownloadsCount: Int {
    4
  }

  @MainActor
  func prepareDownload(
    downloadInfo: DownloadElementInfo,
    storage: AsyncCoreDataAccessWrapper
  ) async throws
    -> URL {
    guard downloadInfo.type == .playable else { throw DownloadError.fetchFailed }
    guard networkMonitor.isConnectedToNetwork else { throw DownloadError.noConnectivity }

    let playableInfo = try await storage.performAndGet { asyncCompanion in
      let playable = AbstractPlayable(
        managedObject: asyncCompanion.context
          .object(with: downloadInfo.objectId) as! AbstractPlayableMO
      )
      return !playable.isCached ? playable.info : nil
    }
    guard let playableInfo else { throw DownloadError.alreadyDownloaded }
    return try await Task { @MainActor in
      return try await backendApi.generateUrl(forDownloadingPlayable: playableInfo)
    }.value
  }

  func validateDownloadedData(fileURL: URL?, downloadURL: URL?) -> ResponseError? {
    guard let fileURL else {
      return ResponseError(
        type: .api,
        message: "Invalid download",
        cleansedURL: downloadURL?.asCleansedURL(cleanser: backendApi),
        data: nil
      )
    }
    guard let data = fileManager.getFileDataIfNotToBig(
      url: fileURL,
      maxFileSize: Self.maxFileSizeOfErrorResponse
    ) else { return nil }
    return backendApi.checkForErrorResponse(response: APIDataResponse(
      data: data,
      url: downloadURL
    ))
  }

  func completedDownload(
    downloadInfo: DownloadElementInfo,
    fileURL: URL,
    fileMimeType: String?,
    storage: AsyncCoreDataAccessWrapper
  ) async {
    guard downloadInfo.type == .playable else { return }
    let playableInfo = try? await storage.performAndGet { asyncCompanion in
      let playable = AbstractPlayable(
        managedObject: asyncCompanion.context
          .object(with: downloadInfo.objectId) as! AbstractPlayableMO
      )
      return playable.info
    }
    guard let playableInfo else { return }

    do {
      try await savePlayableData(
        playableInfo: playableInfo,
        fileURL: fileURL,
        fileMimeType: fileMimeType,
        storage: storage
      )
      try await artworkExtractor.extractEmbeddedArtwork(
        playableInfo: playableInfo,
        storage: storage
      )
    } catch {
      // ignore errors
    }
  }

  func savePlayableData(
    playableInfo: AbstractPlayableInfo,
    fileURL: URL,
    fileMimeType: String?,
    storage: AsyncCoreDataAccessWrapper
  ) async throws {
    try await storage.perform { asyncCompanion in
      let playableAsync = AbstractPlayable(
        managedObject: asyncCompanion.context
          .object(with: playableInfo.objectID) as! AbstractPlayableMO
      )
      playableAsync.contentTypeTranscoded = fileMimeType
      // transcoding info needs to available to generate a correct file extension
      guard let relFilePath = CacheFileManager.shared.createRelPath(for: playableAsync),
            let absFilePath = CacheFileManager.shared
            .getAbsoluteAmperfyPath(relFilePath: relFilePath),
            let accountInfo = playableAsync.account?.info
      else { return }
      do {
        try CacheFileManager.shared.moveExcludedFromBackupItem(
          at: fileURL,
          to: absFilePath,
          accountInfo: accountInfo
        )
        playableAsync.relFilePath = relFilePath
      } catch {
        playableAsync.relFilePath = nil
      }
    }
  }

  func failedDownload(downloadInfo: DownloadElementInfo, storage: AsyncCoreDataAccessWrapper) {}
}
