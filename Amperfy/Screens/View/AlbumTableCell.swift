import UIKit

class AlbumTableCell: BasicTableCell {
    
    @IBOutlet weak var albumLabel: UILabel!
    @IBOutlet weak var artistLabel: UILabel!
    @IBOutlet weak var artworkImage: LibraryEntityImage!
    @IBOutlet weak var infoLabel: UILabel!
    
    static let rowHeight: CGFloat = 48.0 + margin.bottom + margin.top
    
    private var album: Album?
    private var rootView: UITableViewController?
    
    override func awakeFromNib() {
        super.awakeFromNib()
        let longPressGesture = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPressGesture))
        self.addGestureRecognizer(longPressGesture)
    }
    
    func display(album: Album, rootView: UITableViewController) {
        self.album = album
        self.rootView = rootView
        albumLabel.text = album.name
        artistLabel.text = album.artist?.name
        artworkImage.displayAndUpdate(entity: album, via: appDelegate.artworkDownloadManager)
        infoLabel.text = album.info(for: appDelegate.backendProxy.selectedApi, type: .short)
    }

    @objc func handleLongPressGesture(gesture: UILongPressGestureRecognizer) -> Void {
        if gesture.state == .began {
            displayMenu()
        }
    }
    
    func displayMenu() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
        guard let album = album, let rootView = rootView, rootView.presentingViewController == nil else { return }
        let detailVC = LibraryEntityDetailVC()
        detailVC.display(container: album, on: rootView)
        rootView.present(detailVC, animated: true)
    }
    
}
