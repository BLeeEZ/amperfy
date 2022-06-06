import Foundation
import UIKit
import CoreData
import os.log

public enum AmperfyLogStatusCode: Int {
    case downloadError = 1
    case playerError = 2
    case emailError = 3
    case internalError = 4
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
    private let persistentContainer: NSPersistentContainer
    
    init(persistentContainer: NSPersistentContainer) {
        self.persistentContainer = persistentContainer
    }
    
    public func info(topic: String, statusCode: AmperfyLogStatusCode, message: String, displayPopup: Bool) {
        report(topic: topic, statusCode: statusCode, message: message, logType: .info, displayPopup: displayPopup)
    }
    
    public func error(topic: String, statusCode: AmperfyLogStatusCode, message: String, displayPopup: Bool) {
        report(topic: topic, statusCode: statusCode, message: message, logType: .error, displayPopup: displayPopup)
    }
    
    private func report(topic: String, statusCode: AmperfyLogStatusCode, message: String, logType: LogEntryType, displayPopup: Bool) {
        persistentContainer.performBackgroundTask { context in
            let library = LibraryStorage(context: context)
            let logEntry = library.createLogEntry()
            logEntry.type = logType
            logEntry.statusCode = statusCode.rawValue
            logEntry.message = message
            library.saveContext()
            
            let logEntries = library.getLogEntries()
            let sameStatusCodeEntries = logEntries.lazy.filter{ $0.statusCode == statusCode.rawValue && $0.type == logType && $0.suppressionTimeInterval > 0 }
            if let sameEntry = sameStatusCodeEntries.first, sameEntry.creationDate.compare(Date() - Double(sameEntry.suppressionTimeInterval)) == .orderedDescending {
                return
            }
            if displayPopup {
                self.displayAlert(topic: topic, message: message, logEntry: logEntry)
            }
        }
    }
    
    public func report(error: ResponseError, displayPopup: Bool) {
        persistentContainer.performBackgroundTask { context in
            let library = LibraryStorage(context: context)
            let logEntry = library.createLogEntry()
            logEntry.type = .apiError
            logEntry.statusCode = error.statusCode
            logEntry.message = error.message
            library.saveContext()
            
            var alertMessage = ""
            alertMessage += "Status code: \(error.statusCode)"
            alertMessage += "\n\(error.message)"
            alertMessage += "\n"
            alertMessage += "\nYou can find the event log at:"
            alertMessage += "\nSettings -> Support -> Event Log"
            
            let logEntries = library.getLogEntries()
            let sameStatusCodeEntries = logEntries.lazy.filter{ $0.statusCode == error.statusCode && $0.type == .apiError && $0.suppressionTimeInterval > 0 }
            if let sameEntry = sameStatusCodeEntries.first, sameEntry.creationDate.compare(Date() - Double(sameEntry.suppressionTimeInterval)) == .orderedDescending {
                return
            }
            if displayPopup {
                self.displayAlert(topic: "API Error", message: alertMessage, logEntry: logEntry)
            }
        }
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
        persistentContainer.performBackgroundTask { context in
            let library = LibraryStorage(context: context)
            let logEntryMO = context.object(with: logEntry.managedObject.objectID) as! LogEntryMO
            let logEntry = LogEntry(managedObject: logEntryMO)
            logEntry.suppressionTimeInterval = suppressionTimeInterval
            library.saveContext()
        }
    }
    
}
