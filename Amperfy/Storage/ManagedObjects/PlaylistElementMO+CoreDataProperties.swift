import Foundation
import CoreData


extension PlaylistElementMO {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<PlaylistElementMO> {
        return NSFetchRequest<PlaylistElementMO>(entityName: "PlaylistElement")
    }

    @NSManaged public var order: Int32
    @NSManaged public var song: SongMO?
    @NSManaged public var playlist: PlaylistMO?

}
