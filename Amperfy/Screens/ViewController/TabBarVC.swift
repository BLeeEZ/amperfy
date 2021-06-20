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
            let popupVC = LibrarySyncPopupVC.instantiateFromAppStoryboard()
            popupVC.setContent(
                topic: "Synchronisation",
                message: "Your music collection is constantly updating. Already synced libray items are offline available. If library items (artists/albums/songs) are not shown in your  collection please use the various search functionalities to synchronise with the server.",
                type: .info,
                customIcon: .Sync,
                customAnimation: .rotate,
                onClosePressed: { _ in
                    self.appDelegate.persistentStorage.isLibrarySyncInfoReadByUser = true
                }
            )
            appDelegate.display(popup: popupVC)
        }
    }

}
