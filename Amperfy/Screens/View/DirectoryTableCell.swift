import UIKit
import CoreData

class DirectoryTableCell: BasicTableCell, UIArtworkUpdatable {
    
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
        let appDelegate = (UIApplication.shared.delegate as! AppDelegate)
        appDelegate.uiArtworkUpdater.add(directoryCell: self)
    }
    
    deinit {
        let appDelegate = (UIApplication.shared.delegate as! AppDelegate)
        appDelegate.uiArtworkUpdater.remove(directoryCell: self)
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
    
    internal func refresh() {
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
