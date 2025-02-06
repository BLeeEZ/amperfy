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

import Foundation
import CoreData

public typealias CompleteHandlerBlock = () -> ()

public protocol DownloadManageable {
    var backgroundFetchCompletionHandler: CompleteHandlerBlock? { get set }
    @MainActor func download(object: Downloadable)
    @MainActor func download(objects: [Downloadable])
    @MainActor func removeFinishedDownload(for object: Downloadable)
    @MainActor func removeFinishedDownload(for objects: [Downloadable])
    func clearFinishedDownloads()
    func resetFailedDownloads()
    func cancelDownloads()
    func cancelPlayableDownloads()
    func start()
    func stop()
    func storageExceedsCacheLimit() -> Bool
}

public protocol DownloadManagerDelegate {
    var requestPredicate: NSPredicate { get }
    var parallelDownloadsCount: Int { get }
    @MainActor func prepareDownload(download: Download) async throws -> URL
    @MainActor func validateDownloadedData(download: Download) -> ResponseError?
    @MainActor func completedDownload(download: Download, storage: PersistentStorage) async
    @MainActor func failedDownload(download: Download, storage: PersistentStorage)
}

public protocol Downloadable: CustomEquatable {
    var objectID: NSManagedObjectID { get }
    var isCached: Bool { get }
    var displayString: String { get }
}

extension Downloadable {
    public var uniqueID: String { return objectID.uriRepresentation().absoluteString }
}
