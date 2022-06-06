import Foundation
import CoreData


extension PlayableFileMO {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<PlayableFileMO> {
        return NSFetchRequest<PlayableFileMO>(entityName: "PlayableFile")
    }

    @NSManaged public var data: Data?
    @NSManaged public var info: AbstractPlayableMO?

}
