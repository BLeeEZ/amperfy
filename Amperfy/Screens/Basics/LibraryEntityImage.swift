import UIKit

class LibraryEntityImage: RoundedImage {
    
    let appDelegate: AppDelegate
    var entity: AbstractLibraryEntity?
    var backupImage: UIImage?

    required init?(coder: NSCoder) {
        appDelegate = (UIApplication.shared.delegate as! AppDelegate)
        super.init(coder: coder)
        appDelegate.notificationHandler.register(self, selector: #selector(self.downloadFinishedSuccessful(notification:)), name: .downloadFinishedSuccess, object: appDelegate.artworkDownloadManager)
        appDelegate.notificationHandler.register(self, selector: #selector(self.downloadFinishedSuccessful(notification:)), name: .downloadFinishedSuccess, object: appDelegate.playableDownloadManager)
    }
    
    deinit {
        appDelegate.notificationHandler.remove(self, name: .downloadFinishedSuccess, object: appDelegate.artworkDownloadManager)
    }
    
    func display(entity: AbstractLibraryEntity) {
        self.entity = entity
        self.backupImage = entity.defaultImage
        refresh()
    }

    func displayAndUpdate(entity: AbstractLibraryEntity) {
        display(entity: entity)
        if let artwork = entity.artwork {
            appDelegate.artworkDownloadManager.download(object: artwork)
        }
    }
    
    func display(image: UIImage) {
        self.backupImage = image
        self.entity = nil
        refresh()
    }
    
    func refresh() {
        self.image = entity?.image(setting: appDelegate.persistentStorage.settings.artworkDisplayStyle) ?? backupImage ?? UIImage.songArtwork
    }
    
    @objc private func downloadFinishedSuccessful(notification: Notification) {
        guard let downloadNotification = DownloadNotification.fromNotification(notification) else { return }
        if let playable = entity as? AbstractPlayable,
           playable.uniqueID == downloadNotification.id {
            refresh()
        }
        if let artwork = entity?.artwork,
           artwork.uniqueID == downloadNotification.id {
            refresh()
        }
    }
    
}
