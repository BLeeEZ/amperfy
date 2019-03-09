import UIKit

class RoundedImage: UIImageView {

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        configureStyle()
    }
    
    func configureStyle() {
        layer.cornerRadius = 5
        layer.masksToBounds = true
    }
    
}
