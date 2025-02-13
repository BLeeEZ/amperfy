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

class PlayableDownloadDelegate: DownloadManagerDelegate {
  /// max file size of an error response from an API
  private static let maxFileSizeOfErrorResponse = 2_000

  private let backendApi: BackendApi
  private let artworkExtractor: EmbeddedArtworkExtractor
  private let networkMonitor: NetworkMonitorFacade

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
  func prepareDownload(download: Download) async throws -> URL {
    guard let playable = download.element as? AbstractPlayable
    else { throw DownloadError.fetchFailed }
    guard !playable.isCached else { throw DownloadError.alreadyDownloaded }
    guard networkMonitor.isConnectedToNetwork else { throw DownloadError.noConnectivity }
    return try await backendApi.generateUrl(forDownloadingPlayable: playable)
  }

  @MainActor
  func validateDownloadedData(download: Download) -> ResponseError? {
    guard let fileURL = download.fileURL else {
      return ResponseError(
        type: .api,
        message: "Invalid download",
        cleansedURL: download.url?.asCleansedURL(cleanser: backendApi)
      )
    }
    guard let data = CacheFileManager.shared.getFileDataIfNotToBig(
      url: fileURL,
      maxFileSize: Self.maxFileSizeOfErrorResponse
    ) else { return nil }
    return backendApi.checkForErrorResponse(response: APIDataResponse(
      data: data,
      url: download.url
    ))
  }

  @MainActor
  func completedDownload(download: Download, storage: PersistentStorage) async {
    guard let fileURL = download.fileURL,
          let playable = download.element as? AbstractPlayable,
          let url = download.url else {
      return
    }
    do {
      try await savePlayableDataAsync(
        playable: playable,
        downloadUrl: url,
        fileURL: fileURL,
        fileMimeType: download.mimeType,
        storage: storage
      )
      try await artworkExtractor.extractEmbeddedArtwork(storage: storage, playable: playable)
    } catch {
      // ignore errors
    }
  }

  /// save downloaded playable async to avoid memory overflow issues due to kept references
  @MainActor
  func savePlayableDataAsync(
    playable: AbstractPlayable,
    downloadUrl: URL,
    fileURL: URL,
    fileMimeType: String?,
    storage: PersistentStorage
  ) async throws {
    let playableObjectID = playable.objectID
    try await storage.async.perform { companion in
      guard let playableAsyncMO = companion.context
        .object(with: playableObjectID) as? AbstractPlayableMO else { return }
      let playableAsync = AbstractPlayable(managedObject: playableAsyncMO)
      playableAsync.contentTypeTranscoded = fileMimeType
      // transcoding info needs to available to generate a correct file extension
      guard let relFilePath = CacheFileManager.shared.createRelPath(for: playableAsync),
            let absFilePath = CacheFileManager.shared
            .getAbsoluteAmperfyPath(relFilePath: relFilePath)
      else { return }
      do {
        try CacheFileManager.shared.moveExcludedFromBackupItem(at: fileURL, to: absFilePath)
        playableAsync.relFilePath = relFilePath
      } catch {
        playableAsync.relFilePath = nil
      }
    }
  }

  @MainActor
  func failedDownload(download: Download, storage: PersistentStorage) {}
}
