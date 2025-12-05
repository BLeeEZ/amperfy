//
//  SubsonicArtworkDownloadDelegate.swift
//  AmperfyKit
//
//  Created by Maximilian Bauer on 09.06.21.
//  Copyright (c) 2021 Maximilian Bauer. All rights reserved.
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
import os.log
import UIKit

final class SubsonicArtworkDownloadDelegate: DownloadManagerDelegate {
  /// max file size of an error response from an API
  private static let maxFileSizeOfErrorResponse = 2_000

  private let subsonicServerApi: SubsonicServerApi
  private let networkMonitor: NetworkMonitorFacade
  private let fileManager = CacheFileManager.shared

  init(subsonicServerApi: SubsonicServerApi, networkMonitor: NetworkMonitorFacade) {
    self.subsonicServerApi = subsonicServerApi
    self.networkMonitor = networkMonitor
  }

  var requestPredicate: NSPredicate {
    DownloadMO.onlyArtworksPredicate
  }

  var parallelDownloadsCount: Int {
    2
  }

  @MainActor
  func prepareDownload(
    downloadInfo: DownloadElementInfo,
    storage: AsyncCoreDataAccessWrapper
  ) async throws
    -> URL {
    guard downloadInfo.type == .artwork else { throw DownloadError.fetchFailed }
    guard networkMonitor.isConnectedToNetwork else { throw DownloadError.noConnectivity }
    let artworkId = try await storage.performAndGet { asyncCompanion in
      let artwork = Artwork(
        managedObject: asyncCompanion.context
          .object(with: downloadInfo.objectId) as! ArtworkMO
      )
      return artwork.id
    }
    return try await subsonicServerApi.generateUrl(forArtworkId: artworkId)
  }

  func validateDownloadedData(fileURL: URL?, downloadURL: URL?) -> ResponseError? {
    guard let fileURL else {
      return ResponseError(
        type: .api,
        message: "Invalid download",
        cleansedURL: downloadURL?.asCleansedURL(cleanser: subsonicServerApi),
        data: nil
      )
    }
    guard let data = fileManager.getFileDataIfNotToBig(
      url: fileURL,
      maxFileSize: Self.maxFileSizeOfErrorResponse
    ) else { return nil }
    return subsonicServerApi.checkForErrorResponse(response: APIDataResponse(
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
    guard downloadInfo.type == .artwork else { return }
    let artworkRemoteInfo = try? await storage.performAndGet { asyncCompanion in
      let artwork = Artwork(
        managedObject: asyncCompanion.context
          .object(with: downloadInfo.objectId) as! ArtworkMO
      )
      return artwork.remoteInfo
    }
    guard let artworkRemoteInfo else { return }
    let relFilePath = handleCustomImage(fileURL: fileURL, artworkRemoteInfo: artworkRemoteInfo)
    try? await storage.perform { asyncCompanion in
      let artwork = Artwork(
        managedObject: asyncCompanion.context
          .object(with: downloadInfo.objectId) as! ArtworkMO
      )
      artwork.status = .CustomImage
      artwork.relFilePath = relFilePath
    }
  }

  func handleCustomImage(fileURL: URL, artworkRemoteInfo: ArtworkRemoteInfo) -> URL? {
    guard let account = subsonicServerApi.account,
          let relFilePath = fileManager.createRelPath(for: artworkRemoteInfo, account: account),
          let absFilePath = fileManager.getAbsoluteAmperfyPath(relFilePath: relFilePath)
    else { return nil }
    do {
      try fileManager.moveExcludedFromBackupItem(at: fileURL, to: absFilePath, accountInfo: account)
      return relFilePath
    } catch {
      return nil
    }
  }

  func failedDownload(
    downloadInfo: DownloadElementInfo,
    storage: AsyncCoreDataAccessWrapper
  ) async {
    guard downloadInfo.type == .artwork else { return }
    try? await storage.perform { asyncCompanion in
      let artwork = Artwork(
        managedObject: asyncCompanion.context
          .object(with: downloadInfo.objectId) as! ArtworkMO
      )
      artwork.markErrorIfNeeded()
      asyncCompanion.saveContext()
    }
  }
}
