import UIKit

class LibraryEntityImage: RoundedImage {
    
    let appDelegate: AppDelegate
    var entity: AbstractLibraryEntity?

    required init?(coder: NSCoder) {
        appDelegate = (UIApplication.shared.delegate as! AppDelegate)
        super.init(coder: coder)
        appDelegate.notificationHandler.register(self, selector: #selector(self.artworkDownloadFinishedSuccessful(notification:)), name: .downloadFinishedSuccess, object: appDelegate.artworkDownloadManager)
    }
    
    deinit {
        appDelegate.notificationHandler.remove(self, name: .downloadFinishedSuccess, object: appDelegate.artworkDownloadManager)
    }
    
    func display(entity: AbstractLibraryEntity) {
        self.entity = entity
        refresh()
    }

    func displayAndUpdate(entity: AbstractLibraryEntity) {
        display(entity: entity)
        if let artwork = entity.artwork {
            appDelegate.artworkDownloadManager.download(object: artwork)
        }
    }
    
    func refresh() {
        self.image = entity?.image ?? Artwork.defaultImage
    }
    
    @objc private func artworkDownloadFinishedSuccessful(notification: Notification) {
        if let downloadNotification = DownloadNotification.fromNotification(notification),
           let artwork = entity?.artwork,
           artwork.uniqueID == downloadNotification.id {
            refresh()
        }
    }
    
}
