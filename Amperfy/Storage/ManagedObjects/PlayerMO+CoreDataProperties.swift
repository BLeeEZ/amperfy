import Foundation
import CoreData


extension PlayerMO {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<PlayerMO> {
        return NSFetchRequest<PlayerMO>(entityName: "Player")
    }

    @NSManaged public var autoCachePlayedSongSetting: Int16
    @NSManaged public var currentSongIndex: Int32
    @NSManaged public var repeatSetting: Int16
    @NSManaged public var shuffleSetting: Int16
    @NSManaged public var normalPlaylist: PlaylistMO?
    @NSManaged public var shuffledPlaylist: PlaylistMO?

}
