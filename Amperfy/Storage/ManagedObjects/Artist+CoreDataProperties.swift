import Foundation
import CoreData


extension Artist {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Artist> {
        return NSFetchRequest<Artist>(entityName: "Artist")
    }

    @NSManaged public var name: String?
    @NSManaged public var albums: NSOrderedSet?
    @NSManaged public var songsMO: NSOrderedSet?
    @NSManaged public var syncInfo: SyncWaveMO?

}

// MARK: Generated accessors for albums
extension Artist {

    @objc(insertObject:inAlbumsAtIndex:)
    @NSManaged public func insertIntoAlbums(_ value: AlbumMO, at idx: Int)

    @objc(removeObjectFromAlbumsAtIndex:)
    @NSManaged public func removeFromAlbums(at idx: Int)

    @objc(insertAlbums:atIndexes:)
    @NSManaged public func insertIntoAlbums(_ values: [AlbumMO], at indexes: NSIndexSet)

    @objc(removeAlbumsAtIndexes:)
    @NSManaged public func removeFromAlbums(at indexes: NSIndexSet)

    @objc(replaceObjectInAlbumsAtIndex:withObject:)
    @NSManaged public func replaceAlbums(at idx: Int, with value: AlbumMO)

    @objc(replaceAlbumsAtIndexes:withAlbums:)
    @NSManaged public func replaceAlbums(at indexes: NSIndexSet, with values: [AlbumMO])

    @objc(addAlbumsObject:)
    @NSManaged public func addToAlbums(_ value: AlbumMO)

    @objc(removeAlbumsObject:)
    @NSManaged public func removeFromAlbums(_ value: AlbumMO)

    @objc(addAlbums:)
    @NSManaged public func addToAlbums(_ values: NSOrderedSet)

    @objc(removeAlbums:)
    @NSManaged public func removeFromAlbums(_ values: NSOrderedSet)

}

// MARK: Generated accessors for songsMO
extension Artist {

    @objc(insertObject:inSongsMOAtIndex:)
    @NSManaged public func insertIntoSongsMO(_ value: SongMO, at idx: Int)

    @objc(removeObjectFromSongsMOAtIndex:)
    @NSManaged public func removeFromSongsMO(at idx: Int)

    @objc(insertSongsMO:atIndexes:)
    @NSManaged public func insertIntoSongsMO(_ values: [SongMO], at indexes: NSIndexSet)

    @objc(removeSongsMOAtIndexes:)
    @NSManaged public func removeFromSongsMO(at indexes: NSIndexSet)

    @objc(replaceObjectInSongsMOAtIndex:withObject:)
    @NSManaged public func replaceSongsMO(at idx: Int, with value: SongMO)

    @objc(replaceSongsMOAtIndexes:withSongsMO:)
    @NSManaged public func replaceSongsMO(at indexes: NSIndexSet, with values: [SongMO])

    @objc(addSongsMOObject:)
    @NSManaged public func addToSongsMO(_ value: SongMO)

    @objc(removeSongsMOObject:)
    @NSManaged public func removeFromSongsMO(_ value: SongMO)

    @objc(addSongsMO:)
    @NSManaged public func addToSongsMO(_ values: NSOrderedSet)

    @objc(removeSongsMO:)
    @NSManaged public func removeFromSongsMO(_ values: NSOrderedSet)

}
