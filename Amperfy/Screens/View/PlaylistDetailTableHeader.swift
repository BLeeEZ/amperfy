import UIKit

class PlaylistDetailTableHeader: UIView {

    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var nameTextField: UITextField!
    @IBOutlet weak var optionsButton: UIButton!
    @IBOutlet weak var art1Image: LibraryEntityImage!
    @IBOutlet weak var art2Image: LibraryEntityImage!
    @IBOutlet weak var art3Image: LibraryEntityImage!
    @IBOutlet weak var art4Image: LibraryEntityImage!
    @IBOutlet weak var art5Image: LibraryEntityImage!
    @IBOutlet weak var art6Image: LibraryEntityImage!
    @IBOutlet weak var infoLabel: MarqueeLabel!
    
    static let frameHeight: CGFloat = 109.0 + margin.top + margin.bottom
    static let margin = UIView.defaultMarginTopElement
    
    private var playlist: Playlist?
    private var appDelegate: AppDelegate!
    private var rootView: PlaylistDetailVC?
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        appDelegate = (UIApplication.shared.delegate as! AppDelegate)
        self.layoutMargins = Self.margin
    }
    
    func prepare(toWorkOnPlaylist playlist: Playlist?, rootView: PlaylistDetailVC) {
        guard let playlist = playlist else { return }
        self.playlist = playlist
        nameLabel.text = playlist.name
        self.rootView = rootView
        refresh()
    }
    
    func refresh() {
        guard let playlist = playlist else { return }
        nameTextField.text = playlist.name
        nameLabel.text = playlist.name
        refreshArtworks(playlist: playlist)
        infoLabel.applyAmperfyStyle()
        infoLabel.text = playlist.info(for: appDelegate.backendProxy.selectedApi, type: .long)
    }
    
    func refreshArtworks(playlist: Playlist?) {
        let images: [LibraryEntityImage] = [art1Image, art2Image, art3Image, art4Image, art5Image, art6Image]
        images.forEach{ $0.image = Artwork.defaultImage }
        
        guard let playlist = playlist else { return }
        let playables = playlist.playables
        for (index, artImage) in images.enumerated() {
            guard playables.count > index else { break }
            artImage.displayAndUpdate(entity: playables[index], via: appDelegate.artworkDownloadManager)
        }
    }
    
    func startEditing() {
        nameLabel.isHidden = true
        nameTextField.text = playlist?.name
        nameTextField.isHidden = false
    }
    
    func endEditing() {
        nameLabel.isHidden = false
        nameTextField.isHidden = true
        if let nameText = nameTextField.text, let playlist = playlist, nameText != playlist.name {
            playlist.name = nameText
            nameLabel.text = nameText
        }
    }
    
    @IBAction func optionsButtonPressed(_ sender: Any) {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
        guard let playlist = playlist, let rootView = rootView, rootView.presentingViewController == nil else { return }
        let detailVC = LibraryEntityDetailVC()
        detailVC.display(playlist: playlist, on: rootView)
        rootView.present(detailVC, animated: true)
    }

}
