import Foundation
import CoreData

enum LogEntryType: Int16 {
    case error = 0
    case warning = 1
    case info = 2
    case debug = 3
    
    var description : String {
        switch self {
        case .error: return "Error"
        case .warning: return "Warning"
        case .info: return "Info"
        case .debug: return "Debug"
        }
    }
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

extension LogEntry: Encodable {
    
    enum CodingKeys: String, CodingKey {
        case creationDate, message, statusCode, type
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(creationDate, forKey: .creationDate)
        try container.encode(message, forKey: .message)
        try container.encode(statusCode, forKey: .statusCode)
        try container.encode(type.description, forKey: .type)
    }

}
