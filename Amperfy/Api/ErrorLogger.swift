import Foundation
import UIKit
import CoreData
import os.log

class ErrorLogger {
    
    static private let errorReportOneDaySilentTimeInSec = 60*60*24
    
    private let log = OSLog(subsystem: AppDelegate.name, category: "ErrorLogger")
    private let appDelegate: AppDelegate
    private let persistentContainer: NSPersistentContainer
    
    init(app: AppDelegate, persistentContainer: NSPersistentContainer) {
        self.appDelegate = app
        self.persistentContainer = persistentContainer
    }
    
    func info(message: String) {
        os_log("Info: %s", log: log, type: .info, message)
        displayAlert(message: message)
    }
    
    private func displayAlert(message: String) {
        DispatchQueue.main.async {
            var alertMessage = ""
            alertMessage += "\(message)"
            
            let alert = UIAlertController(title: "Info", message: alertMessage, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default , handler: { _ in
                self.saveInfoPersistent(message: message)
            }))
            self.appDelegate.display(alert: alert)
        }
    }
    
    func report(error: ResponseError) {
        os_log("API-ERROR StatusCode: %d, Message: %s", log: log, type: .error, error.statusCode, error.message)
        persistentContainer.performBackgroundTask{ context in
            let library = LibraryStorage(context: context)
            let logEntries = library.getLogEntries()
            let sameStatusCodeEntries = logEntries.lazy.filter{ $0.statusCode == error.statusCode }
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
            alertMessage += "\nSettings -> Server -> Event Log"
            
            let alert = UIAlertController(title: "API Error Occured", message: alertMessage, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Suppress for \(Self.errorReportOneDaySilentTimeInSec.asDayString)", style: .destructive , handler: { _ in
                self.saveErrorPersistent(error: error, suppressionTimeInterval: Self.errorReportOneDaySilentTimeInSec)
            }))
            alert.addAction(UIAlertAction(title: "OK", style: .default , handler: { _ in
                self.saveErrorPersistent(error: error, suppressionTimeInterval: 0)
            }))
            self.appDelegate.display(alert: alert)
        }
    }
    
    private func saveErrorPersistent(error: ResponseError, suppressionTimeInterval: Int) {
        persistentContainer.performBackgroundTask{ context in
            let library = LibraryStorage(context: context)
            let errorLog = library.createLogEntry()
            errorLog.type = .error
            errorLog.statusCode = error.statusCode
            errorLog.message = error.message
            errorLog.suppressionTimeInterval = suppressionTimeInterval
            library.saveContext()
        }
    }
    
    private func saveInfoPersistent(message: String) {
        persistentContainer.performBackgroundTask{ context in
            let library = LibraryStorage(context: context)
            let errorLog = library.createLogEntry()
            errorLog.type = .info
            errorLog.message = message
            library.saveContext()
        }
    }
    
}
