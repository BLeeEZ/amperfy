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

class DownloadRequestManager {

    private let persistentStorage: PersistentStorage
    private let downloadDelegate: DownloadManagerDelegate
    
    init(persistentStorage: PersistentStorage, downloadDelegate: DownloadManagerDelegate) {
        self.persistentStorage = persistentStorage
        self.downloadDelegate = downloadDelegate
    }
    
    func add(object: Downloadable) {
        persistentStorage.context.perform {
            let library = LibraryStorage(context: self.persistentStorage.context)
            self.addLowPrio(object: object, library: library)
            library.saveContext()
        }
    }
    
    func add(objects: [Downloadable]) {
        persistentStorage.persistentContainer.performBackgroundTask{ context in
            let library = LibraryStorage(context: context)
            for (n,object) in objects.enumerated() {
                self.addLowPrio(object: object, library: library)
                if (n % 500) == 0 {
                    library.saveContext()
                }
            }
            library.saveContext()
        }
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
        persistentStorage.context.performAndWait {
            let library = LibraryStorage(context: self.persistentStorage.context)
            guard let existingDownload = library.getDownload(id: object.uniqueID), existingDownload.finishDate != nil else { return }
            library.deleteDownload(existingDownload)
            library.saveContext()
        }
    }
    
    func removeFinishedDownload(for objects: [Downloadable]) {
        persistentStorage.context.performAndWait {
            let library = LibraryStorage(context: self.persistentStorage.context)
            for object in objects {
                guard let existingDownload = library.getDownload(id: object.uniqueID), existingDownload.finishDate != nil else { continue }
                library.deleteDownload(existingDownload)
            }
            library.saveContext()
        }
    }

    func getNextRequestToDownload() -> Download? {
        var nextDownload: Download?
        let context = self.persistentStorage.context
        context.performAndWait {
            let library = LibraryStorage(context: context)
            let fetchRequest: NSFetchRequest<DownloadMO> = DownloadMO.creationDateSortedFetchRequest
            fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
                NSPredicate(format: "%K == nil", #keyPath(DownloadMO.finishDate)),
                NSPredicate(format: "%K == nil", #keyPath(DownloadMO.errorDate)),
                NSPredicate(format: "%K == nil", #keyPath(DownloadMO.startDate)),
                self.downloadDelegate.requestPredicate
            ])
            fetchRequest.fetchLimit = 1
            let downloads = try? context.fetch(fetchRequest)
            nextDownload = downloads?.lazy.compactMap{ Download(managedObject: $0) }.first
            nextDownload?.isDownloading = true
            library.saveContext()
        }
        return nextDownload
    }
    
    func clearFinishedDownloads() {
        let library = LibraryStorage(context: persistentStorage.context)
        let fetchRequest: NSFetchRequest<DownloadMO> = DownloadMO.creationDateSortedFetchRequest
        fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
            self.downloadDelegate.requestPredicate,
            NSCompoundPredicate(orPredicateWithSubpredicates: [
                NSPredicate(format: "%K != nil", #keyPath(DownloadMO.finishDate)),
                NSPredicate(format: "%K != nil", #keyPath(DownloadMO.errorDate)),
            ])
        ])
        let results = try? persistentStorage.context.fetch(fetchRequest)
        let downloads = results?.compactMap{ Download(managedObject: $0)}
        downloads?.forEach{ library.deleteDownload($0) }
        library.saveContext()
    }
    
    var notStartedDownloadCount: Int {
        let request: NSFetchRequest<DownloadMO> = DownloadMO.creationDateSortedFetchRequest
        request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
            self.downloadDelegate.requestPredicate,
            NSPredicate(format: "%K == nil", #keyPath(DownloadMO.startDate)),
        ])
        return (try? persistentStorage.context.count(for: request)) ?? 0
    }
    
    func clearAllDownloadsIfAllHaveFinished() {
        if notStartedDownloadCount == 0 {
            clearAllDownloads()
        }
    }
    
    func clearAllDownloads() {
        let library = LibraryStorage(context: persistentStorage.context)
        let fetchRequest: NSFetchRequest<DownloadMO> = DownloadMO.creationDateSortedFetchRequest
        fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
            self.downloadDelegate.requestPredicate,
        ])
        let results = try? persistentStorage.context.fetch(fetchRequest)
        let downloads = results?.compactMap{ Download(managedObject: $0)}
        downloads?.forEach{ library.deleteDownload($0) }
        library.saveContext()
    }
    
    func resetStartedDownloads() {
        let library = LibraryStorage(context: persistentStorage.context)
        let fetchRequest: NSFetchRequest<DownloadMO> = DownloadMO.creationDateSortedFetchRequest
        fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
            NSPredicate(format: "%K == nil", #keyPath(DownloadMO.finishDate)),
            NSPredicate(format: "%K == nil", #keyPath(DownloadMO.errorDate)),
            NSPredicate(format: "%K != nil", #keyPath(DownloadMO.startDate)),
            self.downloadDelegate.requestPredicate
        ])
        let results = try? persistentStorage.context.fetch(fetchRequest)
        let downloads = results?.compactMap{ Download(managedObject: $0) }
        downloads?.forEach{ $0.startDate = nil }
        library.saveContext()
    }

    func cancelDownloads() {
        let library = LibraryStorage(context: persistentStorage.context)
        let fetchRequest: NSFetchRequest<DownloadMO> = DownloadMO.creationDateSortedFetchRequest
        fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
            NSPredicate(format: "%K == nil", #keyPath(DownloadMO.finishDate)),
            NSPredicate(format: "%K == nil", #keyPath(DownloadMO.errorDate)),
            self.downloadDelegate.requestPredicate
        ])
        let results = try? persistentStorage.context.fetch(fetchRequest)
        let downloads = results?.compactMap{ Download(managedObject: $0) }
        downloads?.forEach{ $0.isCanceled = true }
        library.saveContext()
    }
    
    func resetFailedDownloads() {
        let library = LibraryStorage(context: persistentStorage.context)
        let fetchRequest: NSFetchRequest<DownloadMO> = DownloadMO.creationDateSortedFetchRequest
        fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
            NSPredicate(format: "%K != nil", #keyPath(DownloadMO.errorDate)),
            self.downloadDelegate.requestPredicate
        ])
        let results = try? persistentStorage.context.fetch(fetchRequest)
        let downloads = results?.compactMap{ Download(managedObject: $0) }
        downloads?.forEach{ $0.reset() }
        library.saveContext()
    }

}
