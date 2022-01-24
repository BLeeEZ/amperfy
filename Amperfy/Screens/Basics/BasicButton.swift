import UIKit

class BasicButton: UIButton {

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        configureStyle()
    }
    
    func configureStyle() {
        layer.cornerRadius = 10
    }

}
