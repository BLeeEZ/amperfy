import UIKit

class PlaylistDetailTableHeader: UIView {

    @IBOutlet weak var entityImage: EntityImageView!
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var nameTextField: UITextField!
    @IBOutlet weak var infoLabel: UILabel!
    
    static let frameHeight: CGFloat = 200.0
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
        self.rootView = rootView
        nameLabel.setContentCompressionResistancePriority(.required, for: .vertical)
        nameTextField.setContentCompressionResistancePriority(.required, for: .vertical)
        infoLabel.setContentCompressionResistancePriority(.required, for: .vertical)
        refresh()
    }
    
    func refresh() {
        guard let playlist = playlist, let rootView = rootView else { return }
        entityImage.display(container: playlist)
        nameLabel.text = playlist.name
        nameTextField.text = playlist.name
        infoLabel.text = playlist.info(for: appDelegate.backendProxy.selectedApi, type: .long)
        if rootView.tableView.isEditing {
            nameLabel.isHidden = true
            nameTextField.isHidden = false
            nameTextField.text = playlist.name
        } else {
            nameLabel.isHidden = false
            nameTextField.isHidden = true
        }
    }

    func startEditing() {
        refresh()
    }
    
    func endEditing() {
        if let nameText = nameTextField.text, let playlist = playlist, nameText != playlist.name {
            playlist.name = nameText
            nameLabel.text = nameText
            if appDelegate.persistentStorage.settings.isOnlineMode {
                appDelegate.persistentStorage.persistentContainer.performBackgroundTask() { (context) in
                    let syncLibrary = LibraryStorage(context: context)
                    let syncer = self.appDelegate.backendApi.createLibrarySyncer()
                    let playlistAsync = playlist.getManagedObject(in: context, library: syncLibrary)
                    syncer.syncUpload(playlistToUpdateName: playlistAsync, library: syncLibrary)
                }
            }
        }
        refresh()
    }

}
