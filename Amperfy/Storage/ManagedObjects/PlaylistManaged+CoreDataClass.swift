import Foundation
import CoreData

@objc(PlaylistManaged)
public class PlaylistManaged: NSManagedObject {

    var sortedByOrder: [PlaylistElement] {
        return (entries!.allObjects as! [PlaylistElement]).sorted(by: { $0.order < $1.order })
    }

}
