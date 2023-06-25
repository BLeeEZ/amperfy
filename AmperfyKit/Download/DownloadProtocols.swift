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
import PromiseKit

public typealias CompleteHandlerBlock = () -> ()

public protocol DownloadManageable {
    var backgroundFetchCompletionHandler: CompleteHandlerBlock? { get set }
    func download(object: Downloadable)
    func download(objects: [Downloadable])
    func removeFinishedDownload(for object: Downloadable)
    func removeFinishedDownload(for objects: [Downloadable])
    func clearFinishedDownloads()
    func resetFailedDownloads()
    func cancelDownloads()
    func cancelPlayableDownloads()
    func start()
    func stopAndWait()
    func storageExceedsCacheLimit() -> Bool
}

public protocol DownloadManagerDelegate {
    var requestPredicate: NSPredicate { get }
    var parallelDownloadsCount: Int { get }
    func prepareDownload(download: Download) -> Promise<URL>
    func validateDownloadedData(download: Download) -> ResponseError?
    func completedDownload(download: Download, storage: PersistentStorage) -> Guarantee<Void>
    func failedDownload(download: Download, storage: PersistentStorage)
}

public protocol Downloadable: CustomEquatable {
    var objectID: NSManagedObjectID { get }
    var isCached: Bool { get }
    var displayString: String { get }
}

extension Downloadable {
    public var uniqueID: String { return objectID.uriRepresentation().absoluteString }
}
