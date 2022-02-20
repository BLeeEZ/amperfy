import UIKit

class FullWidthDescriptionView: UIView {
    
    @IBOutlet weak var descriptionLabel: UILabel!
    
    static let frameHeight: CGFloat = 85.0
    static let margin = UIView.defaultMarginTopElement
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        self.layoutMargins = Self.margin
    }
}
