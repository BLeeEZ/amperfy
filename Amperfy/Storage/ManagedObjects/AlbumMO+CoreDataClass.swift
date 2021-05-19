import Foundation
import CoreData

@objc(AlbumMO)
public final class AlbumMO: AbstractLibraryEntityMO {

    static func getFetchPredicateForAlbumsWhoseSongsHave(artist: Artist) -> NSPredicate {
        return NSPredicate(format: "SUBQUERY(songs, $song, $song.artist == %@) .@count > 0", artist.managedObject.objectID)
    }

}

extension AlbumMO: CoreDataIdentifyable {
    
    static var identifierKey: WritableKeyPath<AlbumMO, String?> {
        return \AlbumMO.name
    }
    
}
