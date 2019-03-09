import UIKit

class ArtistTableCell: UITableViewCell {
    
    @IBOutlet weak var artistLabel: UILabel!
    @IBOutlet weak var artworkImage: UIImageView!
    
    static let rowHeight: CGFloat = 56.0
    
    override func awakeFromNib() {
        super.awakeFromNib()
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
    }
    
    func display(artist: Artist) {
        artistLabel.text = artist.name
        artworkImage.image = artist.image
    }

}
