//
//  AppDelegateAlertExtensions.swift
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
import NotificationBannerSwift
import AmperfyKit


extension AppDelegate {
    static func topViewController(base: UIViewController? = (UIApplication.shared.delegate as! AppDelegate).window?.rootViewController) -> UIViewController? {
        if base?.presentedViewController is UIAlertController {
            return base
        }
        if let nav = base as? UINavigationController {
            return topViewController(base: nav.visibleViewController)
        }
        if let tab = base as? TabBarVC {
            return tab.parent
        }
        if let splitVC = base as? SplitVC {
            return splitVC
        }
        if let presented = base?.presentedViewController {
            return topViewController(base: presented)
        }
        return base
    }
}

extension AppDelegate: AlertDisplayable {
    func display(notificationBanner popupVC: UIViewController) {
        guard NotificationBannerQueue.default.numberOfBanners < 1,
              let topView = Self.topViewController(),
              topView.presentedViewController == nil,
              let popupVC = popupVC as? LibrarySyncPopupVC,
              let _ = UIApplication.shared.mainWindow
              else { return }

        let banner = FloatingNotificationBanner(title: popupVC.topic, subtitle: popupVC.shortMessage, style: BannerStyle.from(logType: popupVC.logType), colors: AmperfyBannerColors())
        
        banner.onTap = {
            self.display(popup: popupVC)
        }
        
        banner.show(queuePosition: QueuePosition.back, bannerPosition: BannerPosition.top, on: topView, cornerRadius: 20, shadowBlurRadius: 10)
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
    
    func createPopupVC(topic: String, shortMessage: String, detailMessage: String, clipboardContent: String?, logType: LogEntryType) -> UIViewController {
        let popupVC = LibrarySyncPopupVC.instantiateFromAppStoryboard()
        popupVC.setContent(topic: topic, shortMessage: shortMessage, detailMessage: detailMessage, clipboardContent: clipboardContent, type: logType)
        return popupVC
    }
}
