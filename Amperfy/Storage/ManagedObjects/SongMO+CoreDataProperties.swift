import Foundation
import CoreData


extension SongMO {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<SongMO> {
        return NSFetchRequest<SongMO>(entityName: "Song")
    }

    @NSManaged public var bitrate: Int32
    @NSManaged public var contentType: String?
    @NSManaged public var disk: String?
    @NSManaged public var duration: Int16
    @NSManaged public var size: Int32
    @NSManaged public var title: String?
    @NSManaged public var track: Int16
    @NSManaged public var url: String?
    @NSManaged public var year: Int16
    @NSManaged public var album: AlbumMO?
    @NSManaged public var artist: ArtistMO?
    @NSManaged public var directory: DirectoryMO?
    @NSManaged public var file: SongFileMO?
    @NSManaged public var genre: GenreMO?
    @NSManaged public var musicFolder: MusicFolderMO?
    @NSManaged public var playlistItems: NSSet?
    @NSManaged public var syncInfo: SyncWaveMO?
    @NSManaged public var podcastEpisodeInfo: PodcastEpisodeMO?

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
