import UIKit

class GenreDetailTableHeader: UIView {
    
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var genreImage: LibraryEntityImage!
    @IBOutlet weak var infoLabel: UILabel!
    
    static let frameHeight: CGFloat = 150.0 + margin.top + margin.bottom
    static let margin = UIView.defaultMarginTopElement
    private var genre: Genre?
    private var appDelegate: AppDelegate!
    private var rootView: GenreDetailVC?
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        appDelegate = (UIApplication.shared.delegate as! AppDelegate)
        self.layoutMargins = Self.margin
    }
    
    func prepare(toWorkOn genre: Genre?, rootView: GenreDetailVC? ) {
        guard let genre = genre else { return }
        self.genre = genre
        self.rootView = rootView
        nameLabel.text = genre.name
        nameLabel.lineBreakMode = .byWordWrapping
        nameLabel.numberOfLines = 0
        genreImage.displayAndUpdate(entity: genre, via: appDelegate.artworkDownloadManager)
        var infoText = ""
        if appDelegate.backendProxy.selectedApi == .ampache {
            if genre.artists.count == 1 {
                infoText += "1 Artist"
            } else {
                infoText += "\(genre.artists.count) Artists"
            }
            infoText += " \(CommonString.oneMiddleDot) "
        }
        if genre.albums.count == 1 {
            infoText += "1 Album"
        } else {
            infoText += "\(genre.albums.count) Albums"
        }
        infoLabel.text = infoText
    }

    @IBAction func optionsButtonPressed(_ sender: Any) {
        if let genre = self.genre, let rootView = self.rootView {
            let alert = createAlert(for: genre)
            alert.setOptionsForIPadToDisplayPopupCentricIn(view: rootView.view)
            rootView.present(alert, animated: true, completion: nil)
        }
    }
    
    func createAlert(for genre: Genre) -> UIAlertController {
        let alert = UIAlertController(title: genre.name, message: nil, preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: "Add to playlist", style: .default, handler: { _ in
            let selectPlaylistVC = PlaylistSelectorVC.instantiateFromAppStoryboard()
            selectPlaylistVC.songsToAdd = genre.songs
            let selectPlaylistNav = UINavigationController(rootViewController: selectPlaylistVC)
            if let rootView = self.rootView {
                rootView.present(selectPlaylistNav, animated: true, completion: nil)
            }
        }))
        alert.addAction(UIAlertAction(title: "Download", style: .default, handler: { _ in
            self.appDelegate.songDownloadManager.download(objects: genre.songs)
        }))
        if genre.hasCachedSongs {
            alert.addAction(UIAlertAction(title: "Remove from cache", style: .default, handler: { _ in
                self.appDelegate.library.deleteCache(ofGenre: genre)
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
