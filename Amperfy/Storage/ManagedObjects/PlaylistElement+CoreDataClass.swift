import Foundation
import CoreData

@objc(PlaylistElement)
public class PlaylistElement: NSManagedObject {

    var index: Int? {
        // Check if object has been deleted
        guard (managedObjectContext != nil) else {
            return nil
        }
        return Int(order)
    }

}
