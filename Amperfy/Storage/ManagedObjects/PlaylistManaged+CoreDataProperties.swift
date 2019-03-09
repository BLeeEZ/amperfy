import Foundation
import CoreData


extension PlaylistManaged {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<PlaylistManaged> {
        return NSFetchRequest<PlaylistManaged>(entityName: "PlaylistManaged")
    }

    @NSManaged public var id: Int32
    @NSManaged public var name: String?
    @NSManaged public var currentlyPlaying: PlayerManaged?
    @NSManaged public var entries: NSSet?

}

// MARK: Generated accessors for entries
extension PlaylistManaged {

    @objc(addEntriesObject:)
    @NSManaged public func addToEntries(_ value: PlaylistElement)

    @objc(removeEntriesObject:)
    @NSManaged public func removeFromEntries(_ value: PlaylistElement)

    @objc(addEntries:)
    @NSManaged public func addToEntries(_ values: NSSet)

    @objc(removeEntries:)
    @NSManaged public func removeFromEntries(_ values: NSSet)

}
