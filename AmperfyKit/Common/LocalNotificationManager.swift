//
//  LocalNotificationManager.swift
//  AmperfyKit
//
//  Created by Maximilian Bauer on 13.07.21.
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
import os.log
import UIKit
import UserNotifications

// MARK: - NotificationContentType

public enum NotificationContentType: String, Sendable {
  case podcastEpisode = "PodcastEpisode"
}

// MARK: - NotificationUserInfo

public enum NotificationUserInfo {
  public static let type: String = "type"
  public static let account: String = "account"
  public static let id: String = "id"
}

// MARK: - LocalNotificationManager

@MainActor
public class LocalNotificationManager {
  private static let notificationTimeInterval = 0.1 // time interval in seconds
  private let log = OSLog(subsystem: "Amperfy", category: "LocalNotificationManager")

  private let userStatistics: UserStatistics
  private let storage: PersistentStorage

  init(userStatistics: UserStatistics, storage: PersistentStorage) {
    self.userStatistics = userStatistics
    self.storage = storage
  }

  nonisolated public func hasAuthorizationNotBeenAskedYet() async -> Bool {
    await Task {
      let settings = await UNUserNotificationCenter.current().notificationSettings()
      switch settings.authorizationStatus {
      case .notDetermined:
        return true
      default:
        break
      }
      return false
    }.value
  }

  nonisolated public func requestAuthorization() {
    Task {
      do {
        let _ = try await UNUserNotificationCenter.current().requestAuthorization(options: [
          .alert,
          .badge,
          .sound,
        ])
      } catch {
        os_log("Authorization Error: %s", log: self.log, type: .error, error.localizedDescription)
      }
    }
  }

  public func notify(podcastEpisode: PodcastEpisode) {
    userStatistics.localNotificationCreated()
    Task {
      let content = UNMutableNotificationContent()
      content.title = podcastEpisode.creatorName
      content.body = podcastEpisode.title
      content.sound = .default
      guard let account = podcastEpisode.account else { return }
      let identifier =
        "account-\(account.ident)-podcast-\(podcastEpisode.podcast?.id ?? "0")-episode-\(podcastEpisode.id)"
      do {
        let fileIdentifier = identifier + ".png"
        let artworkUrl = createLocalUrl(
          forImage: LibraryEntityImage.getImageToDisplayImmediately(
            libraryEntity: podcastEpisode,
            themePreference: storage.settings.accounts.getSetting(account.info).read
              .themePreference,
            artworkDisplayPreference: storage.settings.accounts.getSetting(account.info).read
              .artworkDisplayPreference,
            useCache: false
          ),
          fileIdentifier: fileIdentifier
        )
        let attachment = try UNNotificationAttachment(
          identifier: fileIdentifier,
          url: artworkUrl,
          options: nil
        )
        content.attachments = [attachment]
      } catch {
        os_log("Attachment Error: %s", log: self.log, type: .error, error.localizedDescription)
      }
      content.userInfo = [
        NotificationUserInfo.type: NotificationContentType.podcastEpisode.rawValue,
        NotificationUserInfo.account: account.ident,
        NotificationUserInfo.id: podcastEpisode.id,
      ]
      let trigger = UNTimeIntervalNotificationTrigger(
        timeInterval: Self.notificationTimeInterval,
        repeats: false
      )
      let request = UNNotificationRequest(
        identifier: identifier,
        content: content,
        trigger: trigger
      )
      await self.notify(request: request)
    }
  }

  public func notifyDebug(title: String, body: String) {
    Task {
      await self.notifyDebugAndWait(title: title, body: body)
    }
  }

  public func notifyDebugAndWait(title: String, body: String) async {
    let content = UNMutableNotificationContent()
    content.title = title
    content.body = body
    content.sound = .default
    let trigger = UNTimeIntervalNotificationTrigger(
      timeInterval: Self.notificationTimeInterval,
      repeats: false
    )
    let request = UNNotificationRequest(
      identifier: String.generateRandomString(ofLength: 15),
      content: content,
      trigger: trigger
    )
    await notify(request: request)
  }

  nonisolated public func listPendingNotifications() {
    Task {
      let notifications = await UNUserNotificationCenter.current().pendingNotificationRequests()
      for notification in notifications {
        print(notification)
      }
    }
  }

  nonisolated private func notify(request: UNNotificationRequest) async {
    let settings = await UNUserNotificationCenter.current().notificationSettings()
    switch settings.authorizationStatus {
    case .authorized, .provisional:
      do {
        try await UNUserNotificationCenter.current().add(request)
      } catch {
        os_log("Request Error: %s", log: self.log, type: .error, error.localizedDescription)
      }
    default:
      break
    }
  }

  private func createLocalUrl(forImage image: UIImage, fileIdentifier: String) -> URL {
    let tempDirectoryURL = NSURL.fileURL(withPath: NSTemporaryDirectory(), isDirectory: true)
    let url = tempDirectoryURL.appendingPathComponent(fileIdentifier)
    var imgData = image.pngData()
    if imgData == nil {
      imgData = UIImage.appIcon.pngData()
    }
    try! imgData!.write(to: url, options: Data.WritingOptions.atomic)
    return url
  }
}
