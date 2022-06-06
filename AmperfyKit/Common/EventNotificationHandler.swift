import Foundation

extension Notification.Name {
    public static var downloadFinishedSuccess = Notification.Name(rawValue: "de.amperfy.download.finished.success")
    public static var playerPlay = Notification.Name(rawValue: "de.amperfy.player.play")
    public static var playerPause = Notification.Name(rawValue: "de.amperfy.player.pause")
    public static var playerStop = Notification.Name(rawValue: "de.amperfy.player.stop")
}

public struct DownloadNotification {
    public let id: String
    
    public var asNotificationUserInfo: [String: Any] {
        return ["downloadId": id]
    }
    
    public static func fromNotification(_ notification: Notification) -> DownloadNotification? {
        guard let userInfo = notification.userInfo as? [String: Any],
              let downloadId = userInfo["downloadId"] as? String
        else { return nil }
        return DownloadNotification(id: downloadId)
    }
}

public class EventNotificationHandler {

    public func register(_ observer: Any,
              selector aSelector: Selector,
                  name aName: NSNotification.Name,
                object anObject: Any?) {
        NotificationCenter.default.addObserver(
            observer,
            selector: aSelector,
            name: aName,
            object: anObject)
    }
    
    public func remove(_ observer: Any,
                    name aName: NSNotification.Name,
                  object anObject: Any?) {
        NotificationCenter.default.removeObserver(observer, name: aName, object: anObject)
    }
    
    public func post(name aName: NSNotification.Name, object anObject: Any?, userInfo: [AnyHashable : Any]?) {
        NotificationCenter.default.post(name: aName, object: anObject, userInfo: userInfo)
    }

}
