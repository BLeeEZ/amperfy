import Foundation
import CoreData

@objc(GenreMO)
public final class GenreMO: AbstractLibraryEntityMO {

}

extension GenreMO: CoreDataIdentifyable {
    
    static var identifierKey: KeyPath<GenreMO, String?> {
        return \GenreMO.name
    }
    
}
