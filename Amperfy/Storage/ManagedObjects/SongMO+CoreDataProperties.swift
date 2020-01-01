import Foundation
import CoreData


extension SongMO {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<SongMO> {
        return NSFetchRequest<SongMO>(entityName: "Song")
    }

    @NSManaged public var title: String?
    @NSManaged public var track: Int16
    @NSManaged public var url: String?
    @NSManaged public var album: AlbumMO?
    @NSManaged public var artist: ArtistMO?
    @NSManaged public var fileDataContainer: SongDataMO?
    @NSManaged public var playlistItems: NSSet?
    @NSManaged public var syncInfo: SyncWaveMO?

}

// MARK: Generated accessors for playlistItems
extension SongMO {

    @objc(addPlaylistItemsObject:)
    @NSManaged public func addToPlaylistItems(_ value: PlaylistItemMO)

    @objc(removePlaylistItemsObject:)
    @NSManaged public func removeFromPlaylistItems(_ value: PlaylistItemMO)

    @objc(addPlaylistItems:)
    @NSManaged public func addToPlaylistItems(_ values: NSSet)

    @objc(removePlaylistItems:)
    @NSManaged public func removeFromPlaylistItems(_ values: NSSet)

}
