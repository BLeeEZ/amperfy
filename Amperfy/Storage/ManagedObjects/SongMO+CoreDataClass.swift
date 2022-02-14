import Foundation
import CoreData

@objc(SongMO)
public final class SongMO: AbstractPlayableMO {
    
}

extension SongMO: CoreDataIdentifyable {
    
    static var identifierKey: KeyPath<SongMO, String?> {
        return \SongMO.title
    }
    
    static var excludeServerDeleteUncachedSongsFetchPredicate: NSPredicate {
        return NSCompoundPredicate(orPredicateWithSubpredicates: [
            NSCompoundPredicate(andPredicateWithSubpredicates: [
                NSPredicate(format: "%K > 0", #keyPath(SongMO.size)),
                NSPredicate(format: "%K == %i", #keyPath(SongMO.album.remoteStatus), RemoteStatus.available.rawValue)
            ]),
            NSPredicate(format: "%K != nil", #keyPath(SongMO.file)),
        ])
    }
    
    static var trackNumberSortedFetchRequest: NSFetchRequest<SongMO> {
        let fetchRequest: NSFetchRequest<SongMO> = SongMO.fetchRequest()
        fetchRequest.sortDescriptors = [
            NSSortDescriptor(key: "disk", ascending: true, selector: #selector(NSString.caseInsensitiveCompare)),
            NSSortDescriptor(key: "track", ascending: true),
            NSSortDescriptor(key: "id", ascending: true, selector: #selector(NSString.caseInsensitiveCompare))
        ]
        return fetchRequest
    }

}
