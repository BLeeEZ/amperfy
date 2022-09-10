//
//  EventLogger.swift
//  AmperfyKit
//
//  Created by Maximilian Bauer on 16.05.21.
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
import os.log

public enum AmperfyLogStatusCode: Int {
    case downloadError = 1
    case playerError = 2
    case emailError = 3
    case internalError = 4
    case connectionError = 5
}

/// Must be called from main thread
public protocol AlertDisplayable {
    func display(notificationBanner popupVC: UIViewController)
    func display(popup popupVC: UIViewController)
    func createPopupVC(topic: String, message: String, logType: LogEntryType, logEntry: LogEntry) -> UIViewController
}

public class EventLogger {
    public var supressAlerts = false
    
    private let log = OSLog(subsystem: "Amperfy", category: "EventLogger")
    public var alertDisplayer: AlertDisplayable?
    private let storage: PersistentStorage
    
    init(storage: PersistentStorage) {
        self.storage = storage
    }
    
    public func info(topic: String, statusCode: AmperfyLogStatusCode, message: String, displayPopup: Bool) {
        report(topic: topic, statusCode: statusCode, message: message, logType: .info, displayPopup: displayPopup)
    }
    
    public func error(topic: String, statusCode: AmperfyLogStatusCode, message: String, displayPopup: Bool) {
        report(topic: topic, statusCode: statusCode, message: message, logType: .error, displayPopup: displayPopup)
    }
     
    private func report(topic: String, statusCode: AmperfyLogStatusCode, message: String, logType: LogEntryType, displayPopup: Bool) {
        storage.async.perform { asynCompanion in
            let logEntry = asynCompanion.library.createLogEntry()
            logEntry.type = logType
            logEntry.statusCode = statusCode.rawValue
            logEntry.message = topic + ": " + message
            asynCompanion.saveContext()
            
            let logEntries = asynCompanion.library.getLogEntries()
            let sameStatusCodeEntries = logEntries.lazy.filter{ $0.statusCode == statusCode.rawValue && $0.type == logType && $0.suppressionTimeInterval > 0 }
            if let sameEntry = sameStatusCodeEntries.first, sameEntry.creationDate.compare(Date() - Double(sameEntry.suppressionTimeInterval)) == .orderedDescending {
                return
            }
            if displayPopup {
                self.displayAlert(topic: topic, message: message, logEntry: logEntry)
            }
        }.catch { error in }
    }
    
    public func report(topic: String, error: Error, displayPopup: Bool = true) {
        if let apiError = error as? ResponseError {
            return report(error: apiError, displayPopup: displayPopup)
        } else {
            storage.async.perform { asynCompanion in
                let logEntry = asynCompanion.library.createLogEntry()
                logEntry.type = .error
                logEntry.message = topic + ": " + error.localizedDescription
                asynCompanion.saveContext()
                os_log("%s", log: self.log, type: .error, logEntry.message)
                if displayPopup {
                    self.displayAlert(topic: topic, message: error.localizedDescription, logEntry: logEntry)
                }
            }.catch { error in }
        }
    }
    
    public func report(error: ResponseError, displayPopup: Bool) {
        storage.async.perform { asynCompanion in
            let logEntry = asynCompanion.library.createLogEntry()
            logEntry.type = .apiError
            logEntry.statusCode = error.statusCode
            logEntry.message = "API Error " + error.statusCode.description + ": " + error.message
            asynCompanion.saveContext()
            
            var alertMessage = ""
            alertMessage += "Status code: \(error.statusCode)"
            alertMessage += "\n\(error.message)"
            
            let logEntries = asynCompanion.library.getLogEntries()
            let sameStatusCodeEntries = logEntries.lazy.filter{ $0.statusCode == error.statusCode && $0.type == .apiError && $0.suppressionTimeInterval > 0 }
            if let sameEntry = sameStatusCodeEntries.first, sameEntry.creationDate.compare(Date() - Double(sameEntry.suppressionTimeInterval)) == .orderedDescending {
                return
            }
            if displayPopup {
                self.displayAlert(topic: "API Error", message: alertMessage, logEntry: logEntry)
            }
        }.catch { error in }
    }
    
    private func displayAlert(topic: String, message: String, logEntry: LogEntry) {
        let logType = logEntry.type
        guard let displayer = self.alertDisplayer else { return }
        DispatchQueue.main.async {
            guard !self.supressAlerts else { return }
            let popupVC = displayer.createPopupVC(topic: topic, message: message, logType: logType, logEntry: logEntry)
            displayer.display(notificationBanner: popupVC)
        }
    }
    
    public func updateSuppressionTimeInterval(logEntry: LogEntry, suppressionTimeInterval: Int) {
        storage.async.perform { asynCompanion in
            let logEntryMO = asynCompanion.context.object(with: logEntry.managedObject.objectID) as! LogEntryMO
            let logEntry = LogEntry(managedObject: logEntryMO)
            logEntry.suppressionTimeInterval = suppressionTimeInterval
            asynCompanion.saveContext()
        }.catch { error in }
    }
    
}
