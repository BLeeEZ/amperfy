import Foundation
import CoreData


extension SyncWaveMO {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<SyncWaveMO> {
        return NSFetchRequest<SyncWaveMO>(entityName: "SyncWaveMO")
    }

    @NSManaged public var dateOfLastAdd: NSDate?
    @NSManaged public var dateOfLastClean: NSDate?
    @NSManaged public var dateOfLastUpdate: NSDate?
    @NSManaged public var id: Int16
    @NSManaged public var syncIndexToContinueMO: Int16
    @NSManaged public var syncStateMO: Int16
    @NSManaged public var albums: NSOrderedSet?
    @NSManaged public var artists: NSOrderedSet?
    @NSManaged public var songsMO: NSOrderedSet?

}

// MARK: Generated accessors for albums
extension SyncWaveMO {

    @objc(insertObject:inAlbumsAtIndex:)
    @NSManaged public func insertIntoAlbums(_ value: Album, at idx: Int)

    @objc(removeObjectFromAlbumsAtIndex:)
    @NSManaged public func removeFromAlbums(at idx: Int)

    @objc(insertAlbums:atIndexes:)
    @NSManaged public func insertIntoAlbums(_ values: [Album], at indexes: NSIndexSet)

    @objc(removeAlbumsAtIndexes:)
    @NSManaged public func removeFromAlbums(at indexes: NSIndexSet)

    @objc(replaceObjectInAlbumsAtIndex:withObject:)
    @NSManaged public func replaceAlbums(at idx: Int, with value: Album)

    @objc(replaceAlbumsAtIndexes:withAlbums:)
    @NSManaged public func replaceAlbums(at indexes: NSIndexSet, with values: [Album])

    @objc(addAlbumsObject:)
    @NSManaged public func addToAlbums(_ value: Album)

    @objc(removeAlbumsObject:)
    @NSManaged public func removeFromAlbums(_ value: Album)

    @objc(addAlbums:)
    @NSManaged public func addToAlbums(_ values: NSOrderedSet)

    @objc(removeAlbums:)
    @NSManaged public func removeFromAlbums(_ values: NSOrderedSet)

}

// MARK: Generated accessors for artists
extension SyncWaveMO {

    @objc(insertObject:inArtistsAtIndex:)
    @NSManaged public func insertIntoArtists(_ value: Artist, at idx: Int)

    @objc(removeObjectFromArtistsAtIndex:)
    @NSManaged public func removeFromArtists(at idx: Int)

    @objc(insertArtists:atIndexes:)
    @NSManaged public func insertIntoArtists(_ values: [Artist], at indexes: NSIndexSet)

    @objc(removeArtistsAtIndexes:)
    @NSManaged public func removeFromArtists(at indexes: NSIndexSet)

    @objc(replaceObjectInArtistsAtIndex:withObject:)
    @NSManaged public func replaceArtists(at idx: Int, with value: Artist)

    @objc(replaceArtistsAtIndexes:withArtists:)
    @NSManaged public func replaceArtists(at indexes: NSIndexSet, with values: [Artist])

    @objc(addArtistsObject:)
    @NSManaged public func addToArtists(_ value: Artist)

    @objc(removeArtistsObject:)
    @NSManaged public func removeFromArtists(_ value: Artist)

    @objc(addArtists:)
    @NSManaged public func addToArtists(_ values: NSOrderedSet)

    @objc(removeArtists:)
    @NSManaged public func removeFromArtists(_ values: NSOrderedSet)

}

// MARK: Generated accessors for songsMO
extension SyncWaveMO {

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
