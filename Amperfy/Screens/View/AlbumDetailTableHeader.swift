import UIKit

class AlbumDetailTableHeader: UIView {
    
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var albumImage: UIImageView!
    
    static let frameHeight: CGFloat = 133.0
    private var album: Album?
    private var appDelegate: AppDelegate!
    private var rootView: AlbumDetailVC?
    
    required init?(coder aDecoder: NSCoder) {
        appDelegate = (UIApplication.shared.delegate as! AppDelegate)
        super.init(coder: aDecoder)
    }
    
    func prepare(toWorkOnAlbum album: Album?, rootView: AlbumDetailVC? ) {
        guard let album = album else { return }
        self.album = album
        self.rootView = rootView
        nameLabel.text = album.name
        nameLabel.lineBreakMode = .byWordWrapping
        nameLabel.numberOfLines = 0
        albumImage.image = album.image
    }

    @IBAction func optionsButtonPressed(_ sender: Any) {
        if let album = self.album, let rootView = self.rootView {
            let alert = createAlert(forAlbum: album)
            rootView.present(alert, animated: true, completion: nil)
        }
    }
    
    func createAlert(forAlbum album: Album) -> UIAlertController {
        let alert = UIAlertController(title: album.name, message: nil, preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: "Listen later", style: .default, handler: { _ in
            for song in album.songs {
                if !song.isCached {
                    self.appDelegate.downloadManager.download(song: song)
                }
            }
        }))
        if album.hasCachedSongs {
            alert.addAction(UIAlertAction(title: "Remove from cache", style: .default, handler: { _ in
                self.appDelegate.persistentLibraryStorage.deleteCache(ofAlbum: album)
                if let rootView = self.rootView {
                    rootView.tableView.reloadData()
                }
            }))
        }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        return alert
    }
    
}
