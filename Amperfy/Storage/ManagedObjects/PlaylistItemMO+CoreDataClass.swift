import Foundation
import CoreData

@objc(PlaylistItemMO)
public class PlaylistItemMO: NSManagedObject {

    static var playlistOrderSortedFetchRequest: NSFetchRequest<PlaylistItemMO> {
        let fetchRequest: NSFetchRequest<PlaylistItemMO> = PlaylistItemMO.fetchRequest()
        fetchRequest.sortDescriptors = [
            NSSortDescriptor(key: #keyPath(PlaylistItemMO.order), ascending: true)
        ]
        return fetchRequest
    }

    static func getFetchPredicate(forSongWithTitle searchText: String) -> NSPredicate {
        if searchText.count > 0 {
            return NSPredicate(format: "(%K == %@)", #keyPath(PlaylistItemMO.song.title), searchText)
        } else {
            return NSPredicate.alwaysTrue
        }
    }

}
