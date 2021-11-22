import UIKit

class PopupPlayerSectionHeader: UIView {

    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var rightButton: UIButton!
    
    static let frameHeight: CGFloat = 40.0 + margin.top + margin.bottom
    static let margin = UIEdgeInsets(top: 8, left: UIView.defaultMarginX, bottom: 0, right: UIView.defaultMarginX)
    
    private var appDelegate: AppDelegate!
    private var buttonPressAction: (() -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        appDelegate = (UIApplication.shared.delegate as! AppDelegate)
        self.layoutMargins = Self.margin
    }
    
    func display(type: PlayerQueueType, buttonTitle: String = "", buttonPressAction: (() -> Void)? = nil) {
        nameLabel.text = type.description
        rightButton.setTitle("", for: .disabled)
        rightButton.setTitle(buttonTitle, for: .normal)
        self.buttonPressAction = buttonPressAction
        rightButton.isEnabled = buttonPressAction != nil
        rightButton.backgroundColor = buttonPressAction != nil ? UIColor.defaultBlue : UIColor.clear
    }
    
    func hide() {
        nameLabel.text = ""
        rightButton.isEnabled = false
        rightButton.backgroundColor =  UIColor.clear
    }

    @IBAction func rightButtonPressed(_ sender: Any) {
        if let buttonAction = buttonPressAction {
            buttonAction()
        }
    }

}
