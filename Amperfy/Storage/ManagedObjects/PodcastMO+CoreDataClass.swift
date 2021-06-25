import Foundation
import CoreData

@objc(PodcastMO)
public final class PodcastMO: AbstractLibraryEntityMO {

}

extension PodcastMO: CoreDataIdentifyable {
    
    static var identifierKey: KeyPath<PodcastMO, String?> {
        return \PodcastMO.title
    }

}
