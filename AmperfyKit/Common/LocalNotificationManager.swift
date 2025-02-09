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
import UserNotifications
import UIKit
import os.log

public enum NotificationContentType: String, Sendable {
    case podcastEpisode = "PodcastEpisode"
}

public struct NotificationUserInfo {
    public static let type: String = "type"
    public static let id: String = "id"
}

@MainActor public class LocalNotificationManager {
    
    private static let notificationTimeInterval = 0.1 // time interval in seconds
    private static let log = OSLog(subsystem: "Amperfy", category: "LocalNotificationManager")
    
    private let userStatistics: UserStatistics
    private let storage: PersistentStorage
    
    init(userStatistics: UserStatistics, storage: PersistentStorage) {
        self.userStatistics = userStatistics
        self.storage = storage
    }
    
    public func executeIfAuthorizationHasNotBeenAskedYet(askForAuthorizationCallback: @escaping () -> Void) {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            switch settings.authorizationStatus {
            case .notDetermined:
                askForAuthorizationCallback()
            default:
                break
            }
        }
    }

    public func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { success, error in
            if let error = error {
                os_log("Authorization Error: %s", log: Self.log, type: .error, error.localizedDescription)
            }
        }
    }

    /// Must be called from main thread
    public func notify(podcastEpisode: PodcastEpisode) {
        userStatistics.localNotificationCreated()
        let content = UNMutableNotificationContent()
        content.title = podcastEpisode.creatorName
        content.body = podcastEpisode.title
        content.sound = .default
        let identifier = "podcast-\(podcastEpisode.podcast?.id ?? "0")-episode-\(podcastEpisode.id)"
        do {
            let fileIdentifier = identifier + ".png"
            let artworkUrl = createLocalUrl(forImage: podcastEpisode.image(theme: storage.settings.themePreference, setting: storage.settings.artworkDisplayPreference), fileIdentifier: fileIdentifier)
            let attachment = try UNNotificationAttachment(identifier: fileIdentifier, url: artworkUrl, options: nil)
            content.attachments = [attachment]
        } catch {
            os_log("Attachment Error: %s", log: Self.log, type: .error, error.localizedDescription)
        }
        content.userInfo = [
            NotificationUserInfo.type: NotificationContentType.podcastEpisode.rawValue,
            NotificationUserInfo.id: podcastEpisode.id
        ]
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: Self.notificationTimeInterval, repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        Self.notify(request: request)
    }
    
    /// Must be called from main thread
    public static func notifyDebug(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: Self.notificationTimeInterval, repeats: false)
        let request = UNNotificationRequest(identifier: String.generateRandomString(ofLength: 15), content: content, trigger: trigger)
        Self.notify(request: request)
    }

    public func listPendingNotifications() {
        UNUserNotificationCenter.current().getPendingNotificationRequests { notifications in
            for notification in notifications {
                print(notification)
            }
        }
    }
    
    private static func notify(request: UNNotificationRequest) {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            switch settings.authorizationStatus {
            case .authorized, .provisional:
                UNUserNotificationCenter.current().add(request) { error in
                    if let error = error {
                        os_log("Request Error: %s", log: self.log, type: .error, error.localizedDescription)
                    }
                }
            default:
                break
            }
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

