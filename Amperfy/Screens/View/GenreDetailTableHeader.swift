import UIKit

class GenreDetailTableHeader: UIView {
    
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var genreImage: LibraryEntityImage!
    @IBOutlet weak var infoLabel: MarqueeLabel!
    
    static let frameHeight: CGFloat = 150.0 + margin.top + margin.bottom
    static let margin = UIView.defaultMarginTopElement
    
    private var genre: Genre?
    private var appDelegate: AppDelegate!
    private var rootView: GenreDetailVC?
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        appDelegate = (UIApplication.shared.delegate as! AppDelegate)
        self.layoutMargins = Self.margin
    }
    
    func prepare(toWorkOn genre: Genre?, rootView: GenreDetailVC? ) {
        guard let genre = genre else { return }
        self.genre = genre
        self.rootView = rootView
        refresh()
    }
        
    func refresh() {
        guard let genre = genre else { return }
        nameLabel.text = genre.name
        nameLabel.lineBreakMode = .byWordWrapping
        nameLabel.numberOfLines = 0
        genreImage.displayAndUpdate(entity: genre, via: appDelegate.artworkDownloadManager)
        infoLabel.applyAmperfyStyle()
        infoLabel.text = genre.info(for: appDelegate.backendProxy.selectedApi, type: .long)
    }

    @IBAction func optionsButtonPressed(_ sender: Any) {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
        guard let genre = self.genre, let rootView = self.rootView, rootView.presentingViewController == nil else { return }
        let detailVC = LibraryEntityDetailVC()
        detailVC.display(genre: genre, on: rootView)
        rootView.present(detailVC, animated: true)
    }
    
}
