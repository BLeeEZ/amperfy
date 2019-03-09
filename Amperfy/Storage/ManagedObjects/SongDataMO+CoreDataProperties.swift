import Foundation
import CoreData


extension SongDataMO {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<SongDataMO> {
        return NSFetchRequest<SongDataMO>(entityName: "SongDataMO")
    }

    @NSManaged public var data: NSData?
    @NSManaged public var id: Int32
    @NSManaged public var info: Song?

}
