//
//  IntentManager.swift
//  AmperfyKit
//
//  Created by Maximilian Bauer on 06.06.22.
//  Copyright (c) 2022 Maximilian Bauer. All rights reserved.
//
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program.  If not, see <http://www.gnu.org/licenses/>.
//

import Foundation
import Intents
import CallbackURLKit
import Fuse
import OSLog

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
    
    public static var allCasesDescription: String {
        return "artist, song, podcastEpisode, playlist, album, genre, podcast"
    }
}

public struct XCallbackActionParameterDocu: Hashable {
    public var id = UUID()
    public var name: String
    public var type: String
    public var isMandatory: Bool
    public var description: String
    public var defaultIfNotGiven: String?
}

public struct XCallbackActionDocu: Hashable {
    public var id = UUID()
    public var name: String
    public var description: String
    public var exampleURLs: [String]
    public var action: String
    public var parameters: [XCallbackActionParameterDocu]
}

public class IntentManager {
    
    public private(set) var documentation: [XCallbackActionDocu]
    private let storage: PersistentStorage
    private let library: LibraryStorage
    private let player: PlayerFacade
    
    init(storage: PersistentStorage, library: LibraryStorage, player: PlayerFacade) {
        self.storage = storage
        self.library = library
        self.player = player
        self.documentation = [XCallbackActionDocu]()
    }
    
    public lazy var log = {
        return OSLog(subsystem: "Amperfy", category: "IntentManager")
    }()
    
    /// URLs to handle need to define in Project -> Targerts: Amperfy -> Info -> URL Types
    public func handleIncoming(url: URL) -> Bool {
        return Manager.shared.handleOpen(url: url)
    }
    
