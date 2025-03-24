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

import AmperfyKit
import Foundation
import NotificationBannerSwift
import UIKit

extension AppDelegate {
  static var window: UIWindow? {
    #if targetEnvironment(macCatalyst)
      // Always get the topmost window that corresponds to the active tab
      return (UIApplication.shared.connectedScenes.first {
        let isForeground = $0.activationState == .foregroundActive
        let isMainWindow = ($0.delegate as? SceneDelegate) != nil
        return isForeground && isMainWindow
      }?.delegate as? SceneDelegate)?.window
    #else
      return (UIApplication.shared.delegate as! AppDelegate).window
    #endif
  }

  static func rootViewController() -> UIViewController? {
    Self.window?.rootViewController
  }

  static func topViewController(
    base: UIViewController? =
      window?.rootViewController
  )
    -> UIViewController? {
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

// MARK: - AppDelegate + AlertDisplayable

extension AppDelegate: AlertDisplayable {
  func display(
    title: String,
    subtitle: String,
    style: LogEntryType,
    notificationBanner popupVC: UIViewController
  ) {
    guard NotificationBannerQueue.default.numberOfBanners < 1,
          let topView = Self.topViewController(),
          topView.presentedViewController == nil,
          let _ = UIApplication.shared.mainWindow
    else { return }

    let banner = FloatingNotificationBanner(
      title: title,
      subtitle: subtitle,
      style: BannerStyle.from(logType: style),
      colors: AmperfyBannerColors()
    )

    banner.onTap = {
      guard let topView = Self.topViewController(),
            topView.presentedViewController == nil
      else { return }
      topView.present(popupVC, animated: true, completion: nil)
    }

    #if targetEnvironment(macCatalyst)
      banner.bannerHeight = 120
      let topViewInset = UIEdgeInsets(
        top: 40,
        left: topView.view.frame.width - 400,
        bottom: 24,
        right: 24
      )
      banner.show(
        queuePosition: QueuePosition.back,
        bannerPosition: BannerPosition.top,
        on: topView,
        edgeInsets: topViewInset,
        cornerRadius: 10,
        shadowOpacity: 0.5,
        shadowBlurRadius: 5
      )
    #else
      banner.show(
        queuePosition: QueuePosition.back,
        bannerPosition: BannerPosition.top,
        on: topView,
        cornerRadius: 15,
        shadowBlurRadius: 10
      )
    #endif
  }

  func display(popup popupVC: UIViewController) {
    guard let topView = Self.topViewController(),
          topView.presentedViewController == nil
    else { return }
    popupVC.modalPresentationStyle = .overCurrentContext
    popupVC.modalTransitionStyle = .crossDissolve
    topView.present(popupVC, animated: true, completion: nil)
  }

  func createPopupVC(
    topic: String,
    shortMessage: String,
    detailMessage: String,
    logType: LogEntryType
  )
    -> UIViewController {
    let popupVC = NotificationDetailVC()
    popupVC.display(title: topic, message: detailMessage, type: logType)
    return popupVC
  }
}
