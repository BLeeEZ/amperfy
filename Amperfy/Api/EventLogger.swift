import Foundation
import UIKit
import CoreData
import os.log

protocol AlertDisplayable {
    func display(alert: UIAlertController) -> Bool // Must be called from main thread
}

enum AmperfyLogStatusCode: Int {
    case downloadError = 1
    case playerError = 2
    case emailError = 3
    case internalError = 4
}

class EventLogger {
    
    static private let errorReportOneDaySilentTimeInSec = 60*60*24
    
    var supressAlerts = false
    
    private let log = OSLog(subsystem: AppDelegate.name, category: "EventLogger")
    private let alertDisplayer: AlertDisplayable
    private let persistentContainer: NSPersistentContainer
    private let displaySemaphore = DispatchSemaphore(value: 1)
    
    init(alertDisplayer: AlertDisplayable, persistentContainer: NSPersistentContainer) {
        self.alertDisplayer = alertDisplayer
        self.persistentContainer = persistentContainer
    }
    
    func info(topic: String, statusCode: AmperfyLogStatusCode, message: String) {
        report(topic: topic, statusCode: statusCode, message: message, logType: .info)
    }
    
    func error(topic: String, statusCode: AmperfyLogStatusCode, message: String) {
        report(topic: topic, statusCode: statusCode, message: message, logType: .error)
    }
    
    private func report(topic: String, statusCode: AmperfyLogStatusCode, message: String, logType: LogEntryType) {
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
            self.displayAlert(topic: topic, message: message, logEntry: logEntry)
        }
    }
    
    func report(error: ResponseError) {
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
            self.displayAlert(topic: "API Error", message: alertMessage, logEntry: logEntry)
        }
    }
    
    private func displayAlert(topic: String, message: String, logEntry: LogEntry) {
        DispatchQueue.main.async {
            guard !self.supressAlerts else { return }
            if self.displaySemaphore.wait(timeout: DispatchTime(uptimeNanoseconds: 0)) == .success {
                let alert = UIAlertController(title: topic, message: message, preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "Suppress for \(Self.errorReportOneDaySilentTimeInSec.asDayString)", style: .destructive, handler: { _ in
                    self.updateSuppressionTimeInterval(logEntry: logEntry, suppressionTimeInterval: Self.errorReportOneDaySilentTimeInSec)
                    self.displaySemaphore.signal()
                }))
                alert.addAction(UIAlertAction(title: "OK", style: .default,  handler: { _ in
                    self.displaySemaphore.signal()
                }))
                let isDisplayed = self.alertDisplayer.display(alert: alert)
                if !isDisplayed {
                    self.displaySemaphore.signal()
                }
            }
        }
    }
    
    private func updateSuppressionTimeInterval(logEntry: LogEntry, suppressionTimeInterval: Int) {
        persistentContainer.performBackgroundTask { context in
            let library = LibraryStorage(context: context)
            let logEntryMO = context.object(with: logEntry.managedObject.objectID) as! LogEntryMO
            let logEntry = LogEntry(managedObject: logEntryMO)
            logEntry.suppressionTimeInterval = suppressionTimeInterval
            library.saveContext()
        }
    }
    
}
