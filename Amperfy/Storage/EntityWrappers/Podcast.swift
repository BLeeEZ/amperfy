import Foundation
import CoreData
import UIKit

public class Podcast: AbstractLibraryEntity, PlayableContainable {
    
    let managedObject: PodcastMO
    
    init(managedObject: PodcastMO) {
        self.managedObject = managedObject
        super.init(managedObject: managedObject)
    }
    
    var identifier: String {
        return title
    }
    var title: String {
        get { return managedObject.title ?? "Unknown Podcast" }
        set { if managedObject.title != newValue { managedObject.title = newValue } }
    }
    var depiction: String {
        get { return managedObject.depiction ?? "" }
        set { if managedObject.depiction != newValue { managedObject.depiction = newValue } }
    }
    var episodes: [PodcastEpisode] {
        guard let episodesSet = managedObject.episodes, let episodesMO = episodesSet.array as? [PodcastEpisodeMO] else { return [PodcastEpisode]() }
        return episodesMO.compactMap{ PodcastEpisode(managedObject: $0) }.sortByPublishDate()
    }
    var playables: [AbstractPlayable] { return episodes }
    
    override var image: UIImage {
        if super.image != Artwork.defaultImage {
            return super.image
        }
        return Artwork.defaultImage
    }

}

extension Podcast: Hashable, Equatable {
    public static func == (lhs: Podcast, rhs: Podcast) -> Bool {
        return lhs.managedObject == rhs.managedObject && lhs.managedObject == rhs.managedObject
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(managedObject)
    }
}
