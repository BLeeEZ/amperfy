import UIKit

class LibraryElementDetailTableHeaderView: UIView {
    
    @IBOutlet weak var playAllButton: UIButton!
    @IBOutlet weak var addAllToPlaylistButton: UIButton!
    
    static let frameHeight: CGFloat = 30.0 + margin.top + margin.bottom
    static let margin = UIView.defaultMarginMiddleElement
    
    private var appDelegate: AppDelegate!
    private var playableContainer: PlayableContainable?
    private var player: PlayerFacade?
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        appDelegate = (UIApplication.shared.delegate as! AppDelegate)
        self.layoutMargins = Self.margin
    }
    
    @IBAction func playAllButtonPressed(_ sender: Any) {
        guard let playableContainer = playableContainer, let player = player else { return }
        player.play(playables: playableContainer.playables.filterCached(dependigOn: appDelegate.persistentStorage.settings.isOfflineMode))
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }
    
    @IBAction func addAllToPlayNextButtonPressed(_ sender: Any) {
        guard let playableContainer = playableContainer, let player = player else { return }
        player.appendToNextInMainQueue(playables: playableContainer.playables.filterCached(dependigOn: appDelegate.persistentStorage.settings.isOfflineMode))
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }
    
    func prepare(playableContainer: PlayableContainable?, with player: PlayerFacade) {
        self.playableContainer = playableContainer
        self.player = player
    }
    
}
