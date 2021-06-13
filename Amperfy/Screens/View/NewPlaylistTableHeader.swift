import UIKit

typealias PlaylistCreationResponder = (_ playlist: Playlist) -> Void

class NewPlaylistTableHeader: UIView {

    @IBOutlet weak var nameTextField: UITextField!
    
    static let frameHeight: CGFloat = 30.0 + margin.top + margin.bottom
    static let margin = UIEdgeInsets(top: 10, left: UIView.defaultMarginX, bottom: 5, right: UIView.defaultMarginX)
    
    private var appDelegate: AppDelegate!

    override init(frame: CGRect) {
        super.init(frame: frame)
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        appDelegate = (UIApplication.shared.delegate as! AppDelegate)
        self.layoutMargins = Self.margin
    }

    @IBAction func createPlaylistButtonPressed(_ sender: Any) {
        guard let playlistName = nameTextField.text, !playlistName.isEmpty else {
            return
        }
        let playlist = appDelegate.library.createPlaylist()
        playlist.name = playlistName
        nameTextField.text = ""
        appDelegate.library.saveContext()
    }

}
