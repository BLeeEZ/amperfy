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
    @NSManaged public var entries: NSSet?

}

// MARK: Generated accessors for entries
extension PlaylistMO {

    @objc(addEntriesObject:)
    @NSManaged public func addToEntries(_ value: PlaylistElementMO)

    @objc(removeEntriesObject:)
    @NSManaged public func removeFromEntries(_ value: PlaylistElementMO)

    @objc(addEntries:)
    @NSManaged public func addToEntries(_ values: NSSet)

    @objc(removeEntries:)
    @NSManaged public func removeFromEntries(_ values: NSSet)

}
