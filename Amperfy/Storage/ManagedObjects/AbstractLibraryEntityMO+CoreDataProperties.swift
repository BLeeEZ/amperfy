import Foundation
import CoreData


extension AbstractLibraryEntityMO {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<AbstractLibraryEntityMO> {
        return NSFetchRequest<AbstractLibraryEntityMO>(entityName: "AbstractLibraryEntity")
    }

    @NSManaged public var id: String
    @NSManaged public var rating: Int16
    @NSManaged public var remoteStatus: Int16
    @NSManaged public var playCount: Int32
    @NSManaged public var lastPlayedDate: Date?
    @NSManaged public var artwork: ArtworkMO?

}
