import UIKit

class OptionsButton: UIButton {

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        configureStyle()
    }
    
    func configureStyle() {
        layer.cornerRadius = 15
        self.backgroundColor = UIColor.defaultBlue
        self.tintColor = UIColor.white
        self.titleLabel?.font = UIFont.systemFont(ofSize: 26)
    }

}
