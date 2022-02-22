import UIKit

class PlaylistTableCell: BasicTableCell {

    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var entityImage: EntityImageView!
    @IBOutlet weak var infoLabel: UILabel!
    
    static let rowHeight: CGFloat = 70.0 + margin.bottom + margin.top
    
    private var playlist: Playlist?
    private var rootView: UITableViewController?
    
    override func awakeFromNib() {
        super.awakeFromNib()
        let longPressGesture = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPressGesture))
        self.addGestureRecognizer(longPressGesture)
    }
    
    func display(playlist: Playlist, rootView: UITableViewController?) {
        self.playlist = playlist
        self.rootView = rootView
        nameLabel.text = playlist.name
        entityImage.display(container: playlist)
        infoLabel.text = playlist.info(for: appDelegate.backendProxy.selectedApi, type: .short)
    }
    
    @objc func handleLongPressGesture(gesture: UILongPressGestureRecognizer) -> Void {
        if gesture.state == .began {
            displayMenu()
        }
    }
    
    func displayMenu() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
        guard let playlist = playlist, let rootView = rootView else { return }
        let detailVC = LibraryEntityDetailVC()
        detailVC.display(container: playlist, on: rootView)
        rootView.present(detailVC, animated: true)
    }
    
}
