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

class SubsonicArtworkDownloadDelegate: DownloadManagerDelegate {
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
  func prepareDownload(download: Download) async throws -> URL {
    guard let artwork = download.element as? Artwork else { throw DownloadError.fetchFailed }
    guard networkMonitor.isConnectedToNetwork else { throw DownloadError.noConnectivity }
    return try await subsonicServerApi.generateUrl(forArtworkId: artwork.id)
  }

  @MainActor
  func validateDownloadedData(download: Download) -> ResponseError? {
    guard let fileURL = download.fileURL else {
      return ResponseError(
        type: .api,
        message: "Invalid download",
        cleansedURL: download.url?.asCleansedURL(cleanser: subsonicServerApi),
        data: nil
      )
    }
    guard let data = fileManager.getFileDataIfNotToBig(
      url: fileURL,
      maxFileSize: Self.maxFileSizeOfErrorResponse
    ) else { return nil }
    return subsonicServerApi.checkForErrorResponse(response: APIDataResponse(
      data: data,
      url: download.url
    ))
  }

  @MainActor
  func completedDownload(download: Download, storage: PersistentStorage) async {
    guard download.fileURL != nil,
          let artwork = download.element as? Artwork else {
      return
    }
    storage.main.perform { companion in
      artwork.status = .CustomImage
      artwork.relFilePath = self.handleCustomImage(download: download, artwork: artwork)
    }
  }

  func handleCustomImage(download: Download, artwork: Artwork) -> URL? {
    guard let downloadPath = download.fileURL,
          let relFilePath = fileManager.createRelPath(for: artwork),
          let absFilePath = fileManager.getAbsoluteAmperfyPath(relFilePath: relFilePath)
    else { return nil }
    do {
      try fileManager.moveExcludedFromBackupItem(at: downloadPath, to: absFilePath)
      return relFilePath
    } catch {
      return nil
    }
  }

  @MainActor
  func failedDownload(download: Download, storage: PersistentStorage) {
    guard let artwork = download.element as? Artwork else {
      return
    }
    artwork.status = .FetchError
    storage.main.saveContext()
  }
}
