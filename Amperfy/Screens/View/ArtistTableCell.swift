import UIKit

class ArtistTableCell: BasicTableCell {
    
    @IBOutlet weak var artistLabel: UILabel!
    @IBOutlet weak var artworkImage: UIImageView!
    
    static let rowHeight: CGFloat = 48.0 + margin.bottom + margin.top
    
    func display(artist: Artist) {
        artistLabel.text = artist.name
        artworkImage.image = artist.image
    }

}
