import Foundation
import CoreData

protocol UIArtworkUpdatable {
    var entity: AbstractLibraryEntity? { get }
    func refresh()
}

class UIArtworkUpdateManager {
    
    private let persistentStorage : PersistentStorage
    private var images: Set<LibraryEntityImage>
    private var directories: Set<DirectoryTableCell>
    
    init(persistentStorage: PersistentStorage) {
        self.persistentStorage = persistentStorage
        images = Set<LibraryEntityImage>()
        directories = Set<DirectoryTableCell>()
        NotificationCenter.default.addObserver(self, selector: #selector(contextDidSave(_:)), name: Notification.Name.NSManagedObjectContextObjectsDidChange, object: persistentStorage.context)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @objc func contextDidSave(_ notification: Notification) {
        let objKeys = [NSUpdatedObjectsKey, NSRefreshedObjectsKey]
        
        var elementRefreshable = [UIArtworkUpdatable]()
        elementRefreshable.append(contentsOf: images.filter{$0.entity != nil})
        elementRefreshable.append(contentsOf: directories.filter{$0.entity != nil})

        for objKey in objKeys {
            guard let refreshedObjects = notification.userInfo?[objKey] as? Set<NSManagedObject>, !refreshedObjects.isEmpty else { continue }
            let refreshedArtworks = refreshedObjects.lazy.compactMap{ $0 as? ArtworkMO }.compactMap{ Artwork(managedObject: $0) }
            for refreshedArtwork in refreshedArtworks {
                for elements in elementRefreshable {
                    if refreshedArtwork.owners.contains(where: {$0.isEqual(elements.entity!)}) {
                        elements.refresh()
                        break
                    }
                }
            }
        }
    }

    func add(image: LibraryEntityImage) {
        images.insert(image)
    }
    
    func remove(image: LibraryEntityImage) {
        images.remove(image)
    }
    
    func add(directoryCell: DirectoryTableCell) {
        directories.insert(directoryCell)
    }
    
    func remove(directoryCell: DirectoryTableCell) {
        directories.remove(directoryCell)
    }
    
}
