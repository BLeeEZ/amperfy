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
  private let fileManager: CacheFileManager
  private let afterFilesystemCommitBeforeCoreDataSave: @Sendable () throws -> ()

  init(
    backendApi: BackendApi,
    artworkExtractor: EmbeddedArtworkExtractor,
    networkMonitor: NetworkMonitorFacade,
    fileManager: CacheFileManager = .shared,
    afterFilesystemCommitBeforeCoreDataSave: @escaping @Sendable () throws -> () = {}
  ) {
    self.backendApi = backendApi
    self.artworkExtractor = artworkExtractor
    self.networkMonitor = networkMonitor
    self.fileManager = fileManager
    self.afterFilesystemCommitBeforeCoreDataSave = afterFilesystemCommitBeforeCoreDataSave
  }

  var requestPredicate: NSPredicate {
    DownloadMO.onlyPlayablesPredicate
  }

  var parallelDownloadsCount: Int {
    4
  }

  var httpHeaders: [String: String] {
    backendApi.httpHeaders
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
    let rootLease = try fileManager.currentRootLease()
    let preparedCommit = try await storage.performWithCommitValidation { asyncCompanion in
      let playableAsync = AbstractPlayable(
        managedObject: asyncCompanion.context
          .object(with: playableInfo.objectID) as! AbstractPlayableMO
      )
      playableAsync.contentTypeTranscoded = fileMimeType
      // transcoding info needs to available to generate a correct file extension
      guard let relFilePath = self.fileManager.createRelPath(for: playableAsync),
            let accountInfo = playableAsync.account?.info
      else { throw CacheRootError.unavailable }
      let absFilePath = try self.fileManager.getAbsoluteAmperfyPath(
        relFilePath: relFilePath,
        using: rootLease
      )
      let transaction = try self.fileManager.prepareRecoverableFileCommit(
        sourceURL: fileURL,
        destinationURL: absFilePath,
        accountInfo: accountInfo,
        using: rootLease
      )
      try self.afterFilesystemCommitBeforeCoreDataSave()
      try rootLease.validateCurrent()
      playableAsync.relFilePath = relFilePath
      return transaction
    } validateBeforeSave: {
      try rootLease.validateCurrent()
    }
    try preparedCommit.finishAfterCoreDataCommit()
  }

  func failedDownload(downloadInfo: DownloadElementInfo, storage: AsyncCoreDataAccessWrapper) {}
}
