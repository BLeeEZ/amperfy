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
                appDelegate.player.appendToNextInMainQueueAndPlay(playable: song)
            case .insertAsNextSongNoPlay:
                appDelegate.player.insertFirstToNextInMainQueue(playables: [song])
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
            let detailVC = LibraryEntityDetailVC()
            detailVC.display(playable: song, on: rootView)
            rootView.present(detailVC, animated: true)
        }
    }

}
