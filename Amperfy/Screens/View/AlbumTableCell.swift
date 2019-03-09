import UIKit

class AlbumTableCell: UITableViewCell {
    
    @IBOutlet weak var albumLabel: UILabel!
    @IBOutlet weak var artistLabel: UILabel!
    @IBOutlet weak var artworkImage: UIImageView!
    
    static let rowHeight: CGFloat = 56.0
    
    override func awakeFromNib() {
        super.awakeFromNib()
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
    }
    
    func display(album: Album) {
        albumLabel.text = album.name
        artistLabel.text = album.artist?.name
        artworkImage.image = album.image
    }

}
