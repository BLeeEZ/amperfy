import UIKit

public class LibraryEntityImage: RoundedImage {
    
    let appDelegate: AmperKit
    var entity: AbstractLibraryEntity?
    var backupImage: UIImage?

    required public init?(coder: NSCoder) {
        appDelegate = AmperKit.shared
        super.init(coder: coder)
        appDelegate.notificationHandler.register(self, selector: #selector(self.downloadFinishedSuccessful(notification:)), name: .downloadFinishedSuccess, object: appDelegate.artworkDownloadManager)
        appDelegate.notificationHandler.register(self, selector: #selector(self.downloadFinishedSuccessful(notification:)), name: .downloadFinishedSuccess, object: appDelegate.playableDownloadManager)
    }
    
    deinit {
        appDelegate.notificationHandler.remove(self, name: .downloadFinishedSuccess, object: appDelegate.artworkDownloadManager)
    }
    
    public func display(entity: AbstractLibraryEntity) {
        self.entity = entity
        self.backupImage = entity.defaultImage
        refresh()
    }

    public func displayAndUpdate(entity: AbstractLibraryEntity) {
        display(entity: entity)
        if let artwork = entity.artwork {
            appDelegate.artworkDownloadManager.download(object: artwork)
        }
    }
    
    public func display(image: UIImage) {
        self.backupImage = image
        self.entity = nil
        refresh()
    }
    
    public func refresh() {
        self.image = entity?.image(setting: appDelegate.persistentStorage.settings.artworkDisplayPreference) ?? backupImage ?? UIImage.songArtwork
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
