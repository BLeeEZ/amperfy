import Foundation
import CoreData


extension Song {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Song> {
        return NSFetchRequest<Song>(entityName: "Song")
    }

    @NSManaged public var title: String?
    @NSManaged public var track: Int16
    @NSManaged public var url: String?
    @NSManaged public var album: Album?
    @NSManaged public var artist: Artist?
    @NSManaged public var dataMO: SongDataMO?
    @NSManaged public var playlistElements: NSSet?
    @NSManaged public var syncInfo: SyncWaveMO?

}

// MARK: Generated accessors for playlistElements
extension Song {

    @objc(addPlaylistElementsObject:)
    @NSManaged public func addToPlaylistElements(_ value: PlaylistElement)

    @objc(removePlaylistElementsObject:)
    @NSManaged public func removeFromPlaylistElements(_ value: PlaylistElement)

    @objc(addPlaylistElements:)
    @NSManaged public func addToPlaylistElements(_ values: NSSet)

    @objc(removePlaylistElements:)
    @NSManaged public func removeFromPlaylistElements(_ values: NSSet)

}
