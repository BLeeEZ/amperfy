import Foundation
import UIKit
import NotificationBanner
import AmperfyKit


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
    func display(notificationBanner popupVC: UIViewController) {
        guard let topView = Self.topViewController(),
              topView.presentedViewController == nil,
              let popupVC = popupVC as? LibrarySyncPopupVC
              else { return }

        let banner = FloatingNotificationBanner(title: popupVC.topic, subtitle: popupVC.message, style: BannerStyle.from(logType: popupVC.logType), colors: AmperfyBannerColors())
        
        banner.onTap = {
            self.display(popup: popupVC)
        }
        banner.onSwipeUp = {
            NotificationBannerQueue.default.removeAll()
        }
        
        banner.show(queuePosition: QueuePosition.back, bannerPosition: BannerPosition.top, on: topView, cornerRadius: 20, shadowBlurRadius: 10)
        if let keyWindow = UIApplication.shared.keyWindow {
            keyWindow.addSubview(banner)
            keyWindow.bringSubviewToFront(banner)
        }
    }
    
    func display(popup popupVC: UIViewController) {
        guard let topView = Self.topViewController(),
              topView.presentedViewController == nil,
              self.popupDisplaySemaphore.wait(timeout: DispatchTime(uptimeNanoseconds: 0)) == .success,
              let popupVC = popupVC as? LibrarySyncPopupVC
              else { return }
        popupVC.onClose = {
            self.popupDisplaySemaphore.signal()
        }
        popupVC.modalPresentationStyle = .overCurrentContext
        popupVC.modalTransitionStyle = .crossDissolve
        topView.present(popupVC, animated: true, completion: nil)
    }
    
    func createPopupVC(topic: String, message: String, logType: LogEntryType, logEntry: LogEntry) -> UIViewController {
        let errorReportOneDaySilentTimeInSec = 60*60*24
        let popupVC = LibrarySyncPopupVC.instantiateFromAppStoryboard()
        popupVC.setContent(topic: topic, message: message, type: logType)
        popupVC.useOptionalButton(text: "Suppress for one day", onPressed: { _ in
            self.eventLogger.updateSuppressionTimeInterval(logEntry: logEntry, suppressionTimeInterval: errorReportOneDaySilentTimeInSec)
        })
        return popupVC
    }
}
