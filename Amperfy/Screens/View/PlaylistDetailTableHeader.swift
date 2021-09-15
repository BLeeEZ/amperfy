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
    @IBOutlet weak var smartPlaylistLabel: UILabel!
    @IBOutlet weak var songCountLabel: UILabel!
    
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
        var infoText = ""
        if playlist.songCount == 1 {
            infoText += "1 Song"
        } else {
            infoText += "\(playlist.songCount) Songs"
        }
        infoText += " \(CommonString.oneMiddleDot) \(playlist.duration.asDurationString)"
        songCountLabel.text = infoText
        if !playlist.isSmartPlaylist {
            smartPlaylistLabel.isHidden = true
        }
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
        if let playlist = self.playlist, let rootView = self.rootView {
            let alert = createAlert(forPlaylist: playlist)
            alert.setOptionsForIPadToDisplayPopupCentricIn(view: rootView.view)
            rootView.present(alert, animated: true, completion: nil)
        }
    }

    func createAlert(forPlaylist playlist: Playlist) -> UIAlertController {
        let alert = UIAlertController(title: playlist.name, message: nil, preferredStyle: .actionSheet)
        
        if appDelegate.persistentStorage.settings.isOnlineMode {
            alert.addAction(UIAlertAction(title: "Download all songs", style: .default, handler: { _ in
                self.appDelegate.playableDownloadManager.download(objects: playlist.playables)
            }))
        }
        if playlist.hasCachedPlayables {
            alert.addAction(UIAlertAction(title: "Remove from cache", style: .default, handler: { _ in
                self.appDelegate.library.deleteCache(of: playlist)
                self.appDelegate.library.saveContext()
                if let rootView = self.rootView {
                    rootView.tableView.reloadData()
                }
            }))
        }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.pruneNegativeWidthConstraintsToAvoidFalseConstraintWarnings()
        return alert
    }
    
}
