import Foundation
import CoreData


extension SongFileMO {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<SongFileMO> {
        return NSFetchRequest<SongFileMO>(entityName: "SongFile")
    }

    @NSManaged public var data: Data?
    @NSManaged public var info: SongMO?

}
