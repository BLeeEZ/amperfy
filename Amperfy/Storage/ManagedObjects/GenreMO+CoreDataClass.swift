import Foundation
import CoreData

@objc(GenreMO)
public final class GenreMO: AbstractLibraryEntityMO {

}

extension GenreMO: CoreDataIdentifyable {
    
    static var identifierKey: WritableKeyPath<GenreMO, String?> {
        return \GenreMO.name
    }
    
}
