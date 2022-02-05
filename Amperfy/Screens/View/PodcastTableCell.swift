import UIKit

class PodcastTableCell: BasicTableCell {
    
    @IBOutlet weak var podcastLabel: UILabel!
    @IBOutlet weak var podcastImage: LibraryEntityImage!
    @IBOutlet weak var infoLabel: UILabel!
    
    static let rowHeight: CGFloat = 48.0 + margin.bottom + margin.top
    
    private var podcast: Podcast!
    private var rootView: UITableViewController?
    
    override func awakeFromNib() {
        super.awakeFromNib()
        let longPressGesture = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPressGesture))
        self.addGestureRecognizer(longPressGesture)
    }
    
    func display(podcast: Podcast, rootView: UITableViewController) {
        self.podcast = podcast
        self.rootView = rootView
        podcastLabel.text = podcast.title
        podcastImage.displayAndUpdate(entity: podcast, via: appDelegate.artworkDownloadManager)
        infoLabel.text = podcast.info(for: appDelegate.backendProxy.selectedApi, type: .short)
    }

    @objc func handleLongPressGesture(gesture: UILongPressGestureRecognizer) -> Void {
        if gesture.state == .began {
            displayMenu()
        }
    }
    
    func displayMenu() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
        guard let podcast = podcast, let rootView = rootView, rootView.presentingViewController == nil else { return }
        let detailVC = LibraryEntityDetailVC()
        detailVC.display(podcast: podcast, on: rootView)
        rootView.present(detailVC, animated: true)
    }
    
}