    public func registerXCallbackURLs() {
        // get the first from Info.plist using utility method
        Manager.shared.callbackURLScheme = Manager.urlSchemes?.first
        
        // [url-scheme]://x-callback-url/[action]?[x-callback parameters]&[action parameters]
        
        documentation.append(XCallbackActionDocu(
            name: "SearchAndPlay",
            description: "Plays the first search result for searchTerm in searchCategory with the given player options",
            exampleURLs: [
                "amperfy://x-callback-url/searchAndPlay?searchTerm=Awesome&searchCategory=playlist",
                "amperfy://x-callback-url/searchAndPlay?searchTerm=Example&searchCategory=artist&shuffleOption=1&repeatOption=2"
            ],
            action: "searchAndPlay",
            parameters: [
                XCallbackActionParameterDocu(
                    name: NSUserActivity.ActivityKeys.searchTerm.rawValue,
                    type: "String",
                    isMandatory: true,
                    description: "Query term to search for"
                ),
                XCallbackActionParameterDocu(
                    name: NSUserActivity.ActivityKeys.searchCategory.rawValue,
                    type: "String",
                    isMandatory: true,
                    description: PlayableContainerType.allCasesDescription
                ),
                XCallbackActionParameterDocu(
                    name: NSUserActivity.ActivityKeys.shuffleOption.rawValue,
                    type: "Int",
                    isMandatory: false,
                    description: "0 (false) or 1 (true)",
                    defaultIfNotGiven: "false"
                ),
                XCallbackActionParameterDocu(
                    name: NSUserActivity.ActivityKeys.repeatOption.rawValue,
                    type: "Int",
                    isMandatory: false,
                    description: "0 (off), 1 (all), 2 (single)",
                    defaultIfNotGiven: "off"
                ),
            ])
        )
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
        
        documentation.append(XCallbackActionDocu(
            name: "PlayID",
            description: "Plays the library element with the given ID and player options",
            exampleURLs: [
                "amperfy://x-callback-url/playID?id=123456&libraryElementType=playlist",
                "amperfy://x-callback-url/playID?id=aa2349&libraryElementType=artist&shuffleOption=1&repeatOption=2"
            ],
            action: "playID",
            parameters: [
                XCallbackActionParameterDocu(
                    name: NSUserActivity.ActivityKeys.id.rawValue,
                    type: "String",
                    isMandatory: true,
                    description: "ID of the library element"
                ),
                XCallbackActionParameterDocu(
                    name: NSUserActivity.ActivityKeys.libraryElementType.rawValue,
                    type: "String",
                    isMandatory: true,
                    description: PlayableContainerType.allCasesDescription
                ),
                XCallbackActionParameterDocu(
                    name: NSUserActivity.ActivityKeys.shuffleOption.rawValue,
                    type: "Int",
                    isMandatory: false,
                    description: "0 (false) or 1 (true)",
                    defaultIfNotGiven: "false"
                ),
                XCallbackActionParameterDocu(
                    name: NSUserActivity.ActivityKeys.repeatOption.rawValue,
                    type: "Int",
                    isMandatory: false,
                    description: "0 (off), 1 (all), 2 (single)",
                    defaultIfNotGiven: "off"
                ),
            ])
        )
        CallbackURLKit.register(action: "playID") { parameters, success, failure, cancel in
            var shuffleOption = false
            var repeatOption = RepeatMode.off
            
            guard let id = parameters.first(where: {$0.key == NSUserActivity.ActivityKeys.id.rawValue} )?.value else {
                failure(NSError.error(code: .missingParameter, failureReason: "ID not provided."))
                return
            }
            guard let libraryElementTypeRaw = parameters.first(where: {$0.key == NSUserActivity.ActivityKeys.libraryElementType.rawValue} )?.value else {
                failure(NSError.error(code: .missingParameter, failureReason: "Library element type not provided."))
                return
            }
            guard let libraryElementType = PlayableContainerType.from(string: libraryElementTypeRaw) else {
                failure(NSError.error(code: .missingParameter, failureReason: "Library element type is not valid."))
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
            let playableContainer = self.getPlayableContainer(id: id, libraryElementType: libraryElementType)
            self.play(container: playableContainer, shuffleOption: shuffleOption, repeatOption: repeatOption)
            success(nil)
        }
        
        documentation.append(XCallbackActionDocu(
            name: "PlayRandomSongs",
            description: "Plays \(player.maxSongsToAddOnce) random songs from library",
            exampleURLs: [
                "amperfy://x-callback-url/playRandomSongs",
                "amperfy://x-callback-url/playRandomSongs?onlyCached=1"
            ],
            action: "playRandomSongs",
            parameters: [
                XCallbackActionParameterDocu(
                    name: NSUserActivity.ActivityKeys.onlyCached.rawValue,
                    type: "Int",
                    isMandatory: false,
                    description: "0 (false) or 1 (true), use only cached songs from library",
                    defaultIfNotGiven: "false"
                ),
            ])
        )
        CallbackURLKit.register(action: "playRandomSongs") { parameters, success, failure, cancel in
            var isOnlyUseCached = false
            if let onlyCachedStringRaw = parameters.first(where: {$0.key == NSUserActivity.ActivityKeys.onlyCached.rawValue} )?.value,
               let onlyCachedRaw = Int(onlyCachedStringRaw),
               onlyCachedRaw <= 1 {
                isOnlyUseCached = onlyCachedRaw == 1
            }
            
            let songs = self.library.getSongs().filterCached(dependigOn: isOnlyUseCached)[randomPick: self.player.maxSongsToAddOnce]
            let playerContext = PlayContext(name: "Random Songs", playables: songs)
            self.player.play(context: playerContext)
            success(nil)
        }
        
        documentation.append(XCallbackActionDocu(
            name: "Play",
            description: "Changes the play state of the player to play",
            exampleURLs: [
                "amperfy://x-callback-url/play"
            ],
            action: "play",
            parameters: [
            ])
        )
        CallbackURLKit.register(action: "play") { parameters, success, failure, cancel in
            self.player.play()
            success(nil)
        }
        
        documentation.append(XCallbackActionDocu(
            name: "Pause",
            description: "Changes the play state of the player to pause",
            exampleURLs: [
                "amperfy://x-callback-url/pause"
            ],
            action: "pause",
            parameters: [
            ])
        )
        CallbackURLKit.register(action: "pause") { parameters, success, failure, cancel in
            self.player.pause()
            success(nil)
        }
        
        documentation.append(XCallbackActionDocu(
            name: "TogglePlayPause",
            description: "Toggles the play state of the player (play/pause)",
            exampleURLs: [
                "amperfy://x-callback-url/togglePlayPause"
            ],
            action: "togglePlayPause",
            parameters: [
            ])
        )
        CallbackURLKit.register(action: "togglePlayPause") { parameters, success, failure, cancel in
            self.player.togglePlayPause()
            success(nil)
        }
        
        documentation.append(XCallbackActionDocu(
            name: "PlayNext",
            description: "The next track will be played",
            exampleURLs: [
                "amperfy://x-callback-url/playNext"
            ],
            action: "playNext",
            parameters: [
            ])
        )
        CallbackURLKit.register(action: "playNext") { parameters, success, failure, cancel in
            self.player.playNext()
            success(nil)
        }
        
        documentation.append(XCallbackActionDocu(
            name: "PlayPreviousOrReplay",
            description: "The previous track will be played (if the tracked plays longer than \(AudioPlayer.replayInsteadPlayPreviousTimeInSec) seconds the track starts from the beginning)",
            exampleURLs: [
                "amperfy://x-callback-url/playPreviousOrReplay"
            ],
            action: "playPreviousOrReplay",
            parameters: [
            ])
        )
        CallbackURLKit.register(action: "playPreviousOrReplay") { parameters, success, failure, cancel in
            self.player.playPreviousOrReplay()
            success(nil)
        }
        
        documentation.append(XCallbackActionDocu(
            name: "SetShuffle",
            description: "Sets the shuffle state of the player",
            exampleURLs: [
                "amperfy://x-callback-url/setShuffle?shuffleOption=1"
            ],
            action: "setShuffle",
            parameters: [
                XCallbackActionParameterDocu(
                    name: NSUserActivity.ActivityKeys.shuffleOption.rawValue,
                    type: "Int",
                    isMandatory: true,
                    description: "0 (false) or 1 (true)"
                )
            ])
        )
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
        
        documentation.append(XCallbackActionDocu(
            name: "SetRepeat",
            description: "Sets the shuffle state of the player",
            exampleURLs: [
                "amperfy://x-callback-url/setRepeat?repeatOption=2"
            ],
            action: "setRepeat",
            parameters: [
                XCallbackActionParameterDocu(
                    name: NSUserActivity.ActivityKeys.repeatOption.rawValue,
                    type: "Int",
                    isMandatory: true,
                    description: "0 (off), 1 (all), 2 (single)"
                ),
            ])
        )
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
        
        documentation.append(XCallbackActionDocu(
            name: "SetOfflineMode",
            description: "Sets the Amperfy offline mode to active/inactive",
            exampleURLs: [
                "amperfy://x-callback-url/setOfflineMode?offlineMode=1"
            ],
            action: "setOfflineMode",
            parameters: [
                XCallbackActionParameterDocu(
                    name: NSUserActivity.ActivityKeys.offlineMode.rawValue,
                    type: "Int",
                    isMandatory: true,
                    description: "0 (inactive) or 1 (active)"
                ),
            ])
        )
        CallbackURLKit.register(action: "setOfflineMode") { parameters, success, failure, cancel in
            guard let offlineModeStringRaw = parameters.first(where: {$0.key == NSUserActivity.ActivityKeys.offlineMode.rawValue} )?.value else {
                failure(NSError.error(code: .missingParameter, failureReason: "offlineMode not provided."))
                return
            }
            guard let offlineMode = Int(offlineModeStringRaw),
                  offlineMode >= 0,
                  offlineMode <= 1 else {
                failure(NSError.error(code: .missingParameter, failureReason: "offlineMode is not valid."))
                return
            }
            self.storage.settings.isOfflineMode = offlineMode == 1
            success(nil)
        }
    }
    
    public func handleIncomingPlayMediaIntent(playMediaIntent: INPlayMediaIntent) -> Bool {
        // intent interpretion is only working if media search is provided
        guard let mediaSearch = playMediaIntent.mediaSearch else {
            os_log("No media search provided", log: self.log, type: .error)
            return false
        }
#if false // use for debug only
        os_log("playMediaIntent: %s", log: self.log, type: .debug, playMediaIntent.debugDescription)
        os_log("mediaSearch: %s", log: self.log, type: .debug, mediaSearch.debugDescription)
#endif
        
        var playableContainer: PlayableContainable?
        var playableElements: [AbstractPlayable]?
        let playableContainerType = PlayableContainerType.fromINMediaItemType(type: mediaSearch.mediaType)
        if playableContainerType != .unknown || mediaSearch.mediaType == .music {
            // media type is provided by user
            // "play music" => mediaType: 18
            // "play podcasts" => mediaType: 6
            // "play song <blub> by <artist>" => mediaType: 1; mediaName: blub; artistNames: artist
            // "play song <blub>" => mediaType: 1; mediaName: blub; artistNames: -
            // "play album <blub>" => mediaType: 2; mediaName: blub; artistNames: -
            // "play artist <blub>" => mediaType: 3; mediaName: blub; artistNames: -
            // "play <Rock>" => mediaType: 4; mediaName: -; artistNames: -; genreNames: Rock
            // "play playlist <blub>" => mediaType: 5; mediaName: blub; artistNames: -
            // "play podcast <blub>" => mediaType: 6; mediaName: blub; artistNames: -
            if let mediaName = mediaSearch.mediaName {
                os_log("Search explicitly in %ss: <%s>", log: self.log, type: .info, playableContainerType.description, mediaName)
                playableContainer = self.getPlayableContainer(searchTerm: mediaName, searchCategory: playableContainerType)
            } else if mediaSearch.mediaType == .music {
                os_log("Play Music", log: self.log, type: .info)
                playableElements = library.getRandomSongs(onlyCached: storage.settings.isOfflineMode)
            } else if mediaSearch.mediaType == .podcastShow ||
                      mediaSearch.mediaType == .podcastEpisode ||
                      mediaSearch.mediaType == .podcastStation ||
                      mediaSearch.mediaType == .podcastPlaylist {
                os_log("Play Podcasts", log: self.log, type: .info)
                playableElements = library.getNewestPodcastEpisode(count: 1)
            } else if let genres = mediaSearch.genreNames {
                os_log("Search explicitly in genres: <%s>", log: self.log, type: .info, genres.joined(separator: ", "))
                for genre in genres {
                    guard playableContainer == nil else { break }
                    os_log("Search explicitly in genre: <%s>", log: self.log, type: .info, genre)
                    playableContainer = self.getPlayableContainer(searchTerm: genre, searchCategory: .genre)
                }
            }
        } else {
            // Do a full search due to missing media type
            if let mediaName = mediaSearch.mediaName {
                // "play <title>" => mediaType: 0; mediaName: title; artistNames: -
                // "play <title> by <artist>" => mediaType: 0; mediaName: title; artistNames: artist
                if let artistName = mediaSearch.artistName {
                    os_log("Search implicitly in songs: <%s> - <%s>", log: self.log, type: .info, artistName, mediaName)
                    playableContainer = self.getSong(songName: mediaName, artistName: artistName)
                }
                if playableContainer == nil {
                    os_log("Search implicitly in playlists: <%s>", log: self.log, type: .info, mediaName)
                    playableContainer = self.getPlayableContainer(searchTerm: mediaName, searchCategory: .playlist)
                }
                if playableContainer == nil {
                    os_log("Search implicitly in artists: <%s>", log: self.log, type: .info, mediaName)
                    playableContainer = self.getPlayableContainer(searchTerm: mediaName, searchCategory: .artist)
                }
                if playableContainer == nil {
                    os_log("Search implicitly in podcasts: <%s>", log: self.log, type: .info, mediaName)
                    playableContainer = self.getPlayableContainer(searchTerm: mediaName, searchCategory: .podcast)
                }
                if playableContainer == nil {
                    os_log("Search implicitly in albums: <%s>", log: self.log, type: .info, mediaName)
                    playableContainer = self.getPlayableContainer(searchTerm: mediaName, searchCategory: .album)
                }
                if playableContainer == nil {
                    os_log("Search implicitly in songs: <%s>", log: self.log, type: .info, mediaName)
                    playableContainer = self.getPlayableContainer(searchTerm: mediaName, searchCategory: .song)
                }
                if playableContainer == nil {
                    os_log("Search implicitly in podcastEpisodes: <%s>", log: self.log, type: .info, mediaName)
                    playableContainer = self.getPlayableContainer(searchTerm: mediaName, searchCategory: .podcastEpisode)
                }
            } else if let genres = mediaSearch.genreNames {
                os_log("Search implicitly in genres: <%s>", log: self.log, type: .info, genres.joined(separator: ", "))
                for genre in genres {
                    guard playableContainer == nil else { break }
                    os_log("Search implicitly in genre: <%s>", log: self.log, type: .info, genre)
                    playableContainer = self.getPlayableContainer(searchTerm: genre, searchCategory: .genre)
                }
            }
        }
        
        let shuffleOption = playMediaIntent.playShuffled ?? false
        let repeatOption = RepeatMode.fromINPlaybackRepeatMode(mode: playMediaIntent.playbackRepeatMode)
        
        if let playableContainer = playableContainer {
            os_log("Play container <%s> (shuffle: %s, repeat: %s)", log: self.log, type: .info, playableContainer.name, shuffleOption.description, repeatOption.description)
            play(container: playableContainer, shuffleOption: shuffleOption, repeatOption: repeatOption)
            return true
        } else if let playableElements = playableElements{
            os_log("Play Music (shuffle: %s, repeat: %s)", log: self.log, type: .info, shuffleOption.description, repeatOption.description)
            play(context: PlayContext(name: "Siri Command", playables: playableElements), shuffleOption: shuffleOption, repeatOption: repeatOption)
            return true
        }
        os_log("No playable container found", log: self.log, type: .error)
        return false
    }
    
    public func handleIncomingIntent(userActivity: NSUserActivity) -> Bool {
        guard userActivity.activityType == NSStringFromClass(SearchAndPlayIntent.self) ||
              userActivity.activityType == NSUserActivity.searchAndPlayActivityType ||
              userActivity.activityType == NSStringFromClass(PlayIDIntent.self) ||
              userActivity.activityType == NSUserActivity.playIdActivityType
            else {
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
        } else if userActivity.activityType == NSUserActivity.playIdActivityType,
           let id = userActivity.userInfo?[NSUserActivity.ActivityKeys.id.rawValue] as? String,
           let libraryElementTypeRaw = userActivity.userInfo?[NSUserActivity.ActivityKeys.libraryElementType.rawValue] as? Int,
           let libraryElementType = PlayableContainerType(rawValue: libraryElementTypeRaw) {
            
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

            let playableContainer = self.getPlayableContainer(id: id, libraryElementType: libraryElementType)
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
            playableContainer = self.findBestMatch(in: library.getSongs(), search: searchTerm).first
        case .artist:
            playableContainer = self.findBestMatch(in: library.getArtists(), search: searchTerm).first
        case .podcastEpisode:
            playableContainer = self.findBestMatch(in: library.getPodcastEpisodes(), search: searchTerm).first
        case .playlist:
            playableContainer = self.findBestMatch(in: library.getPlaylists(), search: searchTerm).first
        case .album:
            playableContainer = self.findBestMatch(in: library.getAlbums(), search: searchTerm).first
        case .genre:
            playableContainer = self.findBestMatch(in: library.getGenres(), search: searchTerm).first
        case .podcast:
            playableContainer = self.findBestMatch(in: library.getPodcasts(), search: searchTerm).first
        }
        return playableContainer
    }
    
    private func getSong(songName: String, artistName: String) -> PlayableContainable? {
        let foundPlayables = self.findBestMatch(in: library.getSongs(), search: songName)
        let foundSongs = foundPlayables.compactMap { $0 as? Song }
        let artists = foundSongs.compactMap { $0.artist }
        let matchingArtistsRaw = self.findBestMatch(in: artists, search: artistName)
        let matchingArtists = matchingArtistsRaw.compactMap { $0 as? Artist }
        let foundSong = foundSongs.lazy.filter { song in matchingArtists.contains(where: { artist in song.artist == artist}) }.first
        return foundSong
    }
    
    struct MatchResult {
        let item: PlayableContainable
        let score: Double
    }
    
    static let fuzzyMatchThreshold = 0.2 // A score be below this value (0 (exact match) and 1 (not a match)) will result in a match
    
    private func findBestMatch(in items: [PlayableContainable], search: String) -> [PlayableContainable] {
        let fuse = Fuse()
        // Improve performance by creating the pattern once
        let pattern = fuse.createPattern(from: search)

        var matches = [MatchResult]()
        items.forEach {
            let result = fuse.search(pattern, in: $0.name)
            if let result = result, result.score <= Self.fuzzyMatchThreshold {
                matches.append(MatchResult(item: $0, score: result.score))
            }
        }
        let sortedMatches = matches.sorted(by: {$0.score < $1.score})
        return sortedMatches.compactMap { $0.item }
    }
    
    private func getPlayableContainer(id: String, libraryElementType: PlayableContainerType) -> PlayableContainable? {
        var playableContainer: PlayableContainable?
        
        switch libraryElementType {
        case .unknown:
            fallthrough
        case .song:
            playableContainer = library.getSong(id: id)
        case .artist:
            playableContainer = library.getArtist(id: id)
        case .podcastEpisode:
            playableContainer = library.getPodcastEpisode(id: id)
        case .playlist:
            playableContainer = library.getPlaylist(id: id)
        case .album:
            playableContainer = library.getAlbum(id: id)
        case .genre:
            playableContainer = library.getGenre(id: id)
        case .podcast:
            playableContainer = library.getPodcast(id: id)
        }
        return playableContainer
    }

    private func play(container: PlayableContainable?, shuffleOption: Bool, repeatOption: RepeatMode) {
        guard let container = container else { return }
        play(context: PlayContext(containable: container), shuffleOption: shuffleOption, repeatOption: repeatOption)
    }
    
    private func play(context: PlayContext, shuffleOption: Bool, repeatOption: RepeatMode) {
        if shuffleOption {
            player.playShuffled(context: context)
        } else {
            player.play(context: context)
        }
        player.setRepeatMode(repeatOption)
    }
    
}

extension PlayableContainerType {
    public var description: String {
        switch (self) {
        case .unknown:
            return "unknown"
        case .artist:
            return "artist"
        case .song:
            return "song"
        case .podcastEpisode:
            return "podcastEpisode"
        case .playlist:
            return "playlist"
        case .album:
            return "album"
        case .genre:
            return "genre"
        case .podcast:
            return "podcast"
        }
    }
}

extension PlayableContainerType {
    static public func fromINMediaItemType(type: INMediaItemType) -> PlayableContainerType {
        switch (type) {
        case .unknown:
            return .unknown
        case .song:
            return .song
        case .album:
            return .album
        case .artist:
            return .artist
        case .genre:
            return .genre
        case .playlist:
            return .playlist
        case .podcastShow:
            return .podcast
        case .podcastEpisode:
            return .podcastEpisode
        case .podcastPlaylist:
            return .podcast
        case .musicStation:
            return .unknown
        case .audioBook:
            return .unknown
        case .movie:
            return .unknown
        case .tvShow:
            return .unknown
        case .tvShowEpisode:
            return .unknown
        case .musicVideo:
            return .unknown
        case .podcastStation:
            return .podcast
        case .radioStation:
            return .unknown
        case .station:
            return .unknown
        case .music:
            return .unknown
        case .algorithmicRadioStation:
            return .unknown
        case .news:
            return .unknown
        @unknown default:
            return .unknown
        }
    }
}
