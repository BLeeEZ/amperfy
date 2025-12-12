//
//  WelcomePopupPresenter.swift
//  Amperfy
//
//  Created by Maximilian Bauer on 31.07.25.
//  Copyright (c) 2025 Maximilian Bauer. All rights reserved.
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

@MainActor
class WelcomePopupPresenter: NSObject {
  func displayInfoPopupsIfNeeded() {
    if !appDelegate.storage.settings.app.isLibrarySyncInfoReadByUser {
      displaySyncInfo()
    } else {
      displayNotificationAuthorization()
    }
  }

  private func displaySyncInfo() {
    let popupVC = AppStoryboard.Main.segueToLibrarySyncPopup()
    popupVC.setContent(
      topic: "Synchronization",
      detailMessage: "Your music collection is constantly updating. Already synced library items are offline available. If library items (artists/albums/songs) are not shown in your collection please use the various search functionalities to synchronize with the server.",
      customIcon: .refresh,
      customAnimation: .rotate,
      onClosePressed: { _ in
        self.appDelegate.storage.settings.app.isLibrarySyncInfoReadByUser = true
        self.displayNotificationAuthorization()
      }
    )
    appDelegate.display(popup: popupVC)
  }

  private func displayNotificationAuthorization() {
    Task { @MainActor in
      let hasAuthorizationNotBeenAskedYet = await self.appDelegate.localNotificationManager
        .hasAuthorizationNotBeenAskedYet()
      guard hasAuthorizationNotBeenAskedYet else { return }
      let popupVC = AppStoryboard.Main.segueToLibrarySyncPopup()
      popupVC.setContent(
        topic: "Notifications",
        detailMessage: "Amperfy can inform you about the latest podcast episodes. If you want to, please authorize Amperfy to send you notifications.",
        customIcon: .bell,
        customAnimation: .swing,
        onClosePressed: { _ in
          self.appDelegate.localNotificationManager.requestAuthorization()
        }
      )
      self.appDelegate.display(popup: popupVC)
    }
  }
}
