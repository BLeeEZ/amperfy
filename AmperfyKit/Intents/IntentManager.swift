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
