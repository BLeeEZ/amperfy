import Foundation
import CoreData

@objc(PodcastEpisodeMO)
public final class PodcastEpisodeMO: AbstractLibraryEntityMO {

}

extension PodcastEpisodeMO: CoreDataIdentifyable {
   
    static var identifierKey: KeyPath<PodcastEpisodeMO, String?> {
        return \PodcastEpisodeMO.playInfo?.title
    }
    
    static var publishedDateSortedFetchRequest: NSFetchRequest<PodcastEpisodeMO> {
        let fetchRequest: NSFetchRequest<PodcastEpisodeMO> = PodcastEpisodeMO.fetchRequest()
        fetchRequest.sortDescriptors = [
            NSSortDescriptor(key: #keyPath(PodcastEpisodeMO.publishDate), ascending: false),
            NSSortDescriptor(key: "id", ascending: true, selector: #selector(NSString.caseInsensitiveCompare))
        ]
        return fetchRequest
    }

}
