import Foundation
import CoreData


extension PlaylistMO {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<PlaylistMO> {
        return NSFetchRequest<PlaylistMO>(entityName: "Playlist")
    }

    @NSManaged public var id: Int32
    @NSManaged public var name: String?
    @NSManaged public var playersNormalPlaylist: PlayerManaged?
    @NSManaged public var playersShuffledPlaylist: PlayerManaged?
    @NSManaged public var items: NSSet?

}

// MARK: Generated accessors for items
extension PlaylistMO {

    @objc(addItemsObject:)
    @NSManaged public func addToItems(_ value: PlaylistItemMO)

    @objc(removeItemsObject:)
    @NSManaged public func removeFromItems(_ value: PlaylistItemMO)

    @objc(addItems:)
    @NSManaged public func addToItems(_ values: NSSet)

    @objc(removeItems:)
    @NSManaged public func removeFromItems(_ values: NSSet)

}
