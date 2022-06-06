import Foundation
import CoreData

@objc(LogEntryMO)
public class LogEntryMO: NSManagedObject {

}

extension LogEntryMO {
    
    static var creationDateSortedFetchRequest: NSFetchRequest<LogEntryMO> {
        let fetchRequest: NSFetchRequest<LogEntryMO> = LogEntryMO.fetchRequest()
        fetchRequest.sortDescriptors = [
            NSSortDescriptor(key: #keyPath(LogEntryMO.creationDate), ascending: false)
        ]
        return fetchRequest
    }

}
