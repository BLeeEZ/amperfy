import Foundation
import UIKit

class LibrarySyncPopupVC: UIViewController {
    
    @IBOutlet weak var syncIcon: UILabel!
    @IBOutlet weak var titelLabel: UILabel!
    @IBOutlet weak var infoLabel: UILabel!
    @IBOutlet weak var contentView: UIView!
    
    var appDelegate: AppDelegate!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        appDelegate = (UIApplication.shared.delegate as! AppDelegate)
        
        titelLabel.text = "Synchronisation"
        infoLabel.text = "Your music collection is constantly updating. Already synced libray items are offline available. If library items (artists/albums/songs) are not shown in your  collection please use the various search functionalities to synchronise with the server."
        contentView.layer.cornerRadius = 15
        showAsAnimatedPopup()
        animateSyncIcon()
    }
    
    @IBAction func closeButtonPressed(_ sender: Any) {
        self.appDelegate.persistentStorage.isLibrarySyncInfoReadByUser = true
        removeAsAnimatedPopup()
    }
    
    func animateSyncIcon() {
        UIView.animate(withDuration: 5, delay: 0, options: .repeat, animations: ({
            self.syncIcon.transform = CGAffineTransform(rotationAngle: CGFloat.pi)
        }), completion: nil)
    }
    
    func showAsAnimatedPopup() {
        self.view.transform = CGAffineTransform(scaleX: 1.3, y: 1.3)
        self.view.alpha = 0.0;
        UIView.animate(withDuration: 0.25, animations: {
            self.view.alpha = 1.0
            self.view.transform = CGAffineTransform(scaleX: 1.0, y: 1.0)
        });
    }
    
    func removeAsAnimatedPopup() {
        UIView.animate(withDuration: 0.25, animations: {
            self.view.transform = CGAffineTransform(scaleX: 1.3, y: 1.3)
            self.view.alpha = 0.0;
            }, completion: { (finished : Bool) in
                if (finished) {
                    self.view.removeFromSuperview()
                }
        });
    }
    
}
