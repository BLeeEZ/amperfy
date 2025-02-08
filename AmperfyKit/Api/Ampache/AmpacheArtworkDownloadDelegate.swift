//
//  AmpacheArtworkDownloadDelegate.swift
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

import Foundation
import CoreData
import UIKit

class AmpacheArtworkDownloadDelegate: DownloadManagerDelegate {
    
    /// max file size of an error response from an API
    private static let maxFileSizeOfErrorResponse = 2_000

    private let ampacheXmlServerApi: AmpacheXmlServerApi
    private let networkMonitor: NetworkMonitorFacade
    private var defaultImageData: Data?
    private let fileManager = CacheFileManager.shared

    init(ampacheXmlServerApi: AmpacheXmlServerApi, networkMonitor: NetworkMonitorFacade) {
        self.ampacheXmlServerApi = ampacheXmlServerApi
        self.networkMonitor = networkMonitor
    }
    
    var requestPredicate: NSPredicate {
        return DownloadMO.onlyArtworksPredicate
    }
    
    var parallelDownloadsCount: Int {
        return 2
    }

    @MainActor public func prepareDownload(download: Download) async throws -> URL {
        guard let artwork = download.element as? Artwork else {
            throw DownloadError.fetchFailed
        }
        guard networkMonitor.isConnectedToNetwork else { throw DownloadError.noConnectivity }
        return try await self.ampacheXmlServerApi.generateUrl(forArtwork: artwork)
    }
    
    @MainActor public func validateDownloadedData(download: Download) -> ResponseError? {
        guard let fileURL = download.fileURL else {
            return ResponseError(type: .api, message: "Invalid download", cleansedURL: download.url?.asCleansedURL(cleanser: ampacheXmlServerApi), data: nil)
        }
        guard let data = fileManager.getFileDataIfNotToBig(url: fileURL, maxFileSize: Self.maxFileSizeOfErrorResponse) else { return nil }
        return ampacheXmlServerApi.checkForErrorResponse(response: APIDataResponse(data: data, url: download.url))
    }

    @MainActor public func completedDownload(download: Download, storage: PersistentStorage) async {
        guard let fileURL = download.fileURL,
              let artwork = download.element as? Artwork else {
            return
        }
        do {
            let defaultImageData = try await self.requestDefaultImageData()
            if let artworkFileSize = self.fileManager.getFileSize(url: fileURL),
               artworkFileSize == defaultImageData.sizeInByte,
               let artworkData = self.fileManager.getFileDataIfNotToBig(url: fileURL),
               artworkData == defaultImageData {
                artwork.status = .IsDefaultImage
                artwork.relFilePath = nil
            } else {
                artwork.status = .CustomImage
                artwork.relFilePath = self.handleCustomImage(download: download, artwork: artwork)
            }
            storage.main.saveContext()
        } catch {
            artwork.status = .CustomImage
            artwork.relFilePath = self.handleCustomImage(download: download, artwork: artwork)
            storage.main.saveContext()
        }
    }
    
    func handleCustomImage(download: Download, artwork: Artwork) -> URL? {
        guard let downloadPath = download.fileURL,
              let relFilePath = self.fileManager.createRelPath(for: artwork),
              let absFilePath = self.fileManager.getAbsoluteAmperfyPath(relFilePath: relFilePath)
        else { return nil }
        do {
            try self.fileManager.moveExcludedFromBackupItem(at: downloadPath, to: absFilePath)
            return relFilePath
        } catch {
            return nil
        }
    }
    
    @MainActor public func failedDownload(download: Download, storage: PersistentStorage) {
        guard let artwork = download.element as? Artwork else {
            return
        }
        artwork.status = .FetchError
        storage.main.saveContext()
    }
    
    @MainActor private func requestDefaultImageData() async throws -> Data {
        if let defaultImageData = defaultImageData {
            return defaultImageData
        } else {
            let response = try await self.ampacheXmlServerApi.requestDefaultArtwork()
            self.defaultImageData = response.data
            return response.data
        }
    }
    
}
