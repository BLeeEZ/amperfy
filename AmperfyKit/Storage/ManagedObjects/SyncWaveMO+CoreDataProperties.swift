import Foundation
import CoreData


extension SyncWaveMO {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<SyncWaveMO> {
        return NSFetchRequest<SyncWaveMO>(entityName: "SyncWave")
    }

    @NSManaged public var dateOfLastAdd: Date?
    @NSManaged public var dateOfLastClean: Date?
    @NSManaged public var dateOfLastUpdate: Date?
    @NSManaged public var id: Int16
    @NSManaged public var syncIndexToContinue: String
    @NSManaged public var syncState: Int16
    @NSManaged public var syncType: Int16
    @NSManaged public var version: Int16
    @NSManaged public var albums: NSOrderedSet?
    @NSManaged public var artists: NSOrderedSet?
    @NSManaged public var genres: NSOrderedSet?
    @NSManaged public var songs: NSOrderedSet?

}

// MARK: Generated accessors for albums
extension SyncWaveMO {

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

// MARK: Generated accessors for artists
extension SyncWaveMO {

    @objc(insertObject:inArtistsAtIndex:)
    @NSManaged public func insertIntoArtists(_ value: ArtistMO, at idx: Int)

    @objc(removeObjectFromArtistsAtIndex:)
    @NSManaged public func removeFromArtists(at idx: Int)

    @objc(insertArtists:atIndexes:)
    @NSManaged public func insertIntoArtists(_ values: [ArtistMO], at indexes: NSIndexSet)

    @objc(removeArtistsAtIndexes:)
    @NSManaged public func removeFromArtists(at indexes: NSIndexSet)

    @objc(replaceObjectInArtistsAtIndex:withObject:)
    @NSManaged public func replaceArtists(at idx: Int, with value: ArtistMO)

    @objc(replaceArtistsAtIndexes:withArtists:)
    @NSManaged public func replaceArtists(at indexes: NSIndexSet, with values: [ArtistMO])

    @objc(addArtistsObject:)
    @NSManaged public func addToArtists(_ value: ArtistMO)

    @objc(removeArtistsObject:)
    @NSManaged public func removeFromArtists(_ value: ArtistMO)

    @objc(addArtists:)
    @NSManaged public func addToArtists(_ values: NSOrderedSet)

    @objc(removeArtists:)
    @NSManaged public func removeFromArtists(_ values: NSOrderedSet)

}

// MARK: Generated accessors for genres
extension SyncWaveMO {

    @objc(insertObject:inGenresAtIndex:)
    @NSManaged public func insertIntoGenres(_ value: GenreMO, at idx: Int)

    @objc(removeObjectFromGenresAtIndex:)
    @NSManaged public func removeFromGenres(at idx: Int)

    @objc(insertGenres:atIndexes:)
    @NSManaged public func insertIntoGenres(_ values: [GenreMO], at indexes: NSIndexSet)

    @objc(removeGenresAtIndexes:)
    @NSManaged public func removeFromGenres(at indexes: NSIndexSet)

    @objc(replaceObjectInGenresAtIndex:withObject:)
    @NSManaged public func replaceGenres(at idx: Int, with value: GenreMO)

    @objc(replaceGenresAtIndexes:withGenres:)
    @NSManaged public func replaceGenres(at indexes: NSIndexSet, with values: [GenreMO])

    @objc(addGenresObject:)
    @NSManaged public func addToGenres(_ value: GenreMO)

    @objc(removeGenresObject:)
    @NSManaged public func removeFromGenres(_ value: GenreMO)

    @objc(addGenres:)
    @NSManaged public func addToGenres(_ values: NSOrderedSet)

    @objc(removeGenres:)
    @NSManaged public func removeFromGenres(_ values: NSOrderedSet)

}

// MARK: Generated accessors for songs
extension SyncWaveMO {

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
