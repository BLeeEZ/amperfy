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
    
    static var ratingSortedFetchRequest: NSFetchRequest<AlbumMO> {
        let fetchRequest: NSFetchRequest<AlbumMO> = AlbumMO.fetchRequest()
        fetchRequest.sortDescriptors = [
            NSSortDescriptor(key: #keyPath(AlbumMO.rating), ascending: false),
            NSSortDescriptor(key: Self.identifierKeyString, ascending: true, selector: #selector(NSString.localizedStandardCompare)),
            NSSortDescriptor(key: #keyPath(AlbumMO.id), ascending: true, selector: #selector(NSString.localizedStandardCompare))
        ]
        return fetchRequest
    }

}

extension AlbumMO: CoreDataIdentifyable {
    
    static var identifierKey: KeyPath<AlbumMO, String?> {
        return \AlbumMO.name
    }
    
    func passOwnership(to targetAlbum: AlbumMO) {
        let songsCopy = songs?.compactMap{ $0 as? SongMO }
        songsCopy?.forEach{
            $0.album = targetAlbum
        }
    }
    
}
