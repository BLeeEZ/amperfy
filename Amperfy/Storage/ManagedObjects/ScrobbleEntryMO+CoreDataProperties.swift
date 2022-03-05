import Foundation
import CoreData


extension ScrobbleEntryMO {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<ScrobbleEntryMO> {
        return NSFetchRequest<ScrobbleEntryMO>(entityName: "ScrobbleEntry")
    }

    @NSManaged public var date: Date?
    @NSManaged public var isUploaded: Bool
    @NSManaged public var playable: AbstractPlayableMO?

}
