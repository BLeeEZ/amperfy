import UIKit

class SongActionSheetView: UIView {

    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var artistLabel: UILabel!
    @IBOutlet weak var artworkImage: LibraryEntityImage!
    
    static let frameHeight: CGFloat = 60.0 + margin.top + margin.bottom
    static let margin = UIEdgeInsets(top: 15, left: 15, bottom: 15, right: 15)
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        self.layoutMargins = SongActionSheetView.margin
    }
    
    func display(song: Song) {
        titleLabel.text = song.title
        artistLabel.text = song.artist?.name
        artworkImage.displayAndUpdate(entity: song, via: (UIApplication.shared.delegate as! AppDelegate).artworkDownloadManager)
    }

}
