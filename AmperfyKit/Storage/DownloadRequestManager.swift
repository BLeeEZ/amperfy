//
//  DownloadRequestManager.swift
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

// MARK: - DownloadTaskInfo

struct DownloadTaskInfo: Sendable {
  let request: DownloadRequest
  let url: URL
  var hasStarted = false
}

// MARK: - DownloadRequestManager

final class DownloadRequestManager: Sendable {
  private let storage: AsyncCoreDataAccessWrapper
  private let downloadDelegate: DownloadManagerDelegate

  init(storage: AsyncCoreDataAccessWrapper, downloadDelegate: DownloadManagerDelegate) {
    self.storage = storage
    self.downloadDelegate = downloadDelegate
  }

  func add(downloadInfo: DownloadElementInfo) async -> DownloadRequest? {
    let request = try? await storage.performAndGet { asyncCompanion -> DownloadRequest? in
      let asyncObject = Download.createDownloadableObject(
        inContext: asyncCompanion.context,
        info: downloadInfo
      )
      let download = self.addLowPrio(object: asyncObject, library: asyncCompanion.library)
      guard let download else { return nil }
      return DownloadRequest(
        objectID: download.managedObject.objectID,
        id: asyncObject.uniqueID,
        title: download.title,
        info: downloadInfo
      )
    }
    return request
  }

  func add(downloadInfos: [DownloadElementInfo]) async -> [DownloadRequest] {
    guard !downloadInfos.isEmpty else { return [] }
    return try! await storage.performAndGet { asyncCompanion in
      var asyncRequests = [DownloadRequest]()
      for downloadInfo in downloadInfos {
        let object = Download.createDownloadableObject(
          inContext: asyncCompanion.context,
          info: downloadInfo
        )
        let asyncDownload = self.addLowPrio(object: object, library: asyncCompanion.library)
        guard let asyncDownload else { continue }
        asyncRequests.append(DownloadRequest(
          objectID: asyncDownload.managedObject.objectID,
          id: object.uniqueID, title: asyncDownload.title, info: downloadInfo
        ))
      }
      return asyncRequests
    }
  }

  nonisolated private func addLowPrio(object: Downloadable, library: LibraryStorage) -> Download? {
    if let existingDownload = library.getDownload(id: object.uniqueID) {
      if existingDownload.errorDate != nil {
        existingDownload.reset()
        library.saveContext()
        return existingDownload
      }
      return nil
    }

    let newDownload = library.createDownload(id: object.uniqueID)
    newDownload.element = object
    library.saveContext()
    return newDownload
  }

  func removeFinishedDownload(for uniqueID: String) async {
    try? await storage.perform { asyncCompanion in
      guard let existingDownload = asyncCompanion.library.getDownload(id: uniqueID),
            existingDownload.finishDate != nil
      else { return }
      asyncCompanion.library.deleteDownload(existingDownload)
      asyncCompanion.saveContext()
    }
  }

  func removeFinishedDownload(for uniqueIDs: [String]) async {
    try? await storage.perform { asyncCompanion in
      for uniqueID in uniqueIDs {
        guard let existingDownload = asyncCompanion.library.getDownload(id: uniqueID),
              existingDownload.finishDate != nil
        else { continue }
        asyncCompanion.library.deleteDownload(existingDownload)
      }
      asyncCompanion.saveContext()
    }
  }

  func getRequestedDownloads() async -> [DownloadRequest] {
    let predicateFormat = downloadDelegate.requestPredicate.predicateFormat
    let requestedDownloads = try? await storage.performAndGet { asyncCompanion in
      let fetchRequest: NSFetchRequest<DownloadMO> = DownloadMO.creationDateSortedFetchRequest
      fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
        NSPredicate(format: predicateFormat),
        NSPredicate(format: "%K == nil", #keyPath(DownloadMO.finishDate)),
        NSPredicate(format: "%K == nil", #keyPath(DownloadMO.errorDate)),
        // ignore start date -> reset it after fetched
      ])
      let downloadsMO = try? asyncCompanion.context.fetch(fetchRequest)
      let downloadRequests = downloadsMO?.compactMap { downloadMo -> DownloadRequest? in
        let download = Download(managedObject: downloadMo)
        download.startDate = nil
        let id = download.id
        guard let element = download.element else { return nil }
        return DownloadRequest(
          objectID: downloadMo.objectID,
          id: id,
          title: download.title,
          info: DownloadElementInfo(objectId: element.objectID, type: download.baseType)
        )
      }
      asyncCompanion.saveContext()
      return downloadRequests
    }
    return requestedDownloads ?? []
  }

