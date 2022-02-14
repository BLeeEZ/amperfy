import UIKit

class SwipeActionTableCell: BasicTableCell {
    
    @IBOutlet weak var nameLabel: MarqueeLabel!
    @IBOutlet weak var actionImage: UIImageView!
    
    private var action: SwipeActionType?
    
    static let rowHeight: CGFloat = 50.0
    
    func display(action: SwipeActionType) {
        self.action = action
        nameLabel.applyAmperfyStyle()
        nameLabel.text = action.settingsName
        refreshStyle()
    }
    
    func refreshStyle() {
        guard let action = action else { return }
        if traitCollection.userInterfaceStyle == .dark {
            actionImage.image = action.image.invertedImage()
        } else {
            actionImage.image = action.image
        }
        
    }

}
