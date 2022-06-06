import Foundation
import CoreData

@objc(ArtistMO)
public final class ArtistMO: AbstractLibraryEntityMO {

}

extension ArtistMO: CoreDataIdentifyable {   
    
    static var identifierKey: KeyPath<ArtistMO, String?> {
        return \ArtistMO.name
    }
    
    static var ratingSortedFetchRequest: NSFetchRequest<ArtistMO> {
        let fetchRequest: NSFetchRequest<ArtistMO> = ArtistMO.fetchRequest()
        fetchRequest.sortDescriptors = [
            NSSortDescriptor(key: #keyPath(ArtistMO.rating), ascending: false),
            NSSortDescriptor(key: Self.identifierKeyString, ascending: true, selector: #selector(NSString.localizedCaseInsensitiveCompare)),
            NSSortDescriptor(key: #keyPath(ArtistMO.id), ascending: true, selector: #selector(NSString.caseInsensitiveCompare))
        ]
        return fetchRequest
    }
    
    func passOwnership(to targetArtist: ArtistMO) {
        let albumsCopy = albums?.compactMap{ $0 as? AlbumMO }
        albumsCopy?.forEach{
            $0.artist = targetArtist
        }
        
        let songsCopy = songs?.compactMap{ $0 as? SongMO }
        songsCopy?.forEach{
            $0.artist = targetArtist
        }
    }
    
}
