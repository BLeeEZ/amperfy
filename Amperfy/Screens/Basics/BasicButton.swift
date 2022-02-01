import UIKit

class BasicButton: UIButton {
    
    static let cornerRadius = 10.0

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        configureStyle()
    }
    
    func configureStyle() {
        layer.cornerRadius = Self.cornerRadius
    }

}
