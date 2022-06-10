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
            
            var playableContainer: PlayableContainable?
            var shuffleOption = false
            var repeatOption = RepeatMode.off
            
            if let shuffleUserRaw = userActivity.userInfo?[NSUserActivity.ActivityKeys.shuffleOption.rawValue] as? Int,
               let shuffleUser = ShuffleType(rawValue: shuffleUserRaw) {
                shuffleOption = shuffleUser == .on
            }
            if let repeatUserRaw = userActivity.userInfo?[NSUserActivity.ActivityKeys.repeatOption.rawValue] as? Int,
               let repeatUser = RepeatType(rawValue: repeatUserRaw) {
                repeatOption = RepeatMode.fromIntent(type: repeatUser)
            }
            
            switch searchCategory {
            case .unknown:
                fallthrough
            case .song:
                playableContainer = library.getSongs().lazy.first(where: { $0.name.contains(searchTerm) })
            case .artist:
                playableContainer = library.getArtists().lazy.first(where: { $0.name.contains(searchTerm) })
            case .podcastEpisode:
                playableContainer = library.getPodcastEpisodes().lazy.first(where: { $0.name.contains(searchTerm) })
            case .playlist:
                playableContainer = library.getPlaylists().lazy.first(where: { $0.name.contains(searchTerm) })
            case .album:
                playableContainer = library.getAlbums().lazy.first(where: { $0.name.contains(searchTerm) })
            case .genre:
                playableContainer = library.getGenres().lazy.first(where: { $0.name.contains(searchTerm) })
            case .podcast:
                playableContainer = library.getPodcasts().lazy.first(where: { $0.name.contains(searchTerm) })
            }
            
            play(container: playableContainer, shuffleOption: shuffleOption, repeatOption: repeatOption)
        }
        return true
    }
    
    private func play(container: PlayableContainable?, shuffleOption: Bool, repeatOption: RepeatMode) {
        guard let container = container else { return }
        if shuffleOption {
            player.playShuffled(context: PlayContext(containable: container))
        } else {
            player.play(context: PlayContext(containable: container))
        }
        player.setRepeatMode(repeatOption)
    }
    
}
