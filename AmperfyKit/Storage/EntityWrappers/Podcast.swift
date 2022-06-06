import Foundation
import CoreData
import UIKit

public class Podcast: AbstractLibraryEntity {
    
    public let managedObject: PodcastMO
    
    public init(managedObject: PodcastMO) {
        self.managedObject = managedObject
        super.init(managedObject: managedObject)
    }
    
    public var identifier: String {
        return title
    }
    public var title: String {
        get { return managedObject.title ?? "Unknown Podcast" }
        set { if managedObject.title != newValue { managedObject.title = newValue } }
    }
    public var depiction: String {
        get { return managedObject.depiction ?? "" }
        set { if managedObject.depiction != newValue { managedObject.depiction = newValue } }
    }
    public var episodes: [PodcastEpisode] {
        guard let episodesSet = managedObject.episodes, let episodesMO = episodesSet.array as? [PodcastEpisodeMO] else { return [PodcastEpisode]() }
        return episodesMO.compactMap{ PodcastEpisode(managedObject: $0) }.filter{ $0.userStatus != .deleted }.sortByPublishDate()
    }
    override public var defaultImage: UIImage {
        return UIImage.podcastArtwork
    }

}

extension Podcast: PlayableContainable  {
    public var name: String { return title }
    public var subtitle: String? { return nil }
    public var subsubtitle: String? { return nil }
    public func infoDetails(for api: BackenApiType, type: DetailType) -> [String] {
        var infoContent = [String]()
        if episodes.count == 1 {
            infoContent.append("1 Episode")
        } else if episodes.count > 1 {
            infoContent.append("\(episodes.count) Episodes")
        }
        if type == .long {
            let completeDuration = episodes.reduce(0, {$0 + $1.duration})
            if completeDuration > 0 {
                infoContent.append("\(completeDuration.asDurationString)")
            }
        }
        return infoContent
    }
    public var playables: [AbstractPlayable] {
        return episodes
    }
    public var playContextType: PlayerMode { return .podcast }
    public func fetchFromServer(inContext context: NSManagedObjectContext, backendApi: BackendApi, settings: PersistentStorage.Settings, playableDownloadManager: DownloadManageable) {
        let podcastAsync = Podcast(managedObject: context.object(with: managedObject.objectID) as! PodcastMO)
        let autoDownloadSyncer = AutoDownloadLibrarySyncer(settings: settings, backendApi: backendApi, playableDownloadManager: playableDownloadManager)
        _ = autoDownloadSyncer.syncLatestPodcastEpisodes(podcast: podcastAsync, context: context)
    }
    public var artworkCollection: ArtworkCollection {
        return ArtworkCollection(defaultImage: defaultImage, singleImageEntity: self)
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
