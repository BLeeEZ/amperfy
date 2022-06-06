import Foundation
import CoreData

@objc(AbstractLibraryEntityMO)
public class AbstractLibraryEntityMO: NSManagedObject {

    static var excludeRemoteDeleteFetchPredicate: NSPredicate {
        return NSCompoundPredicate(orPredicateWithSubpredicates: [
            NSPredicate(format: "%K == %i", #keyPath(AbstractLibraryEntityMO.remoteStatus), RemoteStatus.available.rawValue)
        ])
    }
    
}
