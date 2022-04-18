import Foundation
import CoreData

@objc(GenreMO)
public final class GenreMO: AbstractLibraryEntityMO {

}

extension GenreMO: CoreDataIdentifyable {
    
    static var identifierKey: KeyPath<GenreMO, String?> {
        return \GenreMO.name
    }
    
    func passOwnership(to targetGenre: GenreMO) {
        let artistsCopy = artists?.compactMap{ $0 as? ArtistMO }
        artistsCopy?.forEach{
            $0.genre = targetGenre
        }
        
        let albumsCopy = albums?.compactMap{ $0 as? AlbumMO }
        albumsCopy?.forEach{
            $0.genre = targetGenre
        }
        
        let songsCopy = songs?.compactMap{ $0 as? SongMO }
        songsCopy?.forEach{
            $0.genre = targetGenre
        }
    }
    
}
