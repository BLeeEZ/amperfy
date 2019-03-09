import Foundation
import CoreData


extension PlaylistElement {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<PlaylistElement> {
        return NSFetchRequest<PlaylistElement>(entityName: "PlaylistElement")
    }

    @NSManaged public var order: Int32
    @NSManaged public var song: Song?
    @NSManaged public var playlist: PlaylistManaged?

}
