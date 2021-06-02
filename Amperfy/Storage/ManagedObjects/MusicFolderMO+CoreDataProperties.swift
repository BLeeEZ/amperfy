import Foundation
import CoreData


extension MusicFolderMO {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<MusicFolderMO> {
        return NSFetchRequest<MusicFolderMO>(entityName: "MusicFolder")
    }

    @NSManaged public var id: String
    @NSManaged public var name: String
    @NSManaged public var directories: NSOrderedSet?
    @NSManaged public var songs: NSOrderedSet?

}

// MARK: Generated accessors for directories
extension MusicFolderMO {

    @objc(insertObject:inDirectoriesAtIndex:)
    @NSManaged public func insertIntoDirectories(_ value: DirectoryMO, at idx: Int)

    @objc(removeObjectFromDirectoriesAtIndex:)
    @NSManaged public func removeFromDirectories(at idx: Int)

    @objc(insertDirectories:atIndexes:)
    @NSManaged public func insertIntoDirectories(_ values: [DirectoryMO], at indexes: NSIndexSet)

    @objc(removeDirectoriesAtIndexes:)
    @NSManaged public func removeFromDirectories(at indexes: NSIndexSet)

    @objc(replaceObjectInDirectoriesAtIndex:withObject:)
    @NSManaged public func replaceDirectories(at idx: Int, with value: DirectoryMO)

    @objc(replaceDirectoriesAtIndexes:withDirectories:)
    @NSManaged public func replaceDirectories(at indexes: NSIndexSet, with values: [DirectoryMO])

    @objc(addDirectoriesObject:)
    @NSManaged public func addToDirectories(_ value: DirectoryMO)

    @objc(removeDirectoriesObject:)
    @NSManaged public func removeFromDirectories(_ value: DirectoryMO)

    @objc(addDirectories:)
    @NSManaged public func addToDirectories(_ values: NSOrderedSet)

    @objc(removeDirectories:)
    @NSManaged public func removeFromDirectories(_ values: NSOrderedSet)

}

// MARK: Generated accessors for songs
extension MusicFolderMO {

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
