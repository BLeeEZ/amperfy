import Foundation
import CoreData


extension PlayerMO {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<PlayerMO> {
        return NSFetchRequest<PlayerMO>(entityName: "Player")
    }

    @NSManaged public var autoCachePlayedItemSetting: Int16
    @NSManaged public var currentIndex: Int32
    @NSManaged public var isWaitingQueuePlaying: Bool
    @NSManaged public var repeatSetting: Int16
    @NSManaged public var shuffleSetting: Int16
    @NSManaged public var normalPlaylist: PlaylistMO?
    @NSManaged public var shuffledPlaylist: PlaylistMO?
    @NSManaged public var waitingQueuePlaylist: PlaylistMO?

}
