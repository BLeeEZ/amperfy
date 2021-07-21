import UIKit
import CoreData

class LibraryEntityImage: RoundedImage {
    
    var entity: AbstractLibraryEntity?
    
    func display(entity: AbstractLibraryEntity) {
        self.entity = entity
        refresh()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        let appDelegate = (UIApplication.shared.delegate as! AppDelegate)
        NotificationCenter.default.addObserver(self, selector: #selector(contextDidSave(_:)), name: Notification.Name.NSManagedObjectContextObjectsDidChange, object: appDelegate.persistentStorage.context)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc func contextDidSave(_ notification: Notification) {
        if let refreshedObjects = notification.userInfo?[NSRefreshedObjectsKey] as? Set<NSManagedObject>, !refreshedObjects.isEmpty, let entity = entity {
            for obj in refreshedObjects {
                if let artMO = obj as? ArtworkMO {
                    let artw = Artwork(managedObject: artMO)
                    if artw.owners.contains(where: {$0.isEqual(entity)}) {
                        refresh()
                    }
                }
            }
        }
    }
    
    func displayAndUpdate(entity: AbstractLibraryEntity, via artworkDownloadManager: DownloadManageable) {
        display(entity: entity)
        if let artwork = entity.artwork {
            artworkDownloadManager.download(object: artwork)
        }
    }
    
    func refresh() {
        self.image = entity?.image
    }
    
}
