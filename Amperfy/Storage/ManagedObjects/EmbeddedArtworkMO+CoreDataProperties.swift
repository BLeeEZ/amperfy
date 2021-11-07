import Foundation
import CoreData


extension EmbeddedArtworkMO {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<EmbeddedArtworkMO> {
        return NSFetchRequest<EmbeddedArtworkMO>(entityName: "EmbeddedArtwork")
    }

    @NSManaged public var imageData: Data?
    @NSManaged public var owner: AbstractPlayableMO?

}
