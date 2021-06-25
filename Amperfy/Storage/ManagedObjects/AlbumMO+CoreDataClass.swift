import Foundation
import CoreData

@objc(AlbumMO)
public final class AlbumMO: AbstractLibraryEntityMO {

    static func getFetchPredicateForAlbumsWhoseSongsHave(artist: Artist) -> NSPredicate {
        return NSPredicate(format: "SUBQUERY(songs, $song, $song.artist == %@) .@count > 0", artist.managedObject.objectID)
    }
    
    static var releaseYearSortedFetchRequest: NSFetchRequest<AlbumMO> {
        let fetchRequest: NSFetchRequest<AlbumMO> = AlbumMO.fetchRequest()
        fetchRequest.sortDescriptors = [
            NSSortDescriptor(key: #keyPath(AlbumMO.year), ascending: true),
            NSSortDescriptor(key: #keyPath(AlbumMO.name), ascending: true)
        ]
        return fetchRequest
    }

}

extension AlbumMO: CoreDataIdentifyable {
    
    static var identifierKey: KeyPath<AlbumMO, String?> {
        return \AlbumMO.name
    }
    
}
