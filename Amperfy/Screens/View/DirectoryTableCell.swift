import UIKit

class DirectoryTableCell: BasicTableCell {
    
    @IBOutlet weak var infoLabel: UILabel!
    @IBOutlet weak var artworkImage: RoundedImage!
    @IBOutlet weak var iconLabel: UILabel!
    
    static let rowHeight: CGFloat = 40.0 + margin.bottom + margin.top
    
    private var folder: MusicFolder?
    private var directory: Directory?
    
    func display(folder: MusicFolder) {
        self.folder = folder
        self.directory = nil
        refresh()
    }
    
    func display(directory: Directory) {
        self.folder = nil
        self.directory = directory
        if let artwork = directory.artwork {
            appDelegate.artworkDownloadManager.download(object: artwork, notifier: self)
        }
        refresh()
    }
    
    private func refresh() {
        iconLabel.isHidden = true
        artworkImage.isHidden = true
        
        if let directory = directory {
            infoLabel.text = directory.name
            if let artwork = directory.artwork, let directoryImage = artwork.image, directoryImage != Artwork.defaultImage {
                artworkImage.image = directoryImage
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

extension DirectoryTableCell: DownloadNotifiable {
    func finished(downloading: Downloadable, error: DownloadError?) {
        if error == nil {
            refresh()
        }
    }
}
