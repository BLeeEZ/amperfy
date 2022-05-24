import UIKit
import AudioToolbox

class AlbumSongTableCell: SongTableCell {
    
    static let albumSongRowHeight: CGFloat = 55
    
    @IBOutlet weak var trackNumberLabel: UILabel!
    @IBOutlet weak var cacheIndicatorImage: UIImageView!
    @IBOutlet weak var artistLabelLeadConstraint: NSLayoutConstraint!
    
    override func refresh() {
        guard let song = song else { return }
        playIndicator.willDisplayIndicatorCB = { [weak self] () in
            guard let self = self else { return }
            self.trackNumberLabel.text = ""
        }
        playIndicator.willHideIndicatorCB = { [weak self] () in
            guard let self = self else { return }
            self.configureTrackNumberLabel()
        }
        playIndicator.display(playable: song, rootView: self.trackNumberLabel)
        titleLabel.attributedText = NSMutableAttributedString(string: song.title, attributes: [NSAttributedString.Key.font: UIFont.systemFont(ofSize: 17)])
        artistLabel.text = song.creatorName

        if song.isCached {
            cacheIndicatorImage.isHidden = false
            artistLabelLeadConstraint.constant = 20
        } else {
            cacheIndicatorImage.isHidden = true
            artistLabelLeadConstraint.constant = 0
        }
    }
    
    private func configureTrackNumberLabel() {
        guard let song = song else { return }
        trackNumberLabel.text = song.track > 0 ? "\(song.track)" : ""
    }
    
}
