import UIKit

class GenericDetailTableHeader: UIView {
    
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var entityImage: EntityImageView!
    @IBOutlet weak var infoLabel: MarqueeLabel!
    
    static let frameHeight: CGFloat = 150.0 + margin.top + margin.bottom
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
        refresh()
    }
        
    func refresh() {
        guard let entityContainer = entityContainer else { return }
        nameLabel.text = entityContainer.name
        nameLabel.lineBreakMode = .byWordWrapping
        nameLabel.numberOfLines = 0
        entityImage.display(container: entityContainer)
        infoLabel.applyAmperfyStyle()
        infoLabel.text = entityContainer.info(for: appDelegate.backendProxy.selectedApi, type: .long)
    }

}
