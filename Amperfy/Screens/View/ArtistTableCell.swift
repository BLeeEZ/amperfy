import UIKit

class ArtistTableCell: BasicTableCell {
    
    @IBOutlet weak var artistLabel: UILabel!
    @IBOutlet weak var artworkImage: UIImageView!
    @IBOutlet weak var infoLabel: UILabel!
    
    static let rowHeight: CGFloat = 48.0 + margin.bottom + margin.top
    
    func display(artist: Artist) {
        artistLabel.text = artist.name
        artworkImage.image = artist.image
        var infoText = ""
        if artist.albumCount == 1 {
            infoText += "1 Album"
        } else {
            infoText += "\(artist.albumCount) Albums"
        }
        infoLabel.text = infoText
    }

}
