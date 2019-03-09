import Foundation
import CoreData


extension PlayerManaged {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<PlayerManaged> {
        return NSFetchRequest<PlayerManaged>(entityName: "PlayerManaged")
    }

    @NSManaged public var currentSongIndex: Int32
    @NSManaged public var shuffelSetting: Int16
    @NSManaged public var repeatSetting: Int16
    @NSManaged public var playlist: PlaylistManaged?

}
