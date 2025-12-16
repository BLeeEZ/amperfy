//
//  DownloadProtocols.swift
//  AmperfyKit
//
//  Created by Maximilian Bauer on 21.07.21.
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

public typealias CompleteHandlerBlock = @Sendable () -> ()

// MARK: - DownloadRequest

public struct DownloadRequest: Hashable, Sendable {
  let objectID: NSManagedObjectID
  let id: String
  let title: String
  let info: DownloadElementInfo
}

// MARK: - DownloadManageable

public protocol DownloadManageable {
  @MainActor
  var urlSessionIdentifier: String? { get }
  func getBackgroundFetchCompletionHandler() async -> CompleteHandlerBlock?
  func setBackgroundFetchCompletionHandler(_ newValue: CompleteHandlerBlock?)
  @MainActor
  func download(object: Downloadable)
  @MainActor
  func download(objects: [Downloadable])
  @MainActor
  func removeFinishedDownload(for object: Downloadable)
  @MainActor
  func removeFinishedDownload(for objects: [Downloadable])
  func clearFinishedDownloads()
  func resetFailedDownloads()
  func cancelDownloads()
  func start()
  func stop()
}

// MARK: - DownloadManagerDelegate

public protocol DownloadManagerDelegate: Sendable {
  var requestPredicate: NSPredicate { get }
  var parallelDownloadsCount: Int { get }
  func prepareDownload(
    downloadInfo: DownloadElementInfo,
    storage: AsyncCoreDataAccessWrapper
  ) async throws -> URL
  func validateDownloadedData(fileURL: URL?, downloadURL: URL?) -> ResponseError?
  func completedDownload(
    downloadInfo: DownloadElementInfo,
    fileURL: URL,
    fileMimeType: String?,
    storage: AsyncCoreDataAccessWrapper
  ) async
  func failedDownload(downloadInfo: DownloadElementInfo, storage: AsyncCoreDataAccessWrapper) async
}

// MARK: - Downloadable

public protocol Downloadable: CustomEquatable {
  var objectID: NSManagedObjectID { get }
  var isCached: Bool { get }
  var displayString: String { get }
  var threadSafeInfo: DownloadElementInfo? { get }
}

extension Downloadable {
  public var uniqueID: String { objectID.uriRepresentation().absoluteString }
}
