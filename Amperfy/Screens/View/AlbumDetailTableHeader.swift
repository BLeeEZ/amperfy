import UIKit

class AlbumDetailTableHeader: UIView {
    
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var albumImage: LibraryEntityImage!
    @IBOutlet weak var infoLabel: UILabel!
    
    static let frameHeight: CGFloat = 150.0 + margin.top + margin.bottom
    static let margin = UIView.defaultMarginTopElement
    private var album: Album?
    private var appDelegate: AppDelegate!
    private var rootView: AlbumDetailVC?
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        appDelegate = (UIApplication.shared.delegate as! AppDelegate)
        self.layoutMargins = Self.margin
    }
    
    func prepare(toWorkOnAlbum album: Album?, rootView: AlbumDetailVC? ) {
        guard let album = album else { return }
        self.album = album
        self.rootView = rootView
        refresh()
    }
    
    func refresh() {
        guard let album = album else { return }
        nameLabel.text = album.name
        nameLabel.lineBreakMode = .byWordWrapping
        nameLabel.numberOfLines = 0
        albumImage.displayAndUpdate(entity: album, via: appDelegate.artworkDownloadManager)
        var infoText = ""
        if album.songCount == 1 {
            infoText += "1 Song"
        } else {
            infoText += "\(album.songCount) Songs"
        }
        infoText += " \(CommonString.oneMiddleDot) \(album.duration.asDurationString)"
        if album.year != 0 {
            infoText += " \(CommonString.oneMiddleDot) Released \(album.year)"
        }
        infoLabel.text = infoText
    }

    @IBAction func optionsButtonPressed(_ sender: Any) {
        if let album = self.album, let rootView = self.rootView {
            let alert = createAlert(forAlbum: album)
            alert.setOptionsForIPadToDisplayPopupCentricIn(view: rootView.view)
            rootView.present(alert, animated: true, completion: nil)
        }
    }
    
    func createAlert(forAlbum album: Album) -> UIAlertController {
        let alert = UIAlertController(title: album.name, message: nil, preferredStyle: .actionSheet)
        if appDelegate.persistentStorage.settings.isOnlineMode {
            alert.addAction(UIAlertAction(title: "Add to playlist", style: .default, handler: { _ in
                let selectPlaylistVC = PlaylistSelectorVC.instantiateFromAppStoryboard()
                selectPlaylistVC.itemsToAdd = album.songs
                let selectPlaylistNav = UINavigationController(rootViewController: selectPlaylistVC)
                if let rootView = self.rootView {
                    rootView.present(selectPlaylistNav, animated: true, completion: nil)
                }
            }))
            alert.addAction(UIAlertAction(title: "Download", style: .default, handler: { _ in
                for song in album.songs {
                    if !song.isCached {
                        self.appDelegate.playableDownloadManager.download(object: song)
                    }
                }
            }))
        }
        if album.hasCachedPlayables {
            alert.addAction(UIAlertAction(title: "Remove from cache", style: .default, handler: { _ in
                self.appDelegate.library.deleteCache(of: album)
                self.appDelegate.library.saveContext()
                if let rootView = self.rootView {
                    rootView.tableView.reloadData()
                }
            }))
        }
        if let artist = album.artist {
            alert.addAction(UIAlertAction(title: "Show artist", style: .default, handler: { _ in
                let artistDetailVC = ArtistDetailVC.instantiateFromAppStoryboard()
                artistDetailVC.artist = artist
                if let navController = self.rootView?.navigationController {
                    navController.pushViewController(artistDetailVC, animated: true)
                }
            }))
        }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.pruneNegativeWidthConstraintsToAvoidFalseConstraintWarnings()
        return alert
    }
    
}
