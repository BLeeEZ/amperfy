import UIKit

class LibraryEntityImage: RoundedImage {
    
    var entity: AbstractLibraryEntity?
    
    func display(entity: AbstractLibraryEntity) {
        self.entity = entity
        refresh()
    }
    
    func displayAndUpdate(entity: AbstractLibraryEntity, via artworkDownloadManager: DownloadManageable) {
        display(entity: entity)
        if let artwork = entity.artwork {
            artworkDownloadManager.download(object: artwork, notifier: self, priority: .high)
        }
    }
    
    func refresh() {
        self.image = entity?.image
    }
    
}

extension LibraryEntityImage: DownloadNotifiable {
    func finished(downloading: Downloadable, error: DownloadError?) {
        guard error == nil else { return }
        refresh()
    }
}
