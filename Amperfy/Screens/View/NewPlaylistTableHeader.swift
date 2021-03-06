import UIKit

typealias PlaylistCreationResponder = (_ playlist: Playlist) -> Void

class NewPlaylistTableHeader: UIView {

    @IBOutlet weak var nameTextField: UITextField!
    
    static let frameHeight: CGFloat = 30.0 + margin.top + margin.bottom
    static let margin = UIEdgeInsets(top: 10, left: UIView.defaultMarginX, bottom: 5, right: UIView.defaultMarginX)
    
    private var appDelegate: AppDelegate!
    private var creationResponder: PlaylistCreationResponder?

    override init(frame: CGRect) {
        super.init(frame: frame)
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        appDelegate = (UIApplication.shared.delegate as! AppDelegate)
        self.layoutMargins = NewPlaylistTableHeader.margin
    }

    @IBAction func createPlaylistButtonPressed(_ sender: Any) {
        guard let playlistName = nameTextField.text, !playlistName.isEmpty else {
            return
        }
        let playlist = appDelegate.persistentLibraryStorage.createPlaylist()
        playlist.name = playlistName
        nameTextField.text = ""
        appDelegate.persistentLibraryStorage.saveContext()
        creationResponder?(playlist)
    }
    
    func reactOnCreation(with responder: PlaylistCreationResponder?) {
        creationResponder = responder
    }

}
