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

import Foundation
import CoreData
import PromiseKit

class DownloadRequestManager {

    private let storage: PersistentStorage
    private let downloadDelegate: DownloadManagerDelegate
    
    init(storage: PersistentStorage, downloadDelegate: DownloadManagerDelegate) {
        self.storage = storage
        self.downloadDelegate = downloadDelegate
    }
    
    func add(object: Downloadable) {
        storage.main.context.perform {
            self.addLowPrio(object: object, library: self.storage.main.library)
            self.storage.main.saveContext()
        }
    }
    
    func add(objects: [Downloadable]) {
        firstly {
            storage.async.perform { asyncCompanion in
                for (n,object) in objects.enumerated() {
                    self.addLowPrio(object: object, library: asyncCompanion.library)
                    if (n % 500) == 0 {
                        asyncCompanion.saveContext()
                    }
                }
                asyncCompanion.saveContext()
            }
        }.catch { error in }
    }

    private func addLowPrio(object: Downloadable, library: LibraryStorage) {
        let existingDownload = library.getDownload(id: object.uniqueID)
        
        if existingDownload == nil {
            let download = library.createDownload()
            download.id = object.uniqueID
            download.element = object
        } else if let existingDownload = existingDownload, existingDownload.errorDate != nil {
            existingDownload.reset()
        }
    }
    
    func removeFinishedDownload(for object: Downloadable) {
        storage.main.context.performAndWait {
            guard let existingDownload = storage.main.library.getDownload(id: object.uniqueID), existingDownload.finishDate != nil else { return }
            storage.main.library.deleteDownload(existingDownload)
            storage.main.saveContext()
        }
    }
    
    func removeFinishedDownload(for objects: [Downloadable]) {
        storage.main.context.performAndWait {
            for object in objects {
                guard let existingDownload = storage.main.library.getDownload(id: object.uniqueID), existingDownload.finishDate != nil else { continue }
                storage.main.library.deleteDownload(existingDownload)
            }
            storage.main.saveContext()
        }
    }

    func getNextRequestToDownload() -> Download? {
        var nextDownload: Download?
        self.storage.main.context.performAndWait {
            let fetchRequest: NSFetchRequest<DownloadMO> = DownloadMO.creationDateSortedFetchRequest
            fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
                NSPredicate(format: "%K == nil", #keyPath(DownloadMO.finishDate)),
                NSPredicate(format: "%K == nil", #keyPath(DownloadMO.errorDate)),
                NSPredicate(format: "%K == nil", #keyPath(DownloadMO.startDate)),
                self.downloadDelegate.requestPredicate
            ])
            fetchRequest.fetchLimit = 1
            let downloads = try? self.storage.main.context.fetch(fetchRequest)
            nextDownload = downloads?.lazy.compactMap{ Download(managedObject: $0) }.first
            nextDownload?.isDownloading = true
            self.storage.main.saveContext()
        }
        return nextDownload
    }
    
    func clearFinishedDownloads() {
        let fetchRequest: NSFetchRequest<DownloadMO> = DownloadMO.creationDateSortedFetchRequest
        fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
            self.downloadDelegate.requestPredicate,
            NSCompoundPredicate(orPredicateWithSubpredicates: [
                NSPredicate(format: "%K != nil", #keyPath(DownloadMO.finishDate)),
                NSPredicate(format: "%K != nil", #keyPath(DownloadMO.errorDate)),
            ])
        ])
        let results = try? storage.main.context.fetch(fetchRequest)
        let downloads = results?.compactMap{ Download(managedObject: $0)}
        downloads?.forEach{ storage.main.library.deleteDownload($0) }
        storage.main.saveContext()
    }
    
    var notStartedDownloadCount: Int {
        let request: NSFetchRequest<DownloadMO> = DownloadMO.creationDateSortedFetchRequest
        request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
            self.downloadDelegate.requestPredicate,
            NSPredicate(format: "%K == nil", #keyPath(DownloadMO.startDate)),
        ])
        return (try? storage.main.context.count(for: request)) ?? 0
    }
    
    func clearAllDownloadsIfAllHaveFinished() {
        if notStartedDownloadCount == 0 {
            clearAllDownloads()
        }
    }
    
    func clearAllDownloads() {
        let fetchRequest: NSFetchRequest<DownloadMO> = DownloadMO.creationDateSortedFetchRequest
        fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
            self.downloadDelegate.requestPredicate,
        ])
        let results = try? storage.main.context.fetch(fetchRequest)
        let downloads = results?.compactMap{ Download(managedObject: $0)}
        downloads?.forEach{ storage.main.library.deleteDownload($0) }
        storage.main.saveContext()
    }
    
    func resetStartedDownloads() {
        let fetchRequest: NSFetchRequest<DownloadMO> = DownloadMO.creationDateSortedFetchRequest
        fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
            NSPredicate(format: "%K == nil", #keyPath(DownloadMO.finishDate)),
            NSPredicate(format: "%K == nil", #keyPath(DownloadMO.errorDate)),
            NSPredicate(format: "%K != nil", #keyPath(DownloadMO.startDate)),
            self.downloadDelegate.requestPredicate
        ])
        let results = try? storage.main.context.fetch(fetchRequest)
        let downloads = results?.compactMap{ Download(managedObject: $0) }
        downloads?.forEach{ $0.startDate = nil }
        storage.main.saveContext()
    }

    func cancelDownloads() {
        let fetchRequest: NSFetchRequest<DownloadMO> = DownloadMO.creationDateSortedFetchRequest
        fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
            NSPredicate(format: "%K == nil", #keyPath(DownloadMO.finishDate)),
            NSPredicate(format: "%K == nil", #keyPath(DownloadMO.errorDate)),
            self.downloadDelegate.requestPredicate
        ])
        let results = try? storage.main.context.fetch(fetchRequest)
        let downloads = results?.compactMap{ Download(managedObject: $0) }
        downloads?.forEach{ $0.isCanceled = true }
        storage.main.saveContext()
    }
    
    func cancelPlayablesDownloads() {
        let fetchRequest: NSFetchRequest<DownloadMO> = DownloadMO.creationDateSortedFetchRequest
        fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
            NSPredicate(format: "%K == nil", #keyPath(DownloadMO.finishDate)),
            NSPredicate(format: "%K == nil", #keyPath(DownloadMO.errorDate)),
            self.downloadDelegate.requestPredicate
        ])
        let results = try? storage.main.context.fetch(fetchRequest).filter({$0.playable != nil})
        let downloads = results?.compactMap{ Download(managedObject: $0) }
        downloads?.forEach{ $0.isCanceled = true }
        storage.main.saveContext()
    }
    
    func resetFailedDownloads() {
        let fetchRequest: NSFetchRequest<DownloadMO> = DownloadMO.creationDateSortedFetchRequest
        fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
            NSPredicate(format: "%K != nil", #keyPath(DownloadMO.errorDate)),
            self.downloadDelegate.requestPredicate
        ])
        let results = try? storage.main.context.fetch(fetchRequest)
        let downloads = results?.compactMap{ Download(managedObject: $0) }
        downloads?.forEach{ $0.reset() }
        storage.main.saveContext()
    }

}
