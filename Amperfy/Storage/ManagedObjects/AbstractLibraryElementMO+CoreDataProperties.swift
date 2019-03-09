import Foundation
import CoreData


extension AbstractLibraryElementMO {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<AbstractLibraryElementMO> {
        return NSFetchRequest<AbstractLibraryElementMO>(entityName: "AbstractLibraryElementMO")
    }

    @NSManaged public var artwork: Artwork?

}
