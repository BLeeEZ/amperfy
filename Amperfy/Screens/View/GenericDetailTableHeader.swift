import UIKit

class GenericDetailTableHeader: UIView {
    
    @IBOutlet weak var entityImage: EntityImageView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var subtitleView: UIView!
    @IBOutlet weak var subtitleLabel: UILabel!
    @IBOutlet weak var infoLabel: UILabel!
    
    static let frameHeight: CGFloat = 200.0
    static let margin = UIView.defaultMarginTopElement
    
    private var entityContainer: PlayableContainable?
    private var appDelegate: AppDelegate!
    private var rootView: BasicTableViewController?
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        appDelegate = (UIApplication.shared.delegate as! AppDelegate)
        self.layoutMargins = Self.margin
    }
    
    func prepare(toWorkOn entityContainer: PlayableContainable?, rootView: BasicTableViewController? ) {
        guard let entityContainer = entityContainer else { return }
        self.entityContainer = entityContainer
        self.rootView = rootView
        titleLabel.setContentCompressionResistancePriority(.required, for: .vertical)
        subtitleLabel.setContentCompressionResistancePriority(.required, for: .vertical)
        infoLabel.setContentCompressionResistancePriority(.required, for: .vertical)
        refresh()
    }
        
    func refresh() {
        guard let entityContainer = entityContainer else { return }
        entityImage.display(container: entityContainer)
        titleLabel.text = entityContainer.name
        subtitleView.isHidden = entityContainer.subtitle == nil
        subtitleLabel.text = entityContainer.subtitle
        let infoText = entityContainer.info(for: appDelegate.backendProxy.selectedApi, type: .long)
        infoLabel.isHidden = infoText.isEmpty
        infoLabel.text = infoText
    }
    
    @IBAction func subtitleButtonPressed(_ sender: Any) {
        guard let album = entityContainer as? Album,
              let artist = album.artist,
              let navController = self.rootView?.navigationController
        else { return }
        self.appDelegate.userStatistics.usedAction(.alertGoToAlbum)
        let artistDetailVC = ArtistDetailVC.instantiateFromAppStoryboard()
        artistDetailVC.artist = artist
        navController.pushViewController(artistDetailVC, animated: true)
    }
    
}
