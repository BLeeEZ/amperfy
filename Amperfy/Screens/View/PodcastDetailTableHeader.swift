import UIKit

class PodcastDetailTableHeader: UIView {
    
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var podcastImage: LibraryEntityImage!
    @IBOutlet weak var infoLabel: MarqueeLabel!
    @IBOutlet weak var descriptionLabel: UILabel!
    
    static let frameHeight: CGFloat = 245.0 + margin.top + margin.bottom
    static let margin = UIView.defaultMarginTopElement
    private var podcast: Podcast?
    private var appDelegate: AppDelegate!
    private var rootView: PodcastDetailVC?
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        appDelegate = (UIApplication.shared.delegate as! AppDelegate)
        self.layoutMargins = Self.margin
    }
    
    func prepare(toWorkOnPodcast podcast: Podcast?, rootView: PodcastDetailVC? ) {
        guard let podcast = podcast else { return }
        self.podcast = podcast
        self.rootView = rootView
        refresh()
    }
    
    func refresh() {
        guard let podcast = podcast else { return }
        titleLabel.text = podcast.title
        titleLabel.lineBreakMode = .byWordWrapping
        titleLabel.numberOfLines = 0
        podcastImage.displayAndUpdate(entity: podcast, via: appDelegate.artworkDownloadManager)
        infoLabel.applyAmperfyStyle()
        infoLabel.text = podcast.info(for: appDelegate.backendProxy.selectedApi, type: .long)
        descriptionLabel.text = podcast.depiction
    }

    @IBAction func optionsButtonPressed(_ sender: Any) {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
        guard let podcast = self.podcast, let rootView = self.rootView, rootView.presentingViewController == nil else { return }
        let detailVC = LibraryEntityDetailVC()
        detailVC.display(container: podcast, on: rootView)
        rootView.present(detailVC, animated: true)
    }
    
}
