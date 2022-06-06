import Foundation

public enum PodcastsShowType: Int {
    case podcasts = 0
    case episodesSortedByReleaseDate = 1
    
    static let defaultValue: PodcastsShowType = .podcasts
}
