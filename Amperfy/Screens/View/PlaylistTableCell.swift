import UIKit

class PlaylistTableCell: BasicTableCell {

    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var art1Image: UIImageView!
    @IBOutlet weak var art2Image: UIImageView!
    @IBOutlet weak var art3Image: UIImageView!
    @IBOutlet weak var art4Image: UIImageView!
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
        var images = [UIImageView]()
        images.append(art1Image)
        images.append(art2Image)
        images.append(art3Image)
        images.append(art4Image)
        
        for artImage in images {
            artImage.image = Artwork.defaultImage
        }
        
        if playlist.songCount < 500 {
            let customArtworkSongs = playlist.playables.filterCustomArt()
            for (index, artImage) in images.enumerated() {
                guard customArtworkSongs.count > index else { break }
                artImage.image = customArtworkSongs[index].image
            }
        }
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
        guard let playlist = playlist, let rootView = rootView, rootView.presentingViewController == nil else { return }
        let detailVC = LibraryEntityDetailVC()
        detailVC.display(container: playlist, on: rootView)
        rootView.present(detailVC, animated: true)
    }
    
}
