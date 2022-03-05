import Foundation
import UserNotifications
import UIKit
import os.log

enum NotificationContentType: NSString {
    case podcastEpisode = "PodcastEpisode"
}

struct NotificationUserInfo {
    static let type: NSString = "type"
    static let id: NSString = "id"
}

class LocalNotificationManager {
    
    private static let notificationTimeInterval = 1.0 // time interval in seconds
    
    private let userStatistics: UserStatistics
    private let persistentStorage: PersistentStorage
    private let log = OSLog(subsystem: AppDelegate.name, category: "LocalNotificationManager")
    
    init(userStatistics: UserStatistics, persistentStorage: PersistentStorage) {
        self.userStatistics = userStatistics
        self.persistentStorage = persistentStorage
    }
    
    func executeIfAuthorizationHasNotBeenAskedYet(askForAuthorizationCallback: @escaping () -> Void) {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            switch settings.authorizationStatus {
            case .notDetermined:
                askForAuthorizationCallback()
            default:
                break
            }
        }
    }

    func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { success, error in
            if let error = error {
                os_log("Authorization Error: %s", log: self.log, type: .error, error.localizedDescription)
            }
        }
    }

    /// Must be called from main thread
    func notify(podcastEpisode: PodcastEpisode) {
        userStatistics.localNotificationCreated()
        let content = UNMutableNotificationContent()
        content.title = podcastEpisode.creatorName
        content.body = podcastEpisode.title
        content.sound = .default
        let identifier = "podcast-\(podcastEpisode.podcast?.id ?? "0")-episode-\(podcastEpisode.id)"
        do {
            let fileIdentifier = identifier + ".png"
            let artworkUrl = createLocalUrl(forImage: podcastEpisode.image(setting: persistentStorage.settings.artworkDisplayPreference), fileIdentifier: fileIdentifier)
            let attachment = try UNNotificationAttachment(identifier: fileIdentifier, url: artworkUrl, options: nil)
            content.attachments = [attachment]
        } catch {
            os_log("Attachment Error: %s", log: self.log, type: .error, error.localizedDescription)
        }
        content.userInfo = [
            NotificationUserInfo.type: NotificationContentType.podcastEpisode.rawValue,
            NotificationUserInfo.id: podcastEpisode.id
        ]
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: Self.notificationTimeInterval, repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        notify(request: request)
    }

    func listPendingNotifications() {
        UNUserNotificationCenter.current().getPendingNotificationRequests { notifications in
            for notification in notifications {
                print(notification)
            }
        }
    }
    
    private func notify(request: UNNotificationRequest) {
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
            imgData = UIImage.amperfyMosaicArtwork.pngData()
        }
        try! imgData!.write(to: url, options: Data.WritingOptions.atomic)
        return url
    }
    
}

