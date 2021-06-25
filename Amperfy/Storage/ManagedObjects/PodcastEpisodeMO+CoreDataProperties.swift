import Foundation
import CoreData


extension PodcastEpisodeMO {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<PodcastEpisodeMO> {
        return NSFetchRequest<PodcastEpisodeMO>(entityName: "PodcastEpisode")
    }

    @NSManaged public var publishDate: Date?
    @NSManaged public var depiction: String?
    @NSManaged public var status: Int16
    @NSManaged public var streamId: String?
    @NSManaged public var podcast: PodcastMO?
    @NSManaged public var playInfo: SongMO?

}
