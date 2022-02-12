import UIKit
import AudioToolbox

typealias GetPlayContextFromTableCellCallback = (UITableViewCell) -> PlayContext?
typealias GetPlayerIndexFromTableCellCallback = (PlayableTableCell) -> PlayerIndex?

class PlayableTableCell: BasicTableCell {
    
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var artistLabel: UILabel!
    @IBOutlet weak var artworkImage: LibraryEntityImage!
    @IBOutlet weak var downloadProgress: UIProgressView!
    @IBOutlet weak var reorderLabel: UILabel?
    
    static let rowHeight: CGFloat = 48 + margin.bottom + margin.top
    
    private var playerIndexCb: GetPlayerIndexFromTableCellCallback?
    private var playContextCb: GetPlayContextFromTableCellCallback?
    private var playable: AbstractPlayable?
    private var download: Download?
    private var rootView: UIViewController?
    private var isAlertPresented = false

    override func awakeFromNib() {
        super.awakeFromNib()
        let longPressGesture = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPressGesture))
        self.addGestureRecognizer(longPressGesture)
    }
    
    func display(playable: AbstractPlayable, playContextCb: @escaping GetPlayContextFromTableCellCallback, rootView: UIViewController, playerIndexCb: GetPlayerIndexFromTableCellCallback? = nil, download: Download? = nil) {
        self.playable = playable
        self.playContextCb = playContextCb
        self.playerIndexCb = playerIndexCb
        self.rootView = rootView
        self.download = download
        refresh()
    }
    
    func refresh() {
        guard let playable = playable else { return }
        titleLabel.attributedText = NSMutableAttributedString(string: playable.title, attributes: [NSAttributedString.Key.font: UIFont.systemFont(ofSize: 17)])
        
        artistLabel.text = playable.creatorName
        artworkImage.displayAndUpdate(entity: playable)
        
        if playerIndexCb != nil {
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
        } else if playerIndexCb != nil {
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
        if let playerIndex = playerIndexCb?(self), !isAlertPresented {
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
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
        guard let playable = playable, let rootView = rootView, rootView.presentingViewController == nil else { return }
        isAlertPresented = true
        let detailVC = LibraryEntityDetailVC()
        let playContextLambda = {() in self.playContextCb?(self)}
        let playerIndexLambda = playerIndexCb != nil ? {() in self.playerIndexCb?(self)} : nil
        detailVC.display(
            container: playable,
            on: rootView,
            playContextCb: playContextLambda,
            playerIndexCb: playerIndexLambda)
        rootView.present(detailVC, animated: true)
    }

}
