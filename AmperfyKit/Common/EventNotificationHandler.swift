//
//  EventNotificationHandler.swift
//  AmperfyKit
//
//  Created by Maximilian Bauer on 12.02.22.
//  Copyright (c) 2022 Maximilian Bauer. All rights reserved.
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
