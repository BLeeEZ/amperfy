import UIKit
import AudioToolbox

enum SongActionOnTab: Int {
    case playAndErasePlaylist = 0
    case hiddenOptionPlayInPopupPlayerPlaylistSelectedSong = 1
    case addToPlaylistAndPlay = 2
    case insertAsNextSongNoPlay = 3
    
    static let defaultValue: SongActionOnTab = .addToPlaylistAndPlay
    
    var description : String {
        switch self {
        case .playAndErasePlaylist: return "Clear current playlist and play song"
        case .addToPlaylistAndPlay: return "Insert song at the end and play song"
        case .insertAsNextSongNoPlay: return "Insert as next song to play"
        case .hiddenOptionPlayInPopupPlayerPlaylistSelectedSong: return "HIDDEN !!!"
        }
    }
}

class SongTableCell: BasicTableCell {
    
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var artistLabel: UILabel!
    @IBOutlet weak var artworkImage: UIImageView!
    @IBOutlet weak var downloadProgress: UIProgressView!
    @IBOutlet weak var reorderLabel: UILabel?
    
    static let rowHeight: CGFloat = 48 + margin.bottom + margin.top
    
    var displayMode: SongOperationDisplayModes = .libraryCell
    var isUserTouchInteractionAllowed = true
    private var song: Song?
    private var download: Download?
    private var index: Int?
    public var indexInPlaylist: Int? {
        return index
    }
    private var rootView: UIViewController?
    private var isAlertPresented = false
    private var isCellInPopupPlayer = false

