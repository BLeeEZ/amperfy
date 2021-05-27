import Foundation
import CoreData


extension MusicFolderMO {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<MusicFolderMO> {
        return NSFetchRequest<MusicFolderMO>(entityName: "MusicFolder")
    }

    @NSManaged public var id: String
    @NSManaged public var name: String
    @NSManaged public var directories: NSOrderedSet?

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
