import Foundation
import CoreData

@objc(PlaylistMO)
public final class PlaylistMO: NSManagedObject {

    static var excludeSystemPlaylistsFetchPredicate: NSPredicate {
        return NSCompoundPredicate(andPredicateWithSubpredicates: [
            NSPredicate(format: "%K == nil", #keyPath(PlaylistMO.playersNormalPlaylist)),
            NSPredicate(format: "%K == nil", #keyPath(PlaylistMO.playersShuffledPlaylist)),
            NSPredicate(format: "%K == nil", #keyPath(PlaylistMO.playersWaitingQueuePlaylist))
        ])
    }

}

extension PlaylistMO: CoreDataIdentifyable {
    
    static var identifierKey: KeyPath<PlaylistMO, String?> {
        return \PlaylistMO.name
    }
    
}
