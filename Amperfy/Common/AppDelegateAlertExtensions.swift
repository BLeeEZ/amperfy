import Foundation
import UIKit
import NotificationBanner

/// Must be called from main thread
protocol AlertDisplayable {
    func display(notificationBanner popupVC: LibrarySyncPopupVC)
    func display(popup popupVC: LibrarySyncPopupVC)
}

extension AppDelegate {
    static func topViewController(base: UIViewController? = (UIApplication.shared.delegate as! AppDelegate).window?.rootViewController) -> UIViewController? {
        if base?.presentedViewController is UIAlertController {
            return base
        }
        if let nav = base as? UINavigationController {
            return topViewController(base: nav.visibleViewController)
        }
        if let tab = base as? UITabBarController {
            return tab
        }
        if let presented = base?.presentedViewController {
            return topViewController(base: presented)
        }
        return base
    }
}

extension AppDelegate: AlertDisplayable {
    func display(notificationBanner popupVC: LibrarySyncPopupVC) {
        guard let topView = Self.topViewController(),
              topView.presentedViewController == nil
              else { return }

        let banner = FloatingNotificationBanner(title: popupVC.topic, subtitle: popupVC.message, style: BannerStyle.from(logType: popupVC.logType), colors: AmperfyBannerColors())
        
        banner.onTap = {
            self.display(popup: popupVC)
        }
        banner.onSwipeUp = {
            NotificationBannerQueue.default.removeAll()
        }
        
        banner.show(queuePosition: .back, bannerPosition: .top, on: topView, cornerRadius: 20, shadowBlurRadius: 10)
        if let keyWindow = UIApplication.shared.keyWindow {
            keyWindow.addSubview(banner)
            keyWindow.bringSubviewToFront(banner)
        }
    }
    
    func display(popup popupVC: LibrarySyncPopupVC) {
        guard let topView = Self.topViewController(),
              topView.presentedViewController == nil,
              self.popupDisplaySemaphore.wait(timeout: DispatchTime(uptimeNanoseconds: 0)) == .success
              else { return }
        popupVC.onClose = {
            self.popupDisplaySemaphore.signal()
        }
        popupVC.modalPresentationStyle = .overCurrentContext
        popupVC.modalTransitionStyle = .crossDissolve
        topView.present(popupVC, animated: true, completion: nil)
    }
}
