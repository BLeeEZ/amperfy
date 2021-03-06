import UIKit

class AlbumTableCell: BasicTableCell {
    
    @IBOutlet weak var albumLabel: UILabel!
    @IBOutlet weak var artistLabel: UILabel!
    @IBOutlet weak var artworkImage: UIImageView!
    
    static let rowHeight: CGFloat = 48.0 + margin.bottom + margin.top
    
    func display(album: Album) {
        albumLabel.text = album.name
        artistLabel.text = album.artist?.name
        artworkImage.image = album.image
    }

}
