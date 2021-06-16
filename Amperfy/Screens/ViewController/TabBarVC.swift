import UIKit
import Foundation
import LNPopupController

class TabBarVC: UITabBarController {
    
    var appDelegate: AppDelegate!

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        appDelegate = (UIApplication.shared.delegate as! AppDelegate)
        
        let popupPlayer = PopupPlayerVC.instantiateFromAppStoryboard()
        popupPlayer.hostingTabBarVC = self
        self.presentPopupBar(withContentViewController: popupPlayer, animated: true, completion: nil)
        self.popupBar.tintColor = UIColor.defaultBlue
        self.popupBar.imageView.layer.cornerRadius = 5
        self.popupBar.progressViewStyle = .bottom
        self.popupBar.barStyle = .prominent
        self.popupBar.marqueeScrollEnabled = true
        self.popupBar.subtitleTextAttributes = [NSAttributedString.Key.foregroundColor: UIColor.defaultBlue]
        self.popupContentView.popupCloseButtonStyle = .chevron
        self.popupInteractionStyle = .snap
        
        if !appDelegate.persistentStorage.isLibrarySyncInfoReadByUser {
            let popOverVC = LibrarySyncPopupVC.instantiateFromAppStoryboard()
            self.addChild(popOverVC)
            popOverVC.view.frame = self.view.frame
            self.view.addSubview(popOverVC.view)
            popOverVC.didMove(toParent: self)
        }
    }

}
