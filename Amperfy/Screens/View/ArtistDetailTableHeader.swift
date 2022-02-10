import UIKit

class ArtistDetailTableHeader: UIView {
    
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var artistImage: LibraryEntityImage!
    @IBOutlet weak var infoLabel: MarqueeLabel!
    
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
        infoLabel.applyAmperfyStyle()
        infoLabel.text = artist.info(for: appDelegate.backendProxy.selectedApi, type: .long)
    }

    @IBAction func optionsButtonPressed(_ sender: Any) {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
        guard let artist = self.artist, let rootView = self.rootView, rootView.presentingViewController == nil else { return }
        let detailVC = LibraryEntityDetailVC()
        detailVC.display(container: artist, on: rootView)
        rootView.present(detailVC, animated: true)
    }
    
}
