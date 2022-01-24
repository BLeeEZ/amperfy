import UIKit
import AudioToolbox

class AlbumSongTableCell: SongTableCell {
    
    static let albumSongRowHeight: CGFloat = 55
    
    @IBOutlet weak var trackNumberLabel: UILabel!

    override func refresh() {
        guard let song = song else { return }
        trackNumberLabel.text = song.track > 0 ? "\(song.track)" : ""
        titleLabel.attributedText = NSMutableAttributedString(string: song.title, attributes: [NSAttributedString.Key.font: UIFont.systemFont(ofSize: 17)])
        artistLabel.text = song.creatorName

        if song.isCached {
            artistLabel.textColor = UIColor.defaultBlue
        } else {
            artistLabel.textColor = UIColor.secondaryLabelColor
        }
    }
    
}
