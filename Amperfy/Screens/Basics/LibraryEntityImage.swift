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
        if let entity = entity {
            Artwork.executeIf(entity: entity, hasBeenUpdatedIn: notification) {
                refresh()
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
