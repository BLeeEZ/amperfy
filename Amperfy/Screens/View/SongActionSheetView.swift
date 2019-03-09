import UIKit

class SongActionSheetView: UIView {

    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var artistLabel: UILabel!
    @IBOutlet weak var artworkImage: UIImageView!
    
    static let frameHeight: CGFloat = 92.0

    func display(song: Song) {
        titleLabel.text = song.title
        artistLabel.text = song.artist?.name
        artworkImage.image = song.image
    }

}
