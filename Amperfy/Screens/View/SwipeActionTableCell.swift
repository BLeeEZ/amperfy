import UIKit

class SwipeActionTableCell: BasicTableCell {
    
    @IBOutlet weak var nameLabel: MarqueeLabel!
    @IBOutlet weak var actionImage: UIImageView!
    
    static let rowHeight: CGFloat = 50.0
    
    func display(action: SwipeActionType) {
        nameLabel.applyAmperfyStyle()
        nameLabel.text = action.settingsName
        actionImage.image = action.image
    }

}
