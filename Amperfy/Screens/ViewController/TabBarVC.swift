import UIKit
import Foundation
import LNPopupController

class TabBarVC: UITabBarController {

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
    
        let popupPlayer = NextSongsWithEmbeddedPlayerVC()
        self.presentPopupBar(withContentViewController: popupPlayer, animated: true, completion: nil)
        self.popupBar.tintColor = UIColor.defaultBlue
        self.popupBar.imageView.layer.cornerRadius = 5
        self.popupBar.progressViewStyle = .bottom
        self.popupBar.barStyle = .prominent
        self.popupBar.marqueeScrollEnabled = true
        self.popupBar.subtitleTextAttributes = [NSAttributedString.Key.foregroundColor: UIColor.defaultBlue]
        self.popupContentView.popupCloseButtonStyle = .chevron
        self.popupInteractionStyle = .snap
    }

}
