import Foundation
import UIKit

enum PopupIconAnimation {
    case rotate
    case zoomInZoomOut
}

class LibrarySyncPopupVC: UIViewController {
    
    @IBOutlet weak var iconLabel: UILabel!
    @IBOutlet weak var iconBackgroundLabel: UILabel!
    @IBOutlet weak var titelLabel: UILabel!
    @IBOutlet weak var infoLabel: UILabel!
    @IBOutlet weak var optionalButton: BasicButton!
    @IBOutlet weak var contentView: UIView!
    
    var appDelegate: AppDelegate!
    private var topic = ""
    private var message = ""
    private var popupColor = UIColor.systemBlue
    private var icon = FontAwesomeIcon.Sync
    private var iconAnimation = PopupIconAnimation.zoomInZoomOut
    private var closeButtonOnPressed: ((Bool) -> Void)?
    private var optionalButtonText: String?
    private var optionalButtonOnPressed: ((Bool) -> Void)?
    private var onClosedHandler: ((Bool) -> Void)?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        appDelegate = (UIApplication.shared.delegate as! AppDelegate)
        
        titelLabel.text = topic
        infoLabel.text = message
        if let btnText = optionalButtonText {
            optionalButton.setTitle(btnText, for: .normal)
        } else {
            optionalButton.removeFromSuperview()
        }
        iconLabel.layer.cornerRadius = iconLabel.frame.width / 2
        iconLabel.layer.masksToBounds = true
        iconBackgroundLabel.layer.cornerRadius = iconLabel.frame.width / 2
        iconBackgroundLabel.layer.masksToBounds = true
        contentView.layer.cornerRadius = 15
        
        self.contentView.backgroundColor = popupColor
        self.iconLabel.backgroundColor = .clear
        self.iconBackgroundLabel.backgroundColor = popupColor
        
        iconLabel.text = icon.asString
        switch iconAnimation {
        case .rotate:
            animateIconRotation()
        case .zoomInZoomOut:
            animateIconZoomInZoomOut()
        }
        
        showAsAnimatedPopup()
    }
    
    @IBAction func closeButtonPressed(_ sender: Any) {
        self.closeButtonOnPressed?(true)
        removeAsAnimatedPopup()
    }
    
    @IBAction func optionalButtonPressed(_ sender: Any) {
        self.optionalButtonOnPressed?(true)
        removeAsAnimatedPopup()
    }
    
    func setContent(topic: String, message: String, type: LogEntryType, customIcon: FontAwesomeIcon? = nil, customAnimation: PopupIconAnimation? = nil, onClosePressed: ((Bool) -> Void)? = nil) {
        self.topic = topic
        self.message = message
        self.closeButtonOnPressed = onClosePressed
        
        self.iconAnimation = customAnimation != nil ? customAnimation! : .zoomInZoomOut
        switch type {
        case .apiError:
            popupColor = .red
            self.icon = customIcon != nil ? customIcon! : .Exclamation
        case .error:
            popupColor = .red
            self.icon = customIcon != nil ? customIcon! : .Exclamation
        case .info:
            popupColor = .defaultBlue
            self.icon = customIcon != nil ? customIcon! : .Info
        case .debug:
            popupColor = .systemGray
            self.icon = customIcon != nil ? customIcon! : .Info
        }
    }
    
    func useOptionalButton(text: String, onPressed: ((Bool) -> Void)? = nil) {
        self.optionalButtonText = text
        self.optionalButtonOnPressed = onPressed
    }
    
    func display(on hostVC: UIViewController, onClose: ((Bool) -> Void)? = nil) {
        onClosedHandler = onClose
        hostVC.addChild(self)
        self.view.frame = hostVC.view.frame
        hostVC.view.addSubview(self.view)
        self.didMove(toParent: hostVC)
    }
    
    private func animateIconRotation() {
        UIView.animate(withDuration: 5, delay: 0, options: .repeat, animations: ({
            self.iconLabel.transform = CGAffineTransform(rotationAngle: CGFloat.pi)
        }), completion: nil)
    }
    
    private func animateIconZoomInZoomOut() {
        UIView.animate(withDuration: 3, delay: 0, options: [], animations: ({
            self.iconLabel.transform = CGAffineTransform(scaleX: 1.1, y: 1.1)
        }), completion: nil)
        UIView.animate(withDuration: 3, delay: 3, options: [.repeat, .autoreverse], animations: ({
            self.iconLabel.transform = CGAffineTransform(scaleX: 0.9, y: 0.9)
        }), completion: nil)
    }
    
    private func showAsAnimatedPopup() {
        self.view.transform = CGAffineTransform(scaleX: 1.3, y: 1.3)
        self.view.alpha = 0.0;
        UIView.animate(withDuration: 0.25, animations: {
            self.view.alpha = 1.0
            self.view.transform = CGAffineTransform(scaleX: 1.0, y: 1.0)
        });
    }
    
    private func removeAsAnimatedPopup() {
        UIView.animate(withDuration: 0.25, animations: {
            self.view.transform = CGAffineTransform(scaleX: 1.3, y: 1.3)
            self.view.alpha = 0.0;
            }, completion: { (finished : Bool) in
                if (finished) {
                    self.view.removeFromSuperview()
                    self.onClosedHandler?(true)
                }
        });
    }
    
}
