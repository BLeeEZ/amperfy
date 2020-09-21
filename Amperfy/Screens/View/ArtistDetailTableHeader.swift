import UIKit

class ArtistDetailTableHeader: UIView {
    
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var artistImage: UIImageView!
    
    static let frameHeight: CGFloat = 133.0
    private var artist: Artist?
    private var appDelegate: AppDelegate!
    private var rootView: ArtistDetailVC?
    
    required init?(coder aDecoder: NSCoder) {
        appDelegate = (UIApplication.shared.delegate as! AppDelegate)
        super.init(coder: aDecoder)
    }
    
    func prepare(toWorkOnArtist artist: Artist?, rootView: ArtistDetailVC? ) {
        guard let artist = artist else { return }
        self.artist = artist
        self.rootView = rootView
        nameLabel.text = artist.name
        nameLabel.lineBreakMode = .byWordWrapping
        nameLabel.numberOfLines = 0
        artistImage.image = artist.image
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
        alert.addAction(UIAlertAction(title: "Add to playlist", style: .default, handler: { _ in
            let selectPlaylistVC = PlaylistSelectorVC.instantiateFromAppStoryboard()
            selectPlaylistVC.songsToAdd = artist.songs
            let selectPlaylistNav = UINavigationController(rootViewController: selectPlaylistVC)
            if let rootView = self.rootView {
                rootView.present(selectPlaylistNav, animated: true, completion: nil)
            }
        }))
        alert.addAction(UIAlertAction(title: "Download", style: .default, handler: { _ in
            for song in artist.songs {
                if !song.isCached {
                    self.appDelegate.downloadManager.download(song: song)
                }
            }
        }))
        if artist.hasCachedSongs {
            alert.addAction(UIAlertAction(title: "Remove from cache", style: .default, handler: { _ in
                self.appDelegate.persistentLibraryStorage.deleteCache(ofArtist: artist)
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
