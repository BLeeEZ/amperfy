import Foundation
import CoreData

@objc(ArtistMO)
public final class ArtistMO: AbstractLibraryEntityMO {

}

extension ArtistMO: CoreDataIdentifyable {   
    
    static var identifierKey: KeyPath<ArtistMO, String?> {
        return \ArtistMO.name
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
