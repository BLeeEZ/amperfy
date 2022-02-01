import UIKit

class PopupPlayerSectionHeader: UIView {

    @IBOutlet weak var nameLabel: MarqueeLabel!
    @IBOutlet weak var rightButton: UIButton!
    
    @IBOutlet weak var labelRightGapToButtonConstraint: NSLayoutConstraint!
    @IBOutlet weak var labelRightGapToSafeAreaTrailingConstraint: NSLayoutConstraint!
    
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
    
    func display(name: String, buttonTitle: String = "", buttonPressAction: (() -> Void)? = nil) {
        nameLabel.text = name
        nameLabel.applyAmperfyStyle()
        rightButton.setTitle("", for: .disabled)
        rightButton.setTitle(buttonTitle, for: .normal)
        self.buttonPressAction = buttonPressAction
        rightButton.isEnabled = buttonPressAction != nil
        rightButton.backgroundColor = buttonPressAction != nil ? UIColor.defaultBlue : UIColor.clear
        labelRightGapToButtonConstraint.isActive = buttonPressAction != nil
        labelRightGapToSafeAreaTrailingConstraint.isActive = buttonPressAction == nil
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
