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
    @NSManaged public var embeddedArtwork: EmbeddedArtworkMO?
    @NSManaged public var file: PlayableFileMO?
    @NSManaged public var playlistItems: NSOrderedSet?
    @NSManaged public var scrobbleEntries: NSOrderedSet?

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

// MARK: Generated accessors for scrobbleEntries
extension AbstractPlayableMO {

    @objc(insertObject:inScrobbleEntriesAtIndex:)
    @NSManaged public func insertIntoScrobbleEntries(_ value: ScrobbleEntryMO, at idx: Int)

    @objc(removeObjectFromScrobbleEntriesAtIndex:)
    @NSManaged public func removeFromScrobbleEntries(at idx: Int)

    @objc(insertScrobbleEntries:atIndexes:)
    @NSManaged public func insertIntoScrobbleEntries(_ values: [ScrobbleEntryMO], at indexes: NSIndexSet)

    @objc(removeScrobbleEntriesAtIndexes:)
    @NSManaged public func removeFromScrobbleEntries(at indexes: NSIndexSet)

    @objc(replaceObjectInScrobbleEntriesAtIndex:withObject:)
    @NSManaged public func replaceScrobbleEntries(at idx: Int, with value: ScrobbleEntryMO)

    @objc(replaceScrobbleEntriesAtIndexes:withScrobbleEntries:)
    @NSManaged public func replaceScrobbleEntries(at indexes: NSIndexSet, with values: [ScrobbleEntryMO])

    @objc(addScrobbleEntriesObject:)
    @NSManaged public func addToScrobbleEntries(_ value: ScrobbleEntryMO)

    @objc(removeScrobbleEntriesObject:)
    @NSManaged public func removeFromScrobbleEntries(_ value: ScrobbleEntryMO)

    @objc(addScrobbleEntries:)
    @NSManaged public func addToScrobbleEntries(_ values: NSOrderedSet)

    @objc(removeScrobbleEntries:)
    @NSManaged public func removeFromScrobbleEntries(_ values: NSOrderedSet)

}
