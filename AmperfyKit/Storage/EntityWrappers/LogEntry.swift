import Foundation
import CoreData

public enum LogEntryType: Int16 {
    case apiError = 0
    case error = 1
    case info = 2
    case debug = 3
    
    public var description : String {
        switch self {
        case .apiError: return "API Error"
        case .error: return "Error"
        case .info: return "Info"
        case .debug: return "Debug"
        }
    }
}

public class LogEntry: NSObject {
    
    public let managedObject: LogEntryMO

    public init(managedObject: LogEntryMO) {
        self.managedObject = managedObject
    }
    
    public var creationDate: Date {
        get { return managedObject.creationDate }
        set { managedObject.creationDate = newValue }
    }
    
    public var message: String {
        get { return managedObject.message }
        set { managedObject.message = newValue }
    }
    
    public var statusCode: Int {
        get { return Int(managedObject.statusCode) }
        set { managedObject.statusCode = Int32(newValue) }
    }
    
    public var type: LogEntryType {
        get { return LogEntryType(rawValue: managedObject.type) ?? .error }
        set { managedObject.type = newValue.rawValue }
    }
    
    public var suppressionTimeInterval: Int {
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
