import UIKit

class RoundedImage: UIImageView {
    
    static let cornerRadius: CGFloat = 5.0

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        configureStyle()
    }
    
    func configureStyle() {
        layer.cornerRadius = Self.cornerRadius
        layer.masksToBounds = true
    }
    
}
