import UIKit
import CoreData

class DirectoryTableCell: BasicTableCell {
    
    @IBOutlet weak var infoLabel: UILabel!
    @IBOutlet weak var artworkImage: LibraryEntityImage!
    @IBOutlet weak var iconLabel: UILabel!
    
    static let rowHeight: CGFloat = 40.0 + margin.bottom + margin.top
    
    private var folder: MusicFolder?
    private var directory: Directory?
    var entity: AbstractLibraryEntity? {
        return directory
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        appDelegate.notificationHandler.register(self, selector: #selector(self.artworkDownloadFinishedSuccessful(notification:)), name: .downloadFinishedSuccess, object: appDelegate.artworkDownloadManager)
    }
    
    deinit {
        appDelegate.notificationHandler.remove(self, name: .downloadFinishedSuccess, object: appDelegate.artworkDownloadManager)
    }

    func display(folder: MusicFolder) {
        self.folder = folder
        self.directory = nil
        refresh()
    }
    
    func display(directory: Directory) {
        self.folder = nil
        self.directory = directory
        if let artwork = directory.artwork {
            appDelegate.artworkDownloadManager.download(object: artwork)
        }
        refresh()
    }
    
    @objc private func artworkDownloadFinishedSuccessful(notification: Notification) {
        if let downloadNotification = DownloadNotification.fromNotification(notification),
           let artwork = entity?.artwork,
           artwork.uniqueID == downloadNotification.id {
            refresh()
        }
    }
    
    private func refresh() {
        iconLabel.isHidden = true
        artworkImage.isHidden = true
        
        if let directory = directory {
            infoLabel.text = directory.name
            artworkImage.display(entity: directory)
            if let artwork = directory.artwork, let directoryImage = artwork.image, directoryImage != Artwork.defaultImage {
                artworkImage.isHidden = false
            } else {
                iconLabel.isHidden = false
            }
        } else if let folder = folder {
            infoLabel.text = folder.name
            iconLabel.isHidden = false
        }
    }

}
