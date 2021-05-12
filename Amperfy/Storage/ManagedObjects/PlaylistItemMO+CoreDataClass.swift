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

}
