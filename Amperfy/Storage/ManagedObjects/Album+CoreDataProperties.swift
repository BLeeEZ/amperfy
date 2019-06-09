import Foundation
import CoreData


extension Album {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Album> {
        return NSFetchRequest<Album>(entityName: "Album")
    }

    @NSManaged public var name: String?
    @NSManaged public var year: Int16
    @NSManaged public var artist: Artist?
    @NSManaged public var songsMO: NSOrderedSet?
    @NSManaged public var syncInfo: SyncWaveMO?

}

// MARK: Generated accessors for songsMO
extension Album {

    @objc(insertObject:inSongsMOAtIndex:)
    @NSManaged public func insertIntoSongsMO(_ value: Song, at idx: Int)

    @objc(removeObjectFromSongsMOAtIndex:)
    @NSManaged public func removeFromSongsMO(at idx: Int)

    @objc(insertSongsMO:atIndexes:)
    @NSManaged public func insertIntoSongsMO(_ values: [Song], at indexes: NSIndexSet)

    @objc(removeSongsMOAtIndexes:)
    @NSManaged public func removeFromSongsMO(at indexes: NSIndexSet)

    @objc(replaceObjectInSongsMOAtIndex:withObject:)
    @NSManaged public func replaceSongsMO(at idx: Int, with value: Song)

    @objc(replaceSongsMOAtIndexes:withSongsMO:)
    @NSManaged public func replaceSongsMO(at indexes: NSIndexSet, with values: [Song])

    @objc(addSongsMOObject:)
    @NSManaged public func addToSongsMO(_ value: Song)

    @objc(removeSongsMOObject:)
    @NSManaged public func removeFromSongsMO(_ value: Song)

    @objc(addSongsMO:)
    @NSManaged public func addToSongsMO(_ values: NSOrderedSet)

    @objc(removeSongsMO:)
    @NSManaged public func removeFromSongsMO(_ values: NSOrderedSet)

}
