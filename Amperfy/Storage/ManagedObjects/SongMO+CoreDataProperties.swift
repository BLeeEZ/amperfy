import Foundation
import CoreData


extension SongMO {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<SongMO> {
        return NSFetchRequest<SongMO>(entityName: "Song")
    }

    @NSManaged public var album: AlbumMO?
    @NSManaged public var artist: ArtistMO?
    @NSManaged public var directory: DirectoryMO?
    @NSManaged public var genre: GenreMO?
    @NSManaged public var musicFolder: MusicFolderMO?
    @NSManaged public var syncInfo: SyncWaveMO?

}
