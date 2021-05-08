import Foundation
import CoreData

@objc(AlbumMO)
public final class AlbumMO: AbstractLibraryEntityMO {

}

extension AlbumMO: CoreDataIdentifyable {
    
    static var identifierKey: WritableKeyPath<AlbumMO, String?> {
        return \AlbumMO.name
    }
    
}
