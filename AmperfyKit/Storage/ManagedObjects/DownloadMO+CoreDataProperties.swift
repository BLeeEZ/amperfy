import Foundation
import CoreData


extension DownloadMO {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<DownloadMO> {
        return NSFetchRequest<DownloadMO>(entityName: "Download")
    }

    @NSManaged public var creationDate: Date?
    @NSManaged public var errorDate: Date?
    @NSManaged public var errorType: Int16
    @NSManaged public var finishDate: Date?
    @NSManaged public var id: String
    @NSManaged public var progressPercent: Float
    @NSManaged public var startDate: Date?
    @NSManaged public var totalSize: String?
    @NSManaged public var resumeData: Data?
    @NSManaged public var urlString: String
    @NSManaged public var artwork: ArtworkMO?
    @NSManaged public var playable: AbstractPlayableMO?

}
