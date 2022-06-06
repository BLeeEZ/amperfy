import Foundation
import CoreData


extension LogEntryMO {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<LogEntryMO> {
        return NSFetchRequest<LogEntryMO>(entityName: "LogEntry")
    }

    @NSManaged public var creationDate: Date
    @NSManaged public var message: String
    @NSManaged public var statusCode: Int32
    @NSManaged public var type: Int16
    @NSManaged public var suppressionTimeInterval: Int32

}
