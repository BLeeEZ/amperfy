import Foundation
import CoreData


extension AbstractPlayableMO {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<AbstractPlayableMO> {
        return NSFetchRequest<AbstractPlayableMO>(entityName: "AbstractPlayable")
    }

    @NSManaged public var bitrate: Int32
    @NSManaged public var contentType: String?
    @NSManaged public var disk: String?
    @NSManaged public var isRecentlyAdded: Bool
    @NSManaged public var playDuration: Int16
    @NSManaged public var playProgress: Int16
    @NSManaged public var remoteDuration: Int16
    @NSManaged public var size: Int32
    @NSManaged public var title: String?
    @NSManaged public var track: Int16
    @NSManaged public var url: String?
    @NSManaged public var year: Int16
    @NSManaged public var download: DownloadMO?
    @NSManaged public var file: PlayableFileMO?
    @NSManaged public var playlistItems: NSOrderedSet?
    @NSManaged public var embeddedArtwork: EmbeddedArtworkMO?

}

// MARK: Generated accessors for playlistItems
extension AbstractPlayableMO {

    @objc(insertObject:inPlaylistItemsAtIndex:)
    @NSManaged public func insertIntoPlaylistItems(_ value: PlaylistItemMO, at idx: Int)

    @objc(removeObjectFromPlaylistItemsAtIndex:)
    @NSManaged public func removeFromPlaylistItems(at idx: Int)

    @objc(insertPlaylistItems:atIndexes:)
    @NSManaged public func insertIntoPlaylistItems(_ values: [PlaylistItemMO], at indexes: NSIndexSet)

    @objc(removePlaylistItemsAtIndexes:)
    @NSManaged public func removeFromPlaylistItems(at indexes: NSIndexSet)

    @objc(replaceObjectInPlaylistItemsAtIndex:withObject:)
    @NSManaged public func replacePlaylistItems(at idx: Int, with value: PlaylistItemMO)

    @objc(replacePlaylistItemsAtIndexes:withPlaylistItems:)
    @NSManaged public func replacePlaylistItems(at indexes: NSIndexSet, with values: [PlaylistItemMO])

    @objc(addPlaylistItemsObject:)
    @NSManaged public func addToPlaylistItems(_ value: PlaylistItemMO)

    @objc(removePlaylistItemsObject:)
    @NSManaged public func removeFromPlaylistItems(_ value: PlaylistItemMO)

    @objc(addPlaylistItems:)
    @NSManaged public func addToPlaylistItems(_ values: NSOrderedSet)

    @objc(removePlaylistItems:)
    @NSManaged public func removeFromPlaylistItems(_ values: NSOrderedSet)

}
