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

import AmperfyKit
import Foundation
import UIKit

extension UNNotification: @unchecked @retroactive Sendable {}
extension UNNotificationResponse: @unchecked @retroactive Sendable {}
extension UNUserNotificationCenter: @unchecked @retroactive Sendable {}

// MARK: - PopupPlayerDirection

enum PopupPlayerDirection {
  case open
  case close
  case toggle
}

// MARK: - AppDelegate + UNUserNotificationCenterDelegate

extension AppDelegate: UNUserNotificationCenterDelegate {
  func configureNotificationHandling() {
    UNUserNotificationCenter.current().delegate = self
  }

  func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification
  ) async
    -> UNNotificationPresentationOptions {
    [.list, .banner]
  }

  func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse
  ) async {
    let userInfo = response.notification.request.content.userInfo
    guard let contentTypeRaw = userInfo[NotificationUserInfo.type] as? String,
          let contentType = NotificationContentType(rawValue: contentTypeRaw),
          let id = userInfo[NotificationUserInfo.id] as? String else {
      return
    }

    Task { @MainActor in
      userStatistics.appStartedViaNotification()
      switch contentType {
      case .podcastEpisode:
        let episode = storage.main.library.getPodcastEpisode(id: id)
        if let podcast = episode?.podcast {
          let podcastDetailVC = PodcastDetailVC.instantiateFromAppStoryboard()
          podcastDetailVC.podcast = podcast
          displayInLibraryTab(vc: podcastDetailVC)
        }
      }
    }
  }

  func displayInLibraryTab(vc: UIViewController) {
    hostingSplitVC?.pushNavLibrary(vc: vc)
  }

  var hostingSplitVC: SplitVC? {
    guard let topView = Self.topViewController(),
          storage.isLibrarySynced,
          let splitVC = topView as? SplitVC
    else { return nil }
    return splitVC
  }

  func visualizePopupPlayer(
    direction: PopupPlayerDirection,
    animated: Bool,
    completion completionBlock: (() -> ())? = nil
  ) {
    hostingSplitVC?.visualizePopupPlayer(
      direction: direction,
      animated: animated,
      completion: completionBlock
    )
  }

  func displaySearchTab() {
    hostingSplitVC?.displaySearch()
  }
}
