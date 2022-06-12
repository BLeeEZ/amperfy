import Foundation
import Intents
import CallbackURLKit

extension PlayableContainerType {
    public static func from(string: String) -> PlayableContainerType? {
        switch string {
        case "artist":
            return .artist
        case "song":
            return .song
        case "podcastEpisode":
            return .podcastEpisode
        case "playlist":
            return .playlist
        case "album":
            return .album
        case "genre":
            return .genre
        case "podcast":
            return .podcast
        default:
            return nil
        }
    }
}

public class IntentManager {
    
    private let library: LibraryStorage
    private let player: PlayerFacade
    
    init(library: LibraryStorage, player: PlayerFacade) {
        self.library = library
        self.player = player
    }
    
    /// URLs to handle need to define in Project -> Targerts: Amperfy -> Info -> URL Types
    public func handleIncoming(url: URL) -> Bool {
        return Manager.shared.handleOpen(url: url)
    }
    
    public func registerXCallbackURLs() {
        // get the first from Info.plist using utility method
        Manager.shared.callbackURLScheme = Manager.urlSchemes?.first
        
        // [url-scheme]://x-callback-url/[action]?[x-callback parameters]&[action parameters]
        
        // SearchAndPlay
        // url example: amperfy://x-callback-url/searchAndPlay?searchTerm=Good&searchCategory=playlist&shuffleOption=1&repeatOption=2
        // action: searchAndPlay
        // parameter mandatory: searchTerm: String
        //                      searchCategory: Sting (lower case type: artist, song, playlist, ...)
        // parameter optional:  shuffleOption: 0 or 1
        //                      repeatOption: 0 (off), 1 (all), 2 (single)
        CallbackURLKit.register(action: "searchAndPlay") { parameters, success, failure, cancel in
            var shuffleOption = false
            var repeatOption = RepeatMode.off
            
            guard let searchTerm = parameters.first(where: {$0.key == NSUserActivity.ActivityKeys.searchTerm.rawValue} )?.value else {
                failure(NSError.error(code: .missingParameter, failureReason: "searchTerm not provided."))
                return
            }
            guard let searchCategoryStringRaw = parameters.first(where: {$0.key == NSUserActivity.ActivityKeys.searchCategory.rawValue} )?.value else {
                failure(NSError.error(code: .missingParameter, failureReason: "searchCategory not provided."))
                return
            }
            guard let searchCategory = PlayableContainerType.from(string: searchCategoryStringRaw) else {
                failure(NSError.error(code: .missingParameter, failureReason: "searchCategory is not valid."))
                return
            }
            if let shuffleStringRaw = parameters.first(where: {$0.key == NSUserActivity.ActivityKeys.shuffleOption.rawValue} )?.value,
               let shuffleRaw = Int(shuffleStringRaw),
               shuffleRaw <= 1 {
                shuffleOption = shuffleRaw == 1
            }
            if let repeatStringRaw = parameters.first(where: {$0.key == NSUserActivity.ActivityKeys.repeatOption.rawValue} )?.value,
               let repeatRaw = Int16(repeatStringRaw),
               let repeatInput = RepeatMode(rawValue: repeatRaw) {
                repeatOption = repeatInput
            }
            let playableContainer = self.getPlayableContainer(searchTerm: searchTerm, searchCategory: searchCategory)
            self.play(container: playableContainer, shuffleOption: shuffleOption, repeatOption: repeatOption)
            success(nil)
        }
        
        // Play
        // url example: amperfy://x-callback-url/play
        // action: play
        CallbackURLKit.register(action: "play") { parameters, success, failure, cancel in
            self.player.play()
            success(nil)
        }
        
        // Pause
        // url example: amperfy://x-callback-url/pause
        // action: pause
        CallbackURLKit.register(action: "pause") { parameters, success, failure, cancel in
            self.player.pause()
            success(nil)
        }
        
        // TogglePlayPause
        // url example: amperfy://x-callback-url/togglePlayPause
        // action: togglePlayPause
        CallbackURLKit.register(action: "togglePlayPause") { parameters, success, failure, cancel in
            self.player.togglePlayPause()
            success(nil)
        }
        
        // PlayNext
        // url example: amperfy://x-callback-url/playNext
        // action: playNext
        CallbackURLKit.register(action: "playNext") { parameters, success, failure, cancel in
            self.player.playNext()
            success(nil)
        }
        
        // PlayPreviousOrReplay
        // url example: amperfy://x-callback-url/playPreviousOrReplay
        // action: playPreviousOrReplay
        CallbackURLKit.register(action: "playPreviousOrReplay") { parameters, success, failure, cancel in
            self.player.playPreviousOrReplay()
            success(nil)
        }
        
        // SetShuffle
        // url example: amperfy://x-callback-url/setShuffle?shuffleOption=1
        // action: setShuffle
        // parameter mandatory: shuffleOption: 0 or 1
        CallbackURLKit.register(action: "setShuffle") { parameters, success, failure, cancel in
            guard let shuffleStringRaw = parameters.first(where: {$0.key == NSUserActivity.ActivityKeys.shuffleOption.rawValue} )?.value else {
                failure(NSError.error(code: .missingParameter, failureReason: "shuffleOption not provided."))
                return
            }
            guard let shuffleRaw = Int(shuffleStringRaw),
                  shuffleRaw >= 0,
                  shuffleRaw <= 1 else {
                failure(NSError.error(code: .missingParameter, failureReason: "shuffleOption is not valid."))
                return
            }
            if self.player.isShuffle, shuffleRaw == 0 {
                self.player.toggleShuffle()
            } else if !self.player.isShuffle, shuffleRaw == 1 {
                self.player.toggleShuffle()
            }
            success(nil)
        }
        
        // SetRepeat
        // url example: amperfy://x-callback-url/setRepeat?repeatOption=2
        // action: setRepeat
        // parameter mandatory: repeatOption: 0 (off), 1 (all), 2 (single)
        CallbackURLKit.register(action: "setRepeat") { parameters, success, failure, cancel in
            guard let repeatStringRaw = parameters.first(where: {$0.key == NSUserActivity.ActivityKeys.repeatOption.rawValue} )?.value else {
                failure(NSError.error(code: .missingParameter, failureReason: "repeatOption not provided."))
                return
            }
            guard let repeatRaw = Int16(repeatStringRaw),
                  let repeatInput = RepeatMode(rawValue: repeatRaw) else {
                failure(NSError.error(code: .missingParameter, failureReason: "repeatOption is not valid."))
                return
            }
            self.player.setRepeatMode(repeatInput)
            success(nil)
        }
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

            let playableContainer = self.getPlayableContainer(searchTerm: searchTerm, searchCategory: searchCategory)
            play(container: playableContainer, shuffleOption: shuffleOption, repeatOption: repeatOption)
        }
        return true
    }
    
    private func getPlayableContainer(searchTerm: String, searchCategory: PlayableContainerType) -> PlayableContainable? {
        var playableContainer: PlayableContainable?
        
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
        return playableContainer
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
