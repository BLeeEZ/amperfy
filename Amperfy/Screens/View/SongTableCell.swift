import UIKit
import AudioToolbox

class SongTableCell: BasicTableCell {
    
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var artistLabel: UILabel!
    @IBOutlet weak var entityImage: EntityImageView!
    
    static let rowHeight: CGFloat = 48 + margin.bottom + margin.top
    
    var song: Song?
    var rootView: UITableViewController?
    var playContextCb: GetPlayContextFromTableCellCallback?
    private var isAlertPresented = false

    override func awakeFromNib() {
        super.awakeFromNib()
        playContextCb = nil
        let longPressGesture = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPressGesture))
        self.addGestureRecognizer(longPressGesture)
    }
    
    func display(song: Song, playContextCb: @escaping GetPlayContextFromTableCellCallback, rootView: UITableViewController) {
        self.song = song
        self.playContextCb = playContextCb
        self.rootView = rootView
        refresh()
    }
    
    func refresh() {
        guard let song = song else { return }
        titleLabel.attributedText = NSMutableAttributedString(string: song.title, attributes: [NSAttributedString.Key.font: UIFont.systemFont(ofSize: 17)])
        artistLabel.text = song.creatorName
        
        entityImage.display(container: song)

        if song.isCached {
            artistLabel.textColor = UIColor.defaultBlue
        } else {
            artistLabel.textColor = UIColor.secondaryLabelColor
        }
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let song = song, let context = playContextCb?(self) else { return }

        if !isAlertPresented && (song.isCached || appDelegate.persistentStorage.settings.isOnlineMode) {
            hideSearchBarKeyboardInRootView()
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
            appDelegate.player.play(context: context)
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
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
        guard let song = song, let rootView = rootView else { return }
        isAlertPresented = true
        let detailVC = LibraryEntityDetailVC()
        detailVC.display(container: song, on: rootView, playContextCb: {() in self.playContextCb?(self)})
        rootView.present(detailVC, animated: true)
    }

}
