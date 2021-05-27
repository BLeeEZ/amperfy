import UIKit

class DirectoryTableCell: BasicTableCell {
    
    @IBOutlet weak var infoLabel: UILabel!
    @IBOutlet weak var artworkImage: RoundedImage!
    @IBOutlet weak var iconLabel: UILabel!
    
    static let rowHeight: CGFloat = 40.0 + margin.bottom + margin.top
    
    func display(folder: MusicFolder) {
        iconLabel.isHidden = false
        artworkImage.isHidden = true
        
        infoLabel.text = folder.name
    }
    
    func display(directory: Directory) {
        iconLabel.isHidden = true
        artworkImage.isHidden = true
        
        infoLabel.text = directory.name
        if let artwork = directory.artwork, !artwork.url.isEmpty, let directoryImage = artwork.image, directoryImage != Artwork.defaultImage {
            artworkImage.image = directoryImage
            artworkImage.isHidden = false
        } else {
            iconLabel.isHidden = false
        }
    }

}
