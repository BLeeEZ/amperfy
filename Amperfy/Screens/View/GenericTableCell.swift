import UIKit
import AmperfyKit

class GenericTableCell: BasicTableCell {
    
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var subtitleLabel: UILabel!
    @IBOutlet weak var entityImage: EntityImageView!
    @IBOutlet weak var infoLabel: UILabel!
    
    static let rowHeight: CGFloat = 48.0 + margin.bottom + margin.top
    static let rowHeightWithoutImage: CGFloat = 28.0 + margin.bottom + margin.top
    
    private var container: PlayableContainable?
    private var rootView: UITableViewController?
    
    override func awakeFromNib() {
        super.awakeFromNib()
        let longPressGesture = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPressGesture))
        self.addGestureRecognizer(longPressGesture)
    }
    
    func display(container: PlayableContainable, rootView: UITableViewController) {
        self.container = container
        self.rootView = rootView
        titleLabel.text = container.name
        subtitleLabel.isHidden = container.subtitle == nil
        subtitleLabel.text = container.subtitle
        entityImage.display(container: container)
        let infoText = container.info(for: appDelegate.backendProxy.selectedApi, type: .short)
        infoLabel.isHidden = infoText.isEmpty
        infoLabel.text = infoText
    }

    @objc func handleLongPressGesture(gesture: UILongPressGestureRecognizer) -> Void {
        if gesture.state == .began {
            displayMenu()
        }
    }
    
    func displayMenu() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
        guard let container = container, let rootView = rootView else { return }
        let detailVC = LibraryEntityDetailVC()
        detailVC.display(container: container, on: rootView)
        rootView.present(detailVC, animated: true)
    }
    
}
