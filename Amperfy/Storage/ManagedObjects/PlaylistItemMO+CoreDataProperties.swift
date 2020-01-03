import Foundation
import CoreData


extension PlaylistItemMO {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<PlaylistItemMO> {
        return NSFetchRequest<PlaylistItemMO>(entityName: "PlaylistItem")
    }

    @NSManaged public var order: Int32
    @NSManaged public var playlist: PlaylistMO?
    @NSManaged public var song: SongMO?

}