  func clearFinishedDownloads() async {
    let downloadPredicateFormat = downloadDelegate.requestPredicate.predicateFormat
    try? await storage.perform { asyncCompanion in
      let fetchRequest: NSFetchRequest<DownloadMO> = DownloadMO.creationDateSortedFetchRequest
      fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
        NSPredicate(format: downloadPredicateFormat),
        NSCompoundPredicate(orPredicateWithSubpredicates: [
          NSPredicate(format: "%K != nil", #keyPath(DownloadMO.finishDate)),
          NSPredicate(format: "%K != nil", #keyPath(DownloadMO.errorDate)),
        ]),
      ])
      let results = try? asyncCompanion.context.fetch(fetchRequest)
      let downloads = results?.compactMap { Download(managedObject: $0) }
      downloads?.forEach { asyncCompanion.library.deleteDownload($0) }
      asyncCompanion.saveContext()
    }
  }

  func clearAllDownloadsAsyncIfAllHaveFinished() {
    Task {
      let downloadPredicateFormat = downloadDelegate.requestPredicate.predicateFormat
      let notStartedDownloadCount = try? await storage.performAndGet { asyncCompanion in
        let request: NSFetchRequest<DownloadMO> = DownloadMO.creationDateSortedFetchRequest
        request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
          NSPredicate(format: downloadPredicateFormat),
          NSPredicate(format: "%K == nil", #keyPath(DownloadMO.startDate)),
        ])
        return (try? asyncCompanion.context.count(for: request)) ?? 0
      }

      if notStartedDownloadCount == 0 {
        await clearAllDownloads()
      }
    }
  }

  func clearAllDownloads() async {
    let downloadPredicateFormat = downloadDelegate.requestPredicate.predicateFormat
    try? await storage.perform { asyncCompanion in
      let fetchRequest: NSFetchRequest<DownloadMO> = DownloadMO.creationDateSortedFetchRequest
      fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
        NSPredicate(format: downloadPredicateFormat),
      ])
      let results = try? asyncCompanion.context.fetch(fetchRequest)
      let downloads = results?.compactMap { Download(managedObject: $0) }
      downloads?.forEach { asyncCompanion.library.deleteDownload($0) }
      asyncCompanion.saveContext()
    }
  }

  func cancelDownloads() async {
    let downloadPredicateFormat = downloadDelegate.requestPredicate.predicateFormat
    try? await storage.perform { asyncCompanion in
      let fetchRequest: NSFetchRequest<DownloadMO> = DownloadMO.creationDateSortedFetchRequest
      fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
        NSPredicate(format: downloadPredicateFormat),
        NSPredicate(format: "%K == nil", #keyPath(DownloadMO.finishDate)),
        NSPredicate(format: "%K == nil", #keyPath(DownloadMO.errorDate)),
      ])
      let results = try? asyncCompanion.context.fetch(fetchRequest)
      let downloads = results?.compactMap { Download(managedObject: $0) }
      downloads?.forEach { $0.isCanceled = true }
      asyncCompanion.saveContext()
    }
  }

  func getAndResetFailedDownloads() async -> [DownloadRequest] {
    let predicateFormat = downloadDelegate.requestPredicate.predicateFormat
    let failedDownloads = try? await storage.performAndGet { asyncCompanion in
      let fetchRequest: NSFetchRequest<DownloadMO> = DownloadMO.creationDateSortedFetchRequest
      fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
        NSPredicate(format: predicateFormat),
        NSPredicate(format: "%K != nil", #keyPath(DownloadMO.errorDate)),
      ])
      let downloadsMO = try? asyncCompanion.context.fetch(fetchRequest)
      let downloadRequests = downloadsMO?.compactMap { downloadMo -> DownloadRequest? in
        let download = Download(managedObject: downloadMo)
        let id = download.id
        download.reset()
        guard let element = download.element else { return nil }
        return DownloadRequest(
          objectID: downloadMo.objectID,
          id: id,
          title: download.title,
          info: DownloadElementInfo(objectId: element.objectID, type: download.baseType)
        )
      }
      return downloadRequests
    }
    return failedDownloads ?? []
  }
}
