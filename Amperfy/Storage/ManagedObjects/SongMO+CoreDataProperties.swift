import Foundation
import CoreData


extension SongMO {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<SongMO> {
        return NSFetchRequest<SongMO>(entityName: "Song")
    }

    @NSManaged public var title: String?
    @NSManaged public var track: Int16
    @NSManaged public var url: String?
    @NSManaged public var album: Album?
    @NSManaged public var artist: Artist?
    @NSManaged public var fileDataContainer: SongDataMO?
    @NSManaged public var playlistElements: NSSet?
    @NSManaged public var syncInfo: SyncWaveMO?

}

// MARK: Generated accessors for playlistElements
extension SongMO {

    @objc(addPlaylistElementsObject:)
    @NSManaged public func addToPlaylistElements(_ value: PlaylistElementMO)

    @objc(removePlaylistElementsObject:)
    @NSManaged public func removeFromPlaylistElements(_ value: PlaylistElementMO)

    @objc(addPlaylistElements:)
    @NSManaged public func addToPlaylistElements(_ values: NSSet)

    @objc(removePlaylistElements:)
    @NSManaged public func removeFromPlaylistElements(_ values: NSSet)

}
