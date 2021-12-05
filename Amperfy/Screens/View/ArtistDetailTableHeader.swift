import UIKit

class ArtistDetailTableHeader: UIView {
    
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var artistImage: LibraryEntityImage!
    @IBOutlet weak var infoLabel: UILabel!
    
    static let frameHeight: CGFloat = 150.0 + margin.top + margin.bottom
    static let margin = UIView.defaultMarginTopElement
    
    private var artist: Artist?
    private var appDelegate: AppDelegate!
    private var rootView: ArtistDetailVC?
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        appDelegate = (UIApplication.shared.delegate as! AppDelegate)
        self.layoutMargins = Self.margin
    }
    
    func prepare(toWorkOnArtist artist: Artist?, rootView: ArtistDetailVC? ) {
        guard let artist = artist else { return }
        self.artist = artist
        self.rootView = rootView
        refresh()
    }
    
    func refresh() {
        guard let artist = artist else { return }
        nameLabel.text = artist.name
        nameLabel.lineBreakMode = .byWordWrapping
        nameLabel.numberOfLines = 0
        artistImage.displayAndUpdate(entity: artist, via: appDelegate.artworkDownloadManager)
        var infoText = ""
        if artist.albumCount == 1 {
            infoText += "1 Album"
        } else {
            infoText += "\(artist.albumCount) Albums"
        }
        infoLabel.text = infoText
    }

    @IBAction func optionsButtonPressed(_ sender: Any) {
        if let artist = self.artist, let rootView = self.rootView {
            let alert = createAlert(forArtist: artist)
            alert.setOptionsForIPadToDisplayPopupCentricIn(view: rootView.view)
            rootView.present(alert, animated: true, completion: nil)
        }
    }
    
    func createAlert(forArtist artist: Artist) -> UIAlertController {
        let alert = UIAlertController(title: artist.name, message: nil, preferredStyle: .actionSheet)
        if appDelegate.persistentStorage.settings.isOnlineMode {
            alert.addAction(UIAlertAction(title: "Add to playlist", style: .default, handler: { _ in
                let selectPlaylistVC = PlaylistSelectorVC.instantiateFromAppStoryboard()
                selectPlaylistVC.itemsToAdd = artist.songs
                let selectPlaylistNav = UINavigationController(rootViewController: selectPlaylistVC)
                if let rootView = self.rootView {
                    rootView.present(selectPlaylistNav, animated: true, completion: nil)
                }
            }))
            alert.addAction(UIAlertAction(title: "Download", style: .default, handler: { _ in
                for song in artist.songs {
                    if !song.isCached {
                        self.appDelegate.playableDownloadManager.download(object: song)
                    }
                }
            }))
        }
        if artist.hasCachedPlayables {
            alert.addAction(UIAlertAction(title: "Remove from cache", style: .default, handler: { _ in
                self.appDelegate.playableDownloadManager.removeFinishedDownload(for: artist.playables)
                self.appDelegate.library.deleteCache(of: artist)
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
