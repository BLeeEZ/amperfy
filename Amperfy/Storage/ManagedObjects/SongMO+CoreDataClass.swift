import Foundation
import CoreData

@objc(SongMO)
public final class SongMO: AbstractLibraryEntityMO {

    static var excludePodcastEpisodesFetchPredicate: NSPredicate {
        return NSCompoundPredicate(andPredicateWithSubpredicates: [
            NSPredicate(format: "%K == nil", #keyPath(SongMO.podcastEpisodeInfo))
        ])
    }
    
}

extension SongMO: CoreDataIdentifyable {
    
    static var identifierKey: KeyPath<SongMO, String?> {
        return \SongMO.title
    }
    
    static var trackNumberSortedFetchRequest: NSFetchRequest<SongMO> {
        let fetchRequest: NSFetchRequest<SongMO> = SongMO.fetchRequest()
        fetchRequest.sortDescriptors = [
            NSSortDescriptor(key: "track", ascending: true),
            NSSortDescriptor(key: "id", ascending: true, selector: #selector(NSString.caseInsensitiveCompare))
        ]
        return fetchRequest
    }

}
