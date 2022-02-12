import Foundation

extension Notification.Name {
    static var downloadFinishedSuccess = Notification.Name(rawValue: "de.amperfy.download.finished.success")
}

struct DownloadNotification {
    let id: String
    
    var asNotificationUserInfo: [String: Any] {
        return ["downloadId": id]
    }
    
    static func fromNotification(_ notification: Notification) -> DownloadNotification? {
        guard let userInfo = notification.userInfo as? [String: Any],
              let downloadId = userInfo["downloadId"] as? String
        else { return nil }
        return DownloadNotification(id: downloadId)
    }
}

class EventNotificationHandler {

    func register(_ observer: Any,
              selector aSelector: Selector,
                  name aName: NSNotification.Name,
                object anObject: Any?) {
        NotificationCenter.default.addObserver(
            observer,
            selector: aSelector,
            name: .downloadFinishedSuccess,
            object: anObject)
    }
    
    func remove(_ observer: Any,
                    name aName: NSNotification.Name,
                  object anObject: Any?) {
        NotificationCenter.default.removeObserver(observer, name: .downloadFinishedSuccess, object: anObject)
    }
    
    func post(name aName: NSNotification.Name, object anObject: Any?, userInfo: [AnyHashable : Any]?) {
        NotificationCenter.default.post(name: aName, object: anObject, userInfo: userInfo)
    }

}
