import UIKit

class PopupPlayerSectionHeader: UIView {

    @IBOutlet weak var nameLabel: MarqueeLabel!
    @IBOutlet weak var rightButton: UIButton!
    
    @IBOutlet weak var labelTrailingToSuperviewTrailingConstraint: NSLayoutConstraint!
    @IBOutlet weak var rightButtonWidthConstraint: NSLayoutConstraint!
    
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
        nameLabel.isHidden = false
        nameLabel.applyAmperfyStyle()
        rightButton.setTitle("", for: .disabled)
        rightButton.setTitle(buttonTitle, for: .normal)
        self.buttonPressAction = buttonPressAction
        rightButton.isHidden = buttonPressAction == nil
        rightButton.isEnabled = buttonPressAction != nil
        rightButton.backgroundColor = buttonPressAction != nil ? UIColor.defaultBlue : UIColor.clear
        if buttonPressAction != nil {
            labelTrailingToSuperviewTrailingConstraint.constant = rightButtonWidthConstraint.constant + 16.0
        } else {
            labelTrailingToSuperviewTrailingConstraint.constant = 0
        }
    }
    
    func hide() {
        nameLabel.text = ""
        nameLabel.isHidden = true
        rightButton.isHidden = true
        rightButton.isEnabled = false
        rightButton.backgroundColor =  UIColor.clear
        labelTrailingToSuperviewTrailingConstraint.constant = 0
    }

    @IBAction func rightButtonPressed(_ sender: Any) {
        if let buttonAction = buttonPressAction {
            buttonAction()
        }
    }

}
