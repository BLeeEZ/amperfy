import Foundation
import Intents

public class IntentManager {
    
    private let library: LibraryStorage
    private let player: PlayerFacade
    
    init(library: LibraryStorage, player: PlayerFacade) {
        self.library = library
        self.player = player
    }
    
    public func handleIncomingIntent(userActivity: NSUserActivity) -> Bool {
        guard userActivity.activityType == NSStringFromClass(SearchAndPlayIntent.self) ||
                userActivity.activityType == NSUserActivity.searchAndPlayActivityType else {
                return false
        }
        if userActivity.activityType == NSUserActivity.searchAndPlayActivityType,
           let searchTerm = userActivity.userInfo?[NSUserActivity.ActivityKeys.searchTerm.rawValue] as? String,
           let searchCategoryRaw = userActivity.userInfo?[NSUserActivity.ActivityKeys.searchCategory.rawValue] as? Int,
           let searchCategory = PlayableContainerType(rawValue: searchCategoryRaw) {
            
            switch searchCategory {
            case .unknown:
                fallthrough
            case .artist:
                let artist = library.getArtists().lazy.first(where: { $0.name.contains(searchTerm) })
                guard let artist = artist else { return false }
                player.play(context: PlayContext(containable: artist))
            case .song:
                let song = library.getSongs().lazy.first(where: { $0.name.contains(searchTerm) })
                guard let song = song else { return false }
                player.play(context: PlayContext(containable: song))
            case .podcastEpisode:
                let podcastEpisode = library.getPodcastEpisodes().lazy.first(where: { $0.name.contains(searchTerm) })
                guard let podcastEpisode = podcastEpisode else { return false }
                player.play(context: PlayContext(containable: podcastEpisode))
            case .playlist:
                let playlist = library.getPlaylists().lazy.first(where: { $0.name.contains(searchTerm) })
                guard let playlist = playlist else { return false }
                player.play(context: PlayContext(containable: playlist))
            case .album:
                let album = library.getAlbums().lazy.first(where: { $0.name.contains(searchTerm) })
                guard let album = album else { return false }
                player.play(context: PlayContext(containable: album))
            case .genre:
                let genre = library.getGenres().lazy.first(where: { $0.name.contains(searchTerm) })
                guard let genre = genre else { return false }
                player.play(context: PlayContext(containable: genre))
            case .podcast:
                let podcast = library.getPodcasts().lazy.first(where: { $0.name.contains(searchTerm) })
                guard let podcast = podcast else { return false }
                player.play(context: PlayContext(containable: podcast))
            }
        }
        return true
    }
    
}
