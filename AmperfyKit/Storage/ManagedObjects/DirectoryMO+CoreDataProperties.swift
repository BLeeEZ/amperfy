import Foundation
import CoreData


extension DirectoryMO {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<DirectoryMO> {
        return NSFetchRequest<DirectoryMO>(entityName: "Directory")
    }

    @NSManaged public var name: String?
    @NSManaged public var parent: DirectoryMO?
    @NSManaged public var songs: NSOrderedSet?
    @NSManaged public var subdirectories: NSOrderedSet?
    @NSManaged public var musicFolder: MusicFolderMO?

}

// MARK: Generated accessors for songs
extension DirectoryMO {

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

// MARK: Generated accessors for subdirectories
extension DirectoryMO {

    @objc(insertObject:inSubdirectoriesAtIndex:)
    @NSManaged public func insertIntoSubdirectories(_ value: DirectoryMO, at idx: Int)

    @objc(removeObjectFromSubdirectoriesAtIndex:)
    @NSManaged public func removeFromSubdirectories(at idx: Int)

    @objc(insertSubdirectories:atIndexes:)
    @NSManaged public func insertIntoSubdirectories(_ values: [DirectoryMO], at indexes: NSIndexSet)

    @objc(removeSubdirectoriesAtIndexes:)
    @NSManaged public func removeFromSubdirectories(at indexes: NSIndexSet)

    @objc(replaceObjectInSubdirectoriesAtIndex:withObject:)
    @NSManaged public func replaceSubdirectories(at idx: Int, with value: DirectoryMO)

    @objc(replaceSubdirectoriesAtIndexes:withSubdirectories:)
    @NSManaged public func replaceSubdirectories(at indexes: NSIndexSet, with values: [DirectoryMO])

    @objc(addSubdirectoriesObject:)
    @NSManaged public func addToSubdirectories(_ value: DirectoryMO)

    @objc(removeSubdirectoriesObject:)
    @NSManaged public func removeFromSubdirectories(_ value: DirectoryMO)

    @objc(addSubdirectories:)
    @NSManaged public func addToSubdirectories(_ values: NSOrderedSet)

    @objc(removeSubdirectories:)
    @NSManaged public func removeFromSubdirectories(_ values: NSOrderedSet)

}
