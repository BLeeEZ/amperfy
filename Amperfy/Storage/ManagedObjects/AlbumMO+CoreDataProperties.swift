import Foundation
import CoreData


extension AlbumMO {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<AlbumMO> {
        return NSFetchRequest<AlbumMO>(entityName: "Album")
    }

    @NSManaged public var name: String?
    @NSManaged public var year: Int16
    @NSManaged public var songCount: Int16
    @NSManaged public var artist: ArtistMO?
    @NSManaged public var genre: GenreMO?
    @NSManaged public var songs: NSOrderedSet?
    @NSManaged public var syncInfo: SyncWaveMO?

}

// MARK: Generated accessors for songs
extension AlbumMO {

    @objc(insertObject:inSongsAtIndex:)
    @NSManaged public func insertIntoSongs(_ value: SongMO, at idx: Int)

    @objc(removeObjectFromSongsAtIndex:)
    @NSManaged public func removeFromSongs(at idx: Int)

    @objc(insertSongs:atIndexes:)
    @NSManaged public func insertIntoSongs(_ values: [SongMO], at indexes: NSIndexSet)

    @objc(removeSongsAtIndexes:)
    @NSManaged public func removeFromSongs(at indexes: NSIndexSet)

    @objc(replaceObjectInSongsAtIndex:withObject:)
    @NSManaged public func replaceSongs(at idx: Int, with value: SongMO)

    @objc(replaceSongsAtIndexes:withSongs:)
    @NSManaged public func replaceSongs(at indexes: NSIndexSet, with values: [SongMO])

    @objc(addSongsObject:)
    @NSManaged public func addToSongs(_ value: SongMO)

    @objc(removeSongsObject:)
    @NSManaged public func removeFromSongs(_ value: SongMO)

    @objc(addSongs:)
    @NSManaged public func addToSongs(_ values: NSOrderedSet)

    @objc(removeSongs:)
    @NSManaged public func removeFromSongs(_ values: NSOrderedSet)

}
