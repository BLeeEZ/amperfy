import Foundation
import UIKit

extension AppDelegate: UNUserNotificationCenterDelegate
{
    func configureNotificationHandling() {
        UNUserNotificationCenter.current().delegate = self
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler(.alert)
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        userStatistics.appStartedViaNotification()
        let userInfo = response.notification.request.content.userInfo
        guard let contentTypeRaw = userInfo[NotificationUserInfo.type] as? NSString, let contentType = NotificationContentType(rawValue: contentTypeRaw), let id = userInfo[NotificationUserInfo.id] as? String else { completionHandler(); return }

        switch contentType {
        case .podcastEpisode:
            let episode = library.getPodcastEpisode(id: id)
            if let podcast = episode?.podcast {
                let podcastDetailVC = PodcastDetailVC.instantiateFromAppStoryboard()
                podcastDetailVC.podcast = podcast
                displayInLibraryTab(vc: podcastDetailVC)
            }
        }
        completionHandler()
    }
    
    private func displayInLibraryTab(vc: UIViewController) {
        guard let topView = Self.topViewController(),
              topView.presentedViewController == nil,
              let hostingTabBarVC = topView as? UITabBarController
        else { return }
        
        if hostingTabBarVC.popupPresentationState == .open,
           let popupPlayerVC = hostingTabBarVC.popupContent as? PopupPlayerVC {
            popupPlayerVC.closePopupPlayerAndDisplayInLibraryTab(vc: vc)
        } else if let hostingTabViewControllers = hostingTabBarVC.viewControllers,
           hostingTabViewControllers.count > 0,
           let libraryTabNavVC = hostingTabViewControllers[0] as? UINavigationController {
            libraryTabNavVC.pushViewController(vc, animated: false)
            hostingTabBarVC.selectedIndex = 0
        }
    }
}
