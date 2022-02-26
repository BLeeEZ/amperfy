import Foundation
import CoreData

@objc(PlaylistMO)
public final class PlaylistMO: NSManagedObject {

    static var excludeSystemPlaylistsFetchPredicate: NSPredicate {
        return NSCompoundPredicate(andPredicateWithSubpredicates: [
            NSPredicate(format: "%K == nil", #keyPath(PlaylistMO.playersContextPlaylist)),
            NSPredicate(format: "%K == nil", #keyPath(PlaylistMO.playersShuffledContextPlaylist)),
            NSPredicate(format: "%K == nil", #keyPath(PlaylistMO.playersUserQueuePlaylist)),
            NSPredicate(format: "%K == nil", #keyPath(PlaylistMO.playersPodcastPlaylist))
        ])
    }

}

extension PlaylistMO: CoreDataIdentifyable {
    
    static var identifierKey: KeyPath<PlaylistMO, String?> {
        return \PlaylistMO.name
    }
    
}