    override func awakeFromNib() {
        super.awakeFromNib()
        isCellInPopupPlayer = false
        let longPressGesture = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPressGesture))
        self.addGestureRecognizer(longPressGesture)
    }
    
    func display(song: Song, rootView: UIViewController, displayMode: SongOperationDisplayModes = .libraryCell, download: Download? = nil) {
        self.song = song
        self.rootView = rootView
        self.displayMode = displayMode
        self.download = download
        refresh()
    }
    
    func refresh() {
        guard let song = song else { return }
        titleLabel.attributedText = NSMutableAttributedString(string: song.title, attributes: [NSAttributedString.Key.font: UIFont.systemFont(ofSize: 17)])
        artistLabel.text = song.artist?.name
        artworkImage.image = song.image
        if let reorderLabel = self.reorderLabel {
            if displayMode == .playerCell {
                reorderLabel.attributedText = NSMutableAttributedString(string: FontAwesomeIcon.Bars.asString, attributes: [NSAttributedString.Key.font: UIFont(name: FontAwesomeIcon.fontName, size: 17)!])
            } else {
                reorderLabel.removeFromSuperview()
            }
        }
        if song.isCached {
            artistLabel.textColor = UIColor.defaultBlue
        } else if isCellInPopupPlayer {
            artistLabel.textColor = UIColor.labelColor
        } else {
            artistLabel.textColor = UIColor.secondaryLabelColor
        }
        if let download = download {
            downloadProgress.isHidden = false
            downloadProgress.progress = download.progress
        } else {
            downloadProgress.isHidden = true
        }
    }
    
    func confToPlayPlaylistIndexOnTab(indexInPlaylist: Int) {
        self.index = indexInPlaylist
        isCellInPopupPlayer = true
        refresh()
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let song = song else { return }
        
        let behaviourOnTab = isCellInPopupPlayer ? .hiddenOptionPlayInPopupPlayerPlaylistSelectedSong :  appDelegate.storage.getSettings().songActionOnTab
        
        if isUserTouchInteractionAllowed, !isAlertPresented {
            switch behaviourOnTab {
            case .playAndErasePlaylist:
                appDelegate.player.play(song: song)
            case .hiddenOptionPlayInPopupPlayerPlaylistSelectedSong:
                guard let index = index else { return }
                appDelegate.player.play(songInPlaylistAt: index)
            case .addToPlaylistAndPlay:
                appDelegate.player.addToPlaylist(song: song)
                let indexInPlayerPlaylist = appDelegate.player.playlist.songs.count-1
                appDelegate.player.play(songInPlaylistAt: indexInPlayerPlaylist)
            case .insertAsNextSongNoPlay:
                appDelegate.player.addToPlaylist(song: song)
                let addedSongIndexInPlayerPlaylist = appDelegate.player.playlist.songs.count-1
                if let curPlayingIndex = appDelegate.player.currentlyPlaying?.index {
                    appDelegate.player.movePlaylistSong(fromIndex: addedSongIndexInPlayerPlaylist, to: curPlayingIndex+1)
                }
            }
        }
        isAlertPresented = false
    }
    
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        isAlertPresented = false
    }
    
    @objc func handleLongPressGesture(gesture: UILongPressGestureRecognizer) -> Void {
        if isUserTouchInteractionAllowed, gesture.state == .began {
            displayMenu()
        }
    }
    
    func displayMenu() {
        if let song = song, let rootView = rootView, rootView.presentingViewController == nil {
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
            isAlertPresented = true
            let alert = createAlert(forSong: song, rootView: rootView, displayMode: displayMode)
            alert.setOptionsForIPadToDisplayPopupCentricIn(view: rootView.view)
            rootView.present(alert, animated: true, completion: nil)
        }
    }
    
    func createAlert(forSong song: Song, rootView: UIViewController, displayMode: SongOperationDisplayModes) -> UIAlertController {
        let alert = UIAlertController(title: "\n\n\n", message: nil, preferredStyle: .actionSheet)
    
        let headerView = UIView(frame: CGRect(x: 0, y: 0, width: alert.view.bounds.size.width, height: SongActionSheetView.frameHeight))
        if let songActionSheetView = ViewBuilder<SongActionSheetView>.createFromNib(withinFixedFrame: CGRect(x: 0, y: 0, width: alert.view.bounds.size.width, height: SongActionSheetView.frameHeight)) {
            songActionSheetView.display(song: song)
            headerView.addSubview(songActionSheetView)
            alert.view.addSubview(headerView)
        }
    
        if displayMode != .playerCell {
            alert.addAction(UIAlertAction(title: "Play", style: .default, handler: { _ in
                self.appDelegate.player.play(song: song)
                }))
                alert.addAction(UIAlertAction(title: "Add to play next", style: .default, handler: { _ in
                self.appDelegate.player.addToPlaylist(song: song)
            }))
        }
        alert.addAction(UIAlertAction(title: "Add to playlist", style: .default, handler: { _ in
            let selectPlaylistVC = PlaylistSelectorVC.instantiateFromAppStoryboard()
            selectPlaylistVC.songToAdd = song
            let selectPlaylistNav = UINavigationController(rootViewController: selectPlaylistVC)
            rootView.present(selectPlaylistNav, animated: true, completion: nil)
        }))
        if song.isCached {
            alert.addAction(UIAlertAction(title: "Remove from cache", style: .default, handler: { _ in
                self.appDelegate.persistentLibraryStorage.deleteCache(ofSong: song)
                self.refresh()
            }))
        } else {
            alert.addAction(UIAlertAction(title: "Download", style: .default, handler: { _ in
                self.appDelegate.downloadManager.download(song: song)
                self.refresh()
            }))
        }
        alert.addAction(UIAlertAction(title: "Show artist", style: .default, handler: { _ in
            let artistDetailVC = ArtistDetailVC.instantiateFromAppStoryboard()
            artistDetailVC.artist = song.artist
            if let navController = self.rootView?.navigationController {
                navController.pushViewController(artistDetailVC, animated: true)
            } else {
                self.closePopupPlayerAndDisplayInLibraryTab(view: artistDetailVC)
            }
        }))
        alert.addAction(UIAlertAction(title: "Show album", style: .default, handler: { _ in
            let albumDetailVC = AlbumDetailVC.instantiateFromAppStoryboard()
            albumDetailVC.album = song.album
            if let navController = self.rootView?.navigationController {
                navController.pushViewController(albumDetailVC, animated: true)
            } else {
                self.closePopupPlayerAndDisplayInLibraryTab(view: albumDetailVC)
            }
        }))
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.pruneNegativeWidthConstraintsToAvoidFalseConstraintWarnings()
        return alert
    }
    
    private func closePopupPlayerAndDisplayInLibraryTab(view: UIViewController) {
        if let popupPlayerVC = rootView as? PopupPlayerVC,
           let hostingTabBarVC = popupPlayerVC.hostingTabBarVC {
            hostingTabBarVC.closePopup(animated: true, completion: { () in
                if let hostingTabViewControllers = hostingTabBarVC.viewControllers,
                   hostingTabViewControllers.count > 0,
                   let libraryTabNavVC = hostingTabViewControllers[0] as? UINavigationController {
                    libraryTabNavVC.pushViewController(view, animated: false)
                    hostingTabBarVC.selectedIndex = 0
                }
            })
        }
    }

}
