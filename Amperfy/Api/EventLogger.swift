import Foundation
import UIKit
import CoreData
import os.log

protocol AlertDisplayable {
    func display(alert: UIAlertController) // Must be called from main thread
}

enum AmperfyLogStatusCode: Int {
    case downloadError = 1
    case playerError = 2
    case emailError = 3
    case internalError = 4
}

class EventLogger {
    
    static private let errorReportOneDaySilentTimeInSec = 60*60*24
    
    private let log = OSLog(subsystem: AppDelegate.name, category: "EventLogger")
    private let alertDisplayer: AlertDisplayable
    private let persistentContainer: NSPersistentContainer
    
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
        persistentContainer.performBackgroundTask{ context in
            let library = LibraryStorage(context: context)
            let logEntries = library.getLogEntries()
            let sameStatusCodeEntries = logEntries.lazy.filter{ $0.statusCode == statusCode.rawValue && $0.type == logType }
            if let sameEntry = sameStatusCodeEntries.first, sameEntry.creationDate.compare(Date() - Double(sameEntry.suppressionTimeInterval)) == .orderedDescending {
                return
            }
            self.displayAlert(topic: topic, statusCode: statusCode, message: message, logType: logType)
        }
    }
    
    private func displayAlert(topic: String, statusCode: AmperfyLogStatusCode, message: String, logType: LogEntryType) {
        DispatchQueue.main.async {
            var alertMessage = ""
            alertMessage += "\(message)"
            
            let alert = UIAlertController(title: topic, message: alertMessage, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Suppress for \(Self.errorReportOneDaySilentTimeInSec.asDayString)", style: .destructive , handler: { _ in
                self.saveMessagePersistent(message: message, statusCode: statusCode, logType: logType, suppressionTimeInterval: Self.errorReportOneDaySilentTimeInSec)
            }))
            alert.addAction(UIAlertAction(title: "OK", style: .default , handler: { _ in
                self.saveMessagePersistent(message: message, statusCode: statusCode, logType: logType)
            }))
            self.alertDisplayer.display(alert: alert)
        }
    }
    
    func report(error: ResponseError) {
        persistentContainer.performBackgroundTask{ context in
            let library = LibraryStorage(context: context)
            let logEntries = library.getLogEntries()
            let sameStatusCodeEntries = logEntries.lazy.filter{ $0.statusCode == error.statusCode && $0.type == .apiError }
            if let sameEntry = sameStatusCodeEntries.first, sameEntry.creationDate.compare(Date() - Double(sameEntry.suppressionTimeInterval)) == .orderedDescending {
                return
            }
            self.displayAlert(error: error)
        }
    }
    
    private func displayAlert(error: ResponseError) {
        DispatchQueue.main.async {
            var alertMessage = ""
            alertMessage += "Status code: \(error.statusCode)"
            alertMessage += "\n\(error.message)"
            alertMessage += "\n"
            alertMessage += "\nYou can find the event log at:"
            alertMessage += "\nSettings -> Support -> Event Log"
            
            let alert = UIAlertController(title: "API Error", message: alertMessage, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Suppress for \(Self.errorReportOneDaySilentTimeInSec.asDayString)", style: .destructive , handler: { _ in
                self.saveErrorPersistent(error: error, suppressionTimeInterval: Self.errorReportOneDaySilentTimeInSec)
            }))
            alert.addAction(UIAlertAction(title: "OK", style: .default , handler: { _ in
                self.saveErrorPersistent(error: error)
            }))
            self.alertDisplayer.display(alert: alert)
        }
    }
    
    private func saveErrorPersistent(error: ResponseError, suppressionTimeInterval: Int = 0) {
        persistentContainer.performBackgroundTask{ context in
            let library = LibraryStorage(context: context)
            let errorLog = library.createLogEntry()
            errorLog.type = .apiError
            errorLog.statusCode = error.statusCode
            errorLog.message = error.message
            errorLog.suppressionTimeInterval = suppressionTimeInterval
            library.saveContext()
        }
    }
    
    private func saveMessagePersistent(message: String, statusCode: AmperfyLogStatusCode, logType: LogEntryType, suppressionTimeInterval: Int = 0) {
        persistentContainer.performBackgroundTask{ context in
            let library = LibraryStorage(context: context)
            let errorLog = library.createLogEntry()
            errorLog.type = logType
            errorLog.statusCode = statusCode.rawValue
            errorLog.message = message
            errorLog.suppressionTimeInterval = suppressionTimeInterval
            library.saveContext()
        }
    }
    
}
