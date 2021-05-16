import Foundation
import CoreData

enum LogEntryType: Int16 {
    case error = 0
}

public class LogEntry: NSObject {
    
    let managedObject: LogEntryMO

    init(managedObject: LogEntryMO) {
        self.managedObject = managedObject
    }
    
    var creationDate: Date {
        get { return managedObject.creationDate }
        set { managedObject.creationDate = newValue }
    }
    
    var message: String {
        get { return managedObject.message }
        set { managedObject.message = newValue }
    }
    
    var statusCode: Int {
        get { return Int(managedObject.statusCode) }
        set { managedObject.statusCode = Int32(newValue) }
    }
    
    var type: LogEntryType {
        get { return LogEntryType(rawValue: managedObject.type) ?? .error }
        set { managedObject.type = newValue.rawValue }
    }
    
    var suppressionTimeInterval: Int {
        get { return Int(managedObject.suppressionTimeInterval) }
        set { managedObject.suppressionTimeInterval = Int32(newValue) }
    }

}
