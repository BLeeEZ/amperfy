import Foundation
import CoreData


extension PlayerMO {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<PlayerMO> {
        return NSFetchRequest<PlayerMO>(entityName: "Player")
    }

    @NSManaged public var autoCachePlayedItemSetting: Int16
    @NSManaged public var currentIndex: Int32
    @NSManaged public var isUserQueuePlaying: Bool
    @NSManaged public var repeatSetting: Int16
    @NSManaged public var shuffleSetting: Int16
    @NSManaged public var contextPlaylist: PlaylistMO?
    @NSManaged public var shuffledContextPlaylist: PlaylistMO?
    @NSManaged public var userQueuePlaylist: PlaylistMO?

}
