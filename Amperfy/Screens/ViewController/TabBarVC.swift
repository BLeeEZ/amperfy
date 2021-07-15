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
            displaySyncInfo()
        } else {
            displayNotificationAuthorization()
        }
    }
    
    private func displaySyncInfo() {
        let popupVC = LibrarySyncPopupVC.instantiateFromAppStoryboard()
        popupVC.setContent(
            topic: "Synchronization",
            message: "Your music collection is constantly updating. Already synced libray items are offline available. If library items (artists/albums/songs) are not shown in your  collection please use the various search functionalities to synchronize with the server.",
            type: .info,
            customIcon: .Sync,
            customAnimation: .rotate,
            onClosePressed: { _ in
                self.appDelegate.persistentStorage.isLibrarySyncInfoReadByUser = true
                self.displayNotificationAuthorization()
            }
        )
        appDelegate.display(popup: popupVC)
    }
    
    private func displayNotificationAuthorization() {
        self.appDelegate.localNotificationManager.executeIfAuthorizationHasNotBeenAskedYet {
            DispatchQueue.main.async {
                let popupVC = LibrarySyncPopupVC.instantiateFromAppStoryboard()
                popupVC.setContent(
                    topic: "Notifications",
                    message: "Amperfy can inform you about the latest podcast episodes. If you want to, please authorize Amperfy to send you notifications.",
                    type: .info,
                    customIcon: .Bell,
                    customAnimation: .swing,
                    onClosePressed: { _ in
                        self.appDelegate.localNotificationManager.requestAuthorization()
                    }
                )
                self.appDelegate.display(popup: popupVC)
            }
        }
    }

}
