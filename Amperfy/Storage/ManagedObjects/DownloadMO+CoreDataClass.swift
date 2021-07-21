import Foundation
import CoreData

@objc(DownloadMO)
public class DownloadMO: NSManagedObject {

}

extension DownloadMO {
    
    static var creationDateSortedFetchRequest: NSFetchRequest<DownloadMO> {
        let fetchRequest: NSFetchRequest<DownloadMO> = DownloadMO.fetchRequest()
        fetchRequest.sortDescriptors = [
            NSSortDescriptor(key: #keyPath(DownloadMO.creationDate), ascending: true),
            NSSortDescriptor(key: #keyPath(DownloadMO.id), ascending: true, selector: #selector(NSString.caseInsensitiveCompare))
        ]
        return fetchRequest
    }
    
    static var onlyPlayablesPredicate: NSPredicate {
        return NSPredicate(format: "%K != nil", #keyPath(DownloadMO.playable))
    }
    
    static var onlyArtworksPredicate: NSPredicate {
        return NSPredicate(format: "%K != nil", #keyPath(DownloadMO.artwork))
    }

}
