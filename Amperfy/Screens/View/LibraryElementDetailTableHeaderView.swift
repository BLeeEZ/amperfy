import UIKit

class LibraryElementDetailTableHeaderView: UIView {
    
    @IBOutlet weak var playAllButton: UIButton!
    @IBOutlet weak var playShuffledButton: UIButton!
    
    static let frameHeight: CGFloat = 30.0 + margin.top + margin.bottom
    static let margin = UIView.defaultMarginMiddleElement
    
    private var appDelegate: AppDelegate!
    private var playContextCb: GetPlayContextCallback?
    private var player: PlayerFacade?
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        appDelegate = (UIApplication.shared.delegate as! AppDelegate)
        self.layoutMargins = Self.margin
    }
    
    @IBAction func playAllButtonPressed(_ sender: Any) {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        play(isShuffled: false)
    }
    
    @IBAction func addAllShuffledButtonPressed(_ sender: Any) {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        play(isShuffled: true)
    }
    
    private func play(isShuffled: Bool) {
        guard let playContext = playContextCb?(), let player = player else { return }
        isShuffled ? player.playShuffled(context: playContext) : player.play(context: playContext)
    }
    
    func prepare(playContextCb: GetPlayContextCallback?, with player: PlayerFacade) {
        self.playContextCb = playContextCb
        self.player = player
        playAllButton.setImage(UIImage(named: "play")?.invertedImage(), for: .normal)
        playAllButton.imageView?.contentMode = .scaleAspectFit
        playShuffledButton.setImage(UIImage(named: "shuffle")?.invertedImage(), for: .normal)
        playShuffledButton.imageView?.contentMode = .scaleAspectFit
    }
    
}
