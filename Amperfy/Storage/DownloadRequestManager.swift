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
        persistentStorage.context.perform {
            let library = LibraryStorage(context: self.persistentStorage.context)
            for object in objects {
                self.addLowPrio(object: object, library: library)
            }
            library.saveContext()
        }
    }

    private func addLowPrio(object: Downloadable, library: LibraryStorage) {
        if library.getDownload(id: object.uniqueID) == nil {
            let download = library.createDownload()
            download.id = object.uniqueID
            download.element = object
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
        let downloads = results?.compactMap{ Download(managedObject: $0)}
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
        let downloads = results?.compactMap{ Download(managedObject: $0)}
        downloads?.forEach{ $0.isCanceled = true }
        library.saveContext()
    }

}
