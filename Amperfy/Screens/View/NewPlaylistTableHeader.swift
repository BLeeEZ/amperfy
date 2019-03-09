import UIKit

typealias PlaylistCreationResponder = (_ playlist: Playlist) -> Void

class NewPlaylistTableHeader: UIView {

    @IBOutlet weak var nameTextField: UITextField!
    
    static let frameHeight: CGFloat = 56.0
    private var appDelegate: AppDelegate!
    private var creationResponder: PlaylistCreationResponder?

    override init(frame: CGRect) {
        appDelegate = (UIApplication.shared.delegate as! AppDelegate)
        super.init(frame: frame)
    }
    
    required init?(coder aDecoder: NSCoder) {
        appDelegate = (UIApplication.shared.delegate as! AppDelegate)
        super.init(coder: aDecoder)
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
