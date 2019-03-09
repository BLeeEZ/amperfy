import UIKit

class PlaylistDetailTableHeader: UIView {

    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var nameTextField: UITextField!
    @IBOutlet weak var optionsButton: UIButton!
    @IBOutlet weak var art1Image: UIImageView!
    @IBOutlet weak var art2Image: UIImageView!
    @IBOutlet weak var art3Image: UIImageView!
    @IBOutlet weak var art4Image: UIImageView!
    @IBOutlet weak var art5Image: UIImageView!
    @IBOutlet weak var art6Image: UIImageView!
    
    static let frameHeight: CGFloat = 98.0
    private var playlist: Playlist?
    private var appDelegate: AppDelegate!
    private var rootView: PlaylistDetailVC?
    
    required init?(coder aDecoder: NSCoder) {
        appDelegate = (UIApplication.shared.delegate as! AppDelegate)
        super.init(coder: aDecoder)
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
    }
    
    func refreshArtworks(playlist: Playlist?) {
        var images = [UIImageView]()
        images.append(art1Image)
        images.append(art2Image)
        images.append(art3Image)
        images.append(art4Image)
        images.append(art5Image)
        images.append(art6Image)
        
        for artImage in images {
            artImage.image = Artwork.defaultImage
        }
        
        guard let playlist = playlist else { return }
        let customArtworkSongs = playlist.songs.filterCustomArt()
        for (index, artImage) in images.enumerated() {
            guard customArtworkSongs.count > index else { break }
            artImage.image = customArtworkSongs[index].image
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
            let alert = createAlert(forPlaylist: playlist, statusNotifyier: rootView)
            rootView.present(alert, animated: true, completion: nil)
        }
    }

    func createAlert(forPlaylist playlist: Playlist, statusNotifyier: PlaylistSyncCallbacks) -> UIAlertController {
        let ampacheApi = appDelegate.ampacheApi
        let storage = appDelegate.storage
        let alert = UIAlertController(title: playlist.name, message: nil, preferredStyle: .actionSheet)
        
        if playlist.id != 0 {
            alert.addAction(UIAlertAction(title: "Download from server", style: .default, handler: { _ in
                storage.persistentContainer.performBackgroundTask() { (context) in
                    let backgroundStorage = LibraryStorage(context: context)
                    let syncer = LibrarySyncer(ampacheApi: ampacheApi)
                    guard let playlistAsync = backgroundStorage.getPlaylist(id: playlist.id) else { return }
                    syncer.syncDown(playlist: playlistAsync, libraryStorage: backgroundStorage, statusNotifyier: statusNotifyier)
                }
            }))
        }
        alert.addAction(UIAlertAction(title: "Upload to server", style: .default, handler: { _ in
            storage.persistentContainer.performBackgroundTask() { (context) in
                let backgroundStorage = LibraryStorage(context: context)
                let syncer = LibrarySyncer(ampacheApi: ampacheApi)
                guard let playlistAsync = backgroundStorage.getPlaylist(id: playlist.id) else { return }
                syncer.syncUpload(playlist: playlistAsync, libraryStorage: backgroundStorage, statusNotifyier: statusNotifyier)
            }
        }))
        alert.addAction(UIAlertAction(title: "Listen later", style: .default, handler: { _ in
            for song in playlist.songs {
                if !song.isCached {
                    self.appDelegate.downloadManager.download(song: song)
                }
            }
        }))
        if playlist.hasCachedSongs {
            alert.addAction(UIAlertAction(title: "Remove from cache", style: .default, handler: { _ in
                self.appDelegate.persistentLibraryStorage.deleteCache(ofPlaylist: playlist)
                if let rootView = self.rootView {
                    rootView.tableView.reloadData()
                }
            }))
        }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        return alert
    }
    
}
