import UIKit

class ArtistDetailTableHeader: UIView {
    
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var artistImage: LibraryEntityImage!
    @IBOutlet weak var infoLabel: UILabel!
    
    static let frameHeight: CGFloat = 150.0 + margin.top + margin.bottom
    static let margin = UIView.defaultMarginTopElement
    
    private var artist: Artist?
    private var appDelegate: AppDelegate!
    private var rootView: ArtistDetailVC?
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        appDelegate = (UIApplication.shared.delegate as! AppDelegate)
        self.layoutMargins = Self.margin
    }
    
    func prepare(toWorkOnArtist artist: Artist?, rootView: ArtistDetailVC? ) {
        guard let artist = artist else { return }
        self.artist = artist
        self.rootView = rootView
        refresh()
    }
    
    func refresh() {
        guard let artist = artist else { return }
        nameLabel.text = artist.name
        nameLabel.lineBreakMode = .byWordWrapping
        nameLabel.numberOfLines = 0
        artistImage.displayAndUpdate(entity: artist, via: appDelegate.artworkDownloadManager)
        var infoText = ""
        if artist.albumCount == 1 {
            infoText += "1 Album"
        } else {
            infoText += "\(artist.albumCount) Albums"
        }
        infoText += " \(CommonString.oneMiddleDot) "
        if artist.songCount == 1 {
            infoText.append("1 Song")
        } else {
            infoText.append("\(artist.songCount) Songs")
        }
        infoLabel.text = infoText
    }

    @IBAction func optionsButtonPressed(_ sender: Any) {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
        guard let artist = self.artist, let rootView = self.rootView, rootView.presentingViewController == nil else { return }
        let detailVC = LibraryEntityDetailVC()
        detailVC.display(artist: artist, on: rootView)
        rootView.present(detailVC, animated: true)
    }
    
}
