//
//  AppDelegateNotificationExtensions.swift
//  Amperfy
//
//  Created by Maximilian Bauer on 13.10.21.
//  Copyright (c) 2021 Maximilian Bauer. All rights reserved.
//
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program.  If not, see <http://www.gnu.org/licenses/>.
//

import Foundation
import UIKit
import AmperfyKit

extension AppDelegate: UNUserNotificationCenterDelegate
{
    func configureNotificationHandling() {
        UNUserNotificationCenter.current().delegate = self
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.list, .banner])
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
