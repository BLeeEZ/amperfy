import UIKit
import AudioToolbox

typealias PlayerIndexConversionCallback = (PlayableTableCell) -> PlayerIndex?

class PlayableTableCell: BasicTableCell {
    
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var artistLabel: UILabel!
    @IBOutlet weak var artworkImage: LibraryEntityImage!
    @IBOutlet weak var downloadProgress: UIProgressView!
    @IBOutlet weak var reorderLabel: UILabel?
    
    static let rowHeight: CGFloat = 48 + margin.bottom + margin.top
    
    var playerIndexConversionCallback: PlayerIndexConversionCallback?
    private var playable: AbstractPlayable?
    private var download: Download?
    private var rootView: UIViewController?
    private var isAlertPresented = false

    override func awakeFromNib() {
        super.awakeFromNib()
        playerIndexConversionCallback = nil
        let longPressGesture = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPressGesture))
        self.addGestureRecognizer(longPressGesture)
    }
    
    func display(playable: AbstractPlayable, rootView: UIViewController, download: Download? = nil) {
        self.playable = playable
        self.rootView = rootView
        self.download = download
        refresh()
    }
    
    func refresh() {
        guard let playable = playable else { return }
        titleLabel.attributedText = NSMutableAttributedString(string: playable.title, attributes: [NSAttributedString.Key.font: UIFont.systemFont(ofSize: 17)])
        
        artistLabel.text = playable.creatorName
        artworkImage.displayAndUpdate(entity: playable, via: appDelegate.artworkDownloadManager)
        
        if playerIndexConversionCallback != nil {
            self.reorderLabel?.isHidden = false
            self.reorderLabel?.attributedText = NSMutableAttributedString(string: FontAwesomeIcon.Bars.asString, attributes: [NSAttributedString.Key.font: UIFont(name: FontAwesomeIcon.fontName, size: 17)!])
        } else if download?.error != nil {
            self.reorderLabel?.isHidden = false
            self.reorderLabel?.attributedText = NSMutableAttributedString(string: FontAwesomeIcon.Exclamation.asString, attributes: [NSAttributedString.Key.font: UIFont(name: FontAwesomeIcon.fontName, size: 25)!])
        } else if download?.isFinishedSuccessfully ?? false {
            self.reorderLabel?.isHidden = false
            self.reorderLabel?.attributedText = NSMutableAttributedString(string: FontAwesomeIcon.Check.asString, attributes: [NSAttributedString.Key.font: UIFont(name: FontAwesomeIcon.fontName, size: 17)!])
        } else {
            self.reorderLabel?.isHidden = true
        }
        
        if download?.error != nil {
            artistLabel.textColor = .systemRed
        } else if playable.isCached || download?.isFinishedSuccessfully ?? false {
            artistLabel.textColor = UIColor.defaultBlue
        } else if playerIndexConversionCallback != nil {
            artistLabel.textColor = UIColor.labelColor
        } else {
            artistLabel.textColor = UIColor.secondaryLabelColor
        }
        
        if let download = download, download.isDownloading {
            downloadProgress.isHidden = false
            downloadProgress.progress = download.progress
        } else {
            downloadProgress.isHidden = true
        }
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        if let playerIndexConversionCallback = playerIndexConversionCallback, let playerIndex = playerIndexConversionCallback(self), !isAlertPresented {
            appDelegate.player.play(playerIndex: playerIndex)
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
        if let playable = playable, let rootView = rootView, rootView.presentingViewController == nil {
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
            isAlertPresented = true
            let alert = createAlert(forPlayable: playable, rootView: rootView)
            alert.setOptionsForIPadToDisplayPopupCentricIn(view: rootView.view)
            rootView.present(alert, animated: true, completion: nil)
        }
    }
    
    func createAlert(forPlayable playable: AbstractPlayable, rootView: UIViewController) -> UIAlertController {
        let alert = UIAlertController(title: "\n\n\n", message: nil, preferredStyle: .actionSheet)
    
        let headerView = UIView(frame: CGRect(x: 0, y: 0, width: alert.view.bounds.size.width, height: SongActionSheetView.frameHeight))
        if let songActionSheetView = ViewBuilder<SongActionSheetView>.createFromNib(withinFixedFrame: CGRect(x: 0, y: 0, width: alert.view.bounds.size.width, height: SongActionSheetView.frameHeight)) {
            songActionSheetView.display(playable: playable)
            headerView.addSubview(songActionSheetView)
            alert.view.addSubview(headerView)
        }
    
        if playerIndexConversionCallback == nil && (playable.isCached || appDelegate.persistentStorage.settings.isOnlineMode) {
            alert.addAction(UIAlertAction(title: "Play", style: .default, handler: { _ in
                self.appDelegate.player.play(playable: playable)
                }))
                alert.addAction(UIAlertAction(title: "Add to play next", style: .default, handler: { _ in
                self.appDelegate.player.addToPlaylist(playable: playable)
            }))
        }
        if playable.isSong && appDelegate.persistentStorage.settings.isOnlineMode {
            alert.addAction(UIAlertAction(title: "Add to playlist", style: .default, handler: { _ in
                let selectPlaylistVC = PlaylistSelectorVC.instantiateFromAppStoryboard()
                selectPlaylistVC.itemsToAdd = [playable]
                let selectPlaylistNav = UINavigationController(rootViewController: selectPlaylistVC)
                rootView.present(selectPlaylistNav, animated: true, completion: nil)
            }))
        }
        if playable.isCached {
            alert.addAction(UIAlertAction(title: "Remove from cache", style: .default, handler: { _ in
                self.appDelegate.playableDownloadManager.removeFinishedDownload(for: playable)
                self.appDelegate.library.deleteCache(ofPlayable: playable)
                self.appDelegate.library.saveContext()
                self.refresh()
            }))
        } else if appDelegate.persistentStorage.settings.isOnlineMode {
            alert.addAction(UIAlertAction(title: "Download", style: .default, handler: { _ in
                self.appDelegate.playableDownloadManager.download(object: playable)
                self.refresh()
            }))
        }
        if let song = playable.asSong, let artist = song.artist {
            alert.addAction(UIAlertAction(title: "Show artist", style: .default, handler: { _ in
                self.appDelegate.userStatistics.usedAction(.alertGoToArtist)
                let artistDetailVC = ArtistDetailVC.instantiateFromAppStoryboard()
                artistDetailVC.artist = artist
                if let navController = self.rootView?.navigationController {
                    navController.pushViewController(artistDetailVC, animated: true)
                } else if let popupPlayerVC = rootView as? PopupPlayerVC {
                    popupPlayerVC.closePopupPlayerAndDisplayInLibraryTab(vc: artistDetailVC)
                }
            }))
        }
        if let song = playable.asSong, let album = song.album {
            alert.addAction(UIAlertAction(title: "Show album", style: .default, handler: { _ in
                self.appDelegate.userStatistics.usedAction(.alertGoToAlbum)
                let albumDetailVC = AlbumDetailVC.instantiateFromAppStoryboard()
                albumDetailVC.album = album
                if let navController = self.rootView?.navigationController {
                    navController.pushViewController(albumDetailVC, animated: true)
                } else if let popupPlayerVC = rootView as? PopupPlayerVC {
                    popupPlayerVC.closePopupPlayerAndDisplayInLibraryTab(vc: albumDetailVC)
                }
            }))
        }
        if let podcastEpisode = playable.asPodcastEpisode, let podcast = podcastEpisode.podcast {
            alert.addAction(UIAlertAction(title: "Show podcast", style: .default, handler: { _ in
                self.appDelegate.userStatistics.usedAction(.alertGoToPodcast)
                let podcastDetailVC = PodcastDetailVC.instantiateFromAppStoryboard()
                podcastDetailVC.podcast = podcast
                if let navController = self.rootView?.navigationController {
                    navController.pushViewController(podcastDetailVC, animated: true)
                } else if let popupPlayerVC = rootView as? PopupPlayerVC {
                    popupPlayerVC.closePopupPlayerAndDisplayInLibraryTab(vc: podcastDetailVC)
                }
            }))
        }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.pruneNegativeWidthConstraintsToAvoidFalseConstraintWarnings()
        return alert
    }

}
