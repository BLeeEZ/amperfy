import UIKit

class ArtistTableCell: BasicTableCell {
    
    @IBOutlet weak var artistLabel: UILabel!
    @IBOutlet weak var artworkImage: LibraryEntityImage!
    @IBOutlet weak var infoLabel: UILabel!
    
    static let rowHeight: CGFloat = 48.0 + margin.bottom + margin.top
    
    private var artist: Artist?
    private var rootView: UITableViewController?
    
    override func awakeFromNib() {
        super.awakeFromNib()
        let longPressGesture = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPressGesture))
        self.addGestureRecognizer(longPressGesture)
    }

    func display(artist: Artist, rootView: UITableViewController) {
        self.artist = artist
        self.rootView = rootView
        artistLabel.text = artist.name
        artworkImage.displayAndUpdate(entity: artist, via: appDelegate.artworkDownloadManager)
        var infoText = ""
        if artist.albumCount == 1 {
            infoText += "1 Album"
        } else {
            infoText += "\(artist.albumCount) Albums"
        }
        if artist.songCount == 1 {
            infoText += " \(CommonString.oneMiddleDot) 1 Song"
        } else if artist.songCount > 1 {
            infoText += " \(CommonString.oneMiddleDot) \(artist.songCount) Songs"
        }
        infoLabel.text = infoText
    }

    @objc func handleLongPressGesture(gesture: UILongPressGestureRecognizer) -> Void {
        if gesture.state == .began {
            displayMenu()
        }
    }
    
    func displayMenu() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
        guard let artist = artist, let rootView = rootView, rootView.presentingViewController == nil else { return }
        let detailVC = LibraryEntityDetailVC()
        detailVC.display(artist: artist, on: rootView)
        rootView.present(detailVC, animated: true)
    }

}
