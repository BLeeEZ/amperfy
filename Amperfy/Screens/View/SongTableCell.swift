import UIKit
import AudioToolbox

enum BehaviourOnTab {
    case playAndErasePlaylist
    case playAndKeepPlaylist
}

class SongTableCell: UITableViewCell {
    
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var artistLabel: UILabel!
    @IBOutlet weak var cloudSyncedLabel: UILabel!
    @IBOutlet weak var artworkImage: UIImageView!
    @IBOutlet weak var downloadProgress: UIProgressView!
    
    static let rowHeight: CGFloat = 56.0
    var behaviourOnTab: BehaviourOnTab = .playAndErasePlaylist
    var forceTouchDisplayMode: SongOperationDisplayModes = .fullSet
    var isUserTouchInteractionAllowed = true
    private var appDelegate: AppDelegate!
    private var song: Song?
    private var download: Download?
    private var index: Int?
    private var rootView: UIViewController?
    private var isAlertPresented = false

    override func awakeFromNib() {
        super.awakeFromNib()
        appDelegate = (UIApplication.shared.delegate as! AppDelegate)
        
        let longPressGesture = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPressGesture))
        self.addGestureRecognizer(longPressGesture)
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
    }
    
    func display(song: Song, rootView: UIViewController, download: Download? = nil) {
        self.song = song
        self.rootView = rootView
        self.download = download
        refresh()
    }
    
    func refresh() {
        guard let song = song else { return }
        titleLabel.attributedText = NSMutableAttributedString(string: song.title, attributes: [NSAttributedString.Key.font: UIFont.systemFont(ofSize: 17)])
        artistLabel.text = song.artist?.name
        artworkImage.image = song.image
        if song.isCached {
            cloudSyncedLabel.text = FontAwesomeIcon.Cloud.asString
        } else {
            cloudSyncedLabel.text = ""
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
        behaviourOnTab = .playAndKeepPlaylist
        forceTouchDisplayMode = .onlySeperatePlaylists
    }
    
    func displayAsPlaying() {
        let attributedText = NSMutableAttributedString(string: FontAwesomeIcon.VolumeUp.asString + " ", attributes: [NSAttributedString.Key.font: UIFont(name: FontAwesomeIcon.VolumeUp.fontName, size: 17)!])
        attributedText.append(NSMutableAttributedString(string: titleLabel.text ?? "", attributes: [NSAttributedString.Key.font: UIFont.systemFont(ofSize: 17)]))
        titleLabel.attributedText = attributedText
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let song = song else { return }
        if isUserTouchInteractionAllowed, !isAlertPresented {
            switch behaviourOnTab {
            case .playAndErasePlaylist:
                appDelegate.player.play(song: song)
            case .playAndKeepPlaylist:
                guard let index = index else { return }
                appDelegate.player.play(songInPlaylistAt: index)
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
            let alert = createAlert(forSong: song, rootView: rootView, displayMode: forceTouchDisplayMode)
            alert.setOptionsForIPadToDisplayPopupCentricIn(view: rootView.view)
            rootView.present(alert, animated: true, completion: nil)
        }
    }
    
    func createAlert(forSong song: Song, rootView: UIViewController, displayMode: SongOperationDisplayModes) -> UIAlertController {
        let alert = UIAlertController(title: "\n\n\n", message: nil, preferredStyle: .actionSheet)
    
        if let (fixedView, songView) = ViewBuilder<SongActionSheetView>.createFromNib(withinFixedFrame: CGRect(x: 0, y: 0, width: alert.view.bounds.size.width-30, height: SongActionSheetView.frameHeight)) {
            songView.display(song: song)
            alert.view.addSubview(fixedView)
        }
    
        if displayMode != .onlySeperatePlaylists {
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
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.pruneNegativeWidthConstraintsToAvoidFalseConstraintWarnings()
        return alert
    }

}
