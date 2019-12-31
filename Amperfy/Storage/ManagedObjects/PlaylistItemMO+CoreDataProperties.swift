import Foundation
import CoreData


extension PlaylistItemMO {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<PlaylistItemMO> {
        return NSFetchRequest<PlaylistItemMO>(entityName: "PlaylistItem")
    }

    @NSManaged public var order: Int32
    @NSManaged public var song: SongMO?
    @NSManaged public var playlist: PlaylistMO?

}
