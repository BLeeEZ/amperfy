import Foundation
import CoreData

@objc(PodcastMO)
public final class PodcastMO: AbstractLibraryEntityMO {

}

extension PodcastMO: CoreDataIdentifyable {
    
    static var identifierKey: KeyPath<PodcastMO, String?> {
        return \PodcastMO.title
    }
    
    func passOwnership(to targetPodcast: PodcastMO) {
        let episodesCopy = episodes?.compactMap{ $0 as? PodcastEpisodeMO }
        episodesCopy?.forEach{
            $0.podcast = targetPodcast
        }
    }
    
}
