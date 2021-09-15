import UIKit
import AudioToolbox

enum SongActionOnTab: Int {
    case playAndErasePlaylist = 0
    case addToPlaylistAndPlay = 2
    case insertAsNextSongNoPlay = 3
    
    static let defaultValue: SongActionOnTab = .addToPlaylistAndPlay
    
    var description : String {
        switch self {
        case .playAndErasePlaylist: return "PlayAndErasePlaylist"
        case .addToPlaylistAndPlay: return "AddToPlaylistAndPlay"
        case .insertAsNextSongNoPlay: return "InsertAsNextSongNoPlay"
        }
    }
    
    var displayText : String {
        switch self {
        case .playAndErasePlaylist: return "Clear current playlist and play song"
        case .addToPlaylistAndPlay: return "Insert song at the end and play song"
        case .insertAsNextSongNoPlay: return "Insert as next song to play"
        }
    }
}

class SongTableCell: BasicTableCell {
    
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var artistLabel: UILabel!
    @IBOutlet weak var artworkImage: LibraryEntityImage!
    
    static let rowHeight: CGFloat = 48 + margin.bottom + margin.top
    
    private var song: Song?
    private var rootView: UIViewController?
    private var isAlertPresented = false

    override func awakeFromNib() {
        super.awakeFromNib()
        let longPressGesture = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPressGesture))
        self.addGestureRecognizer(longPressGesture)
    }
    
    func display(song: Song, rootView: UIViewController) {
        self.song = song
        self.rootView = rootView
        refresh()
    }
    
    func refresh() {
        guard let song = song else { return }
        titleLabel.attributedText = NSMutableAttributedString(string: song.title, attributes: [NSAttributedString.Key.font: UIFont.systemFont(ofSize: 17)])
        artistLabel.text = song.creatorName
        
        artworkImage.displayAndUpdate(entity: song, via: appDelegate.artworkDownloadManager)

        if song.isCached {
            artistLabel.textColor = UIColor.defaultBlue
        } else {
            artistLabel.textColor = UIColor.secondaryLabelColor
        }
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let song = song else { return }

        if !isAlertPresented && (song.isCached || appDelegate.persistentStorage.settings.isOnlineMode) {
            hideSearchBarKeyboardInRootView()
            switch appDelegate.persistentStorage.settings.songActionOnTab {
            case .playAndErasePlaylist:
                appDelegate.player.play(playable: song)
            case .addToPlaylistAndPlay:
                appDelegate.player.addToPlaylist(playable: song)
                let indexInPlayerPlaylist = appDelegate.player.playlist.playables.count-1
                appDelegate.player.play(elementInPlaylistAt: indexInPlayerPlaylist)
            case .insertAsNextSongNoPlay:
                appDelegate.player.addToPlaylist(playable: song)
                let addedSongIndexInPlayerPlaylist = appDelegate.player.playlist.playables.count-1
                if let curPlayingIndex = appDelegate.player.currentlyPlaying?.index {
                    appDelegate.player.movePlaylistItem(fromIndex: addedSongIndexInPlayerPlaylist, to: curPlayingIndex+1)
                }
            }
        }
        isAlertPresented = false
    }
    
    private func hideSearchBarKeyboardInRootView() {
        if let basicRootView = rootView as? BasicTableViewController {
            basicRootView.searchController.searchBar.endEditing(true)
        }
    }
    
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        isAlertPresented = false
    }
    
    @objc func handleLongPressGesture(gesture: UILongPressGestureRecognizer) -> Void {
        if gesture.state == .began {
            displayMenu()
        }
    }
    
    func displayMenu() {
        if let song = song, let rootView = rootView, rootView.presentingViewController == nil {
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
            isAlertPresented = true
            let alert = createAlert(forSong: song, rootView: rootView)
            alert.setOptionsForIPadToDisplayPopupCentricIn(view: rootView.view)
            rootView.present(alert, animated: true, completion: nil)
        }
    }
    
    func createAlert(forSong song: Song, rootView: UIViewController) -> UIAlertController {
        let alert = UIAlertController(title: "\n\n\n", message: nil, preferredStyle: .actionSheet)
    
        let headerView = UIView(frame: CGRect(x: 0, y: 0, width: alert.view.bounds.size.width, height: SongActionSheetView.frameHeight))
        if let songActionSheetView = ViewBuilder<SongActionSheetView>.createFromNib(withinFixedFrame: CGRect(x: 0, y: 0, width: alert.view.bounds.size.width, height: SongActionSheetView.frameHeight)) {
            songActionSheetView.display(playable: song)
            headerView.addSubview(songActionSheetView)
            alert.view.addSubview(headerView)
        }
        if song.isCached || appDelegate.persistentStorage.settings.isOnlineMode {
            alert.addAction(UIAlertAction(title: "Play", style: .default, handler: { _ in
                self.appDelegate.player.play(playable: song)
                }))
                alert.addAction(UIAlertAction(title: "Add to play next", style: .default, handler: { _ in
                self.appDelegate.player.addToPlaylist(playable: song)
            }))
        }
        if appDelegate.persistentStorage.settings.isOnlineMode {
            alert.addAction(UIAlertAction(title: "Add to playlist", style: .default, handler: { _ in
                let selectPlaylistVC = PlaylistSelectorVC.instantiateFromAppStoryboard()
                selectPlaylistVC.itemsToAdd = [song]
                let selectPlaylistNav = UINavigationController(rootViewController: selectPlaylistVC)
                rootView.present(selectPlaylistNav, animated: true, completion: nil)
            }))
        }
        if song.isCached {
            alert.addAction(UIAlertAction(title: "Remove from cache", style: .default, handler: { _ in
                self.appDelegate.library.deleteCache(ofPlayable: song)
                self.appDelegate.library.saveContext()
                self.refresh()
            }))
        } else if appDelegate.persistentStorage.settings.isOnlineMode {
            alert.addAction(UIAlertAction(title: "Download", style: .default, handler: { _ in
                self.appDelegate.playableDownloadManager.download(object: song)
                self.refresh()
            }))
        }
        if let artist = song.artist {
            alert.addAction(UIAlertAction(title: "Show artist", style: .default, handler: { _ in
                self.appDelegate.userStatistics.usedAction(.alertGoToArtist)
                let artistDetailVC = ArtistDetailVC.instantiateFromAppStoryboard()
                artistDetailVC.artist = artist
                if let navController = self.rootView?.navigationController {
                    navController.pushViewController(artistDetailVC, animated: true)
                }
            }))
        }
        if let album = song.album {
            alert.addAction(UIAlertAction(title: "Show album", style: .default, handler: { _ in
                self.appDelegate.userStatistics.usedAction(.alertGoToAlbum)
                let albumDetailVC = AlbumDetailVC.instantiateFromAppStoryboard()
                albumDetailVC.album = album
                if let navController = self.rootView?.navigationController {
                    navController.pushViewController(albumDetailVC, animated: true)
                }
            }))
        }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.pruneNegativeWidthConstraintsToAvoidFalseConstraintWarnings()
        return alert
    }

}
