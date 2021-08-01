import UIKit
import CoreData

class DirectoryTableCell: BasicTableCell {
    
    @IBOutlet weak var infoLabel: UILabel!
    @IBOutlet weak var artworkImage: LibraryEntityImage!
    @IBOutlet weak var iconLabel: UILabel!
    
    static let rowHeight: CGFloat = 40.0 + margin.bottom + margin.top
    
    private var folder: MusicFolder?
    private var directory: Directory?
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        let appDelegate = (UIApplication.shared.delegate as! AppDelegate)
        NotificationCenter.default.addObserver(self, selector: #selector(contextDidSave(_:)), name: Notification.Name.NSManagedObjectContextObjectsDidChange, object: appDelegate.persistentStorage.context)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc func contextDidSave(_ notification: Notification) {
        if let directory = directory {
            Artwork.executeIf(entity: directory, hasBeenUpdatedIn: notification) {
                refresh()
            }
        }
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
