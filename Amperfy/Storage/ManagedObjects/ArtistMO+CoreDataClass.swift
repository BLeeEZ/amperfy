import Foundation
import CoreData

@objc(ArtistMO)
public final class ArtistMO: AbstractLibraryEntityMO {

}

extension ArtistMO: CoreDataIdentifyable {   
    
    static var identifierKey: KeyPath<ArtistMO, String?> {
        return \ArtistMO.name
    }
    
}
