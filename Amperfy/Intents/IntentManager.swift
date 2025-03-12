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

import AmperfyKit
import CallbackURLKit
import Foundation
import Ifrit
import Intents
import OSLog

extension RepeatMode {
  public static func fromIntent(type: RepeatType) -> RepeatMode {
    switch type {
    case .unknown:
      return .off
    case .single:
      return .single
    case .all:
      return .all
    case .off:
      return .off
    }
  }
}

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
    "artist, song, podcastEpisode, playlist, album, genre, podcast"
  }
}

// MARK: - XCallbackActionParameterDocu

public struct XCallbackActionParameterDocu: Hashable {
  public var id = UUID()
  public var name: String
  public var type: String
  public var isMandatory: Bool
  public var description: String
  public var defaultIfNotGiven: String?
}

// MARK: - XCallbackActionDocu

public struct XCallbackActionDocu: Hashable {
  public var id = UUID()
  public var name: String
  public var description: String
  public var exampleURLs: [String]
  public var action: String
  public var parameters: [XCallbackActionParameterDocu]
}

// MARK: - IntentManager

@MainActor
public class IntentManager {
  public private(set) var documentation: [XCallbackActionDocu]
  private let storage: PersistentStorage
  private let librarySyncer: LibrarySyncer
  private let playableDownloadManager: DownloadManageable
  private let library: LibraryStorage
  private let player: PlayerFacade
  private let networkMonitor: NetworkMonitorFacade
  private let eventLogger: EventLogger
  private var lastResult: AmperfyMediaIntentItemResult?

  init(
    storage: PersistentStorage,
    librarySyncer: LibrarySyncer,
    playableDownloadManager: DownloadManageable,
    library: LibraryStorage,
    player: PlayerFacade,
    networkMonitor: NetworkMonitorFacade,
    eventLogger: EventLogger
  ) {
    self.storage = storage
    self.librarySyncer = librarySyncer
    self.playableDownloadManager = playableDownloadManager
    self.library = library
    self.player = player
    self.networkMonitor = networkMonitor
    self.eventLogger = eventLogger
    self.documentation = [XCallbackActionDocu]()
  }

  public lazy var log = {
    OSLog(subsystem: "Amperfy", category: "IntentManager")
  }()

  /// URLs to handle need to define in Project -> Targerts: Amperfy -> Info -> URL Types
  public func handleIncoming(url: URL) -> Bool {
    Manager.shared.handleOpen(url: url)
  }

  public func registerXCallbackURLs() {
    // get the first from Info.plist using utility method
    Manager.shared.callbackURLScheme = Manager.urlSchemes?.first

    // [url-scheme]://x-callback-url/[action]?[x-callback parameters]&[action parameters]

    documentation.append(
      XCallbackActionDocu(
        name: "SearchAndPlay",
        description: "Plays the first search result for searchTerm in searchCategory with the given player options",
        exampleURLs: [
          "amperfy://x-callback-url/searchAndPlay?searchTerm=Awesome&searchCategory=playlist",
          "amperfy://x-callback-url/searchAndPlay?searchTerm=Example&searchCategory=artist&shuffleOption=1&repeatOption=2",
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
        ]
      )
    )
    CallbackURLKit.register(action: "searchAndPlay") { parameters, success, failure, cancel in
      var shuffleOption = false
      var repeatOption = RepeatMode.off

      guard let searchTerm = parameters
        .first(where: { $0.key == NSUserActivity.ActivityKeys.searchTerm.rawValue })?.value
      else {
        failure(NSError.error(
          code: .missingParameter,
          failureReason: "Parameter searchTerm not provided."
        ))
        return
      }
      guard let searchCategoryStringRaw = parameters
        .first(where: { $0.key == NSUserActivity.ActivityKeys.searchCategory.rawValue })?.value
      else {
        failure(NSError.error(
          code: .missingParameter,
          failureReason: "Parameter searchCategory not provided."
        ))
        return
      }
      guard let searchCategory = PlayableContainerType.from(string: searchCategoryStringRaw) else {
        failure(NSError.error(
          code: .missingParameter,
          failureReason: "Parameter searchCategory is not valid."
        ))
        return
      }
      if let shuffleStringRaw = parameters
        .first(where: { $0.key == NSUserActivity.ActivityKeys.shuffleOption.rawValue })?.value,
        let shuffleRaw = Int(shuffleStringRaw),
        shuffleRaw <= 1 {
        shuffleOption = shuffleRaw == 1
      }
      if let repeatStringRaw = parameters
        .first(where: { $0.key == NSUserActivity.ActivityKeys.repeatOption.rawValue })?.value,
        let repeatRaw = Int16(repeatStringRaw),
        let repeatInput = RepeatMode(rawValue: repeatRaw) {
        repeatOption = repeatInput
      }
      let playableContainer = self.getPlayableContainer(
        searchTerm: searchTerm,
        searchCategory: searchCategory
      )
      Task { @MainActor in
        let playSuccess = await self.play(
          container: playableContainer,
          shuffleOption: shuffleOption,
          repeatOption: repeatOption
        )
        if playSuccess {
          success(nil)
        } else {
          failure(NSError.error(
            code: .missingErrorCode,
            failureReason: "Requested element could not be played."
          ))
        }
      }
    }

    documentation.append(
      XCallbackActionDocu(
        name: "PlayID",
        description: "Plays the library element with the given ID and player options",
        exampleURLs: [
          "amperfy://x-callback-url/playID?id=123456&libraryElementType=playlist",
          "amperfy://x-callback-url/playID?id=aa2349&libraryElementType=artist&shuffleOption=1&repeatOption=2",
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
        ]
      )
    )
    CallbackURLKit.register(action: "playID") { parameters, success, failure, cancel in
      var shuffleOption = false
      var repeatOption = RepeatMode.off

      guard let id = parameters.first(where: { $0.key == NSUserActivity.ActivityKeys.id.rawValue })?
        .value else {
        failure(NSError.error(code: .missingParameter, failureReason: "Parameter id not provided."))
        return
      }
      guard let libraryElementTypeRaw = parameters
        .first(where: { $0.key == NSUserActivity.ActivityKeys.libraryElementType.rawValue })?
        .value
      else {
        failure(NSError.error(
          code: .missingParameter,
          failureReason: "Parameter libraryElementType not provided."
        ))
        return
      }
      guard let libraryElementType = PlayableContainerType.from(string: libraryElementTypeRaw)
      else {
        failure(NSError.error(
          code: .missingParameter,
          failureReason: "Parameter libraryElementType is not valid."
        ))
        return
      }
      if let shuffleStringRaw = parameters
        .first(where: { $0.key == NSUserActivity.ActivityKeys.shuffleOption.rawValue })?.value,
        let shuffleRaw = Int(shuffleStringRaw),
        shuffleRaw <= 1 {
        shuffleOption = shuffleRaw == 1
      }
      if let repeatStringRaw = parameters
        .first(where: { $0.key == NSUserActivity.ActivityKeys.repeatOption.rawValue })?.value,
        let repeatRaw = Int16(repeatStringRaw),
        let repeatInput = RepeatMode(rawValue: repeatRaw) {
        repeatOption = repeatInput
      }
      let playableContainer = self.getPlayableContainer(
        id: id,
        libraryElementType: libraryElementType
      )
      Task { @MainActor in
        let playSuccess = await self.play(
          container: playableContainer,
          shuffleOption: shuffleOption,
          repeatOption: repeatOption
        )
        if playSuccess {
          success(nil)
        } else {
          failure(NSError.error(
            code: .missingErrorCode,
            failureReason: "Requested element could not be played."
          ))
        }
      }
    }

    documentation.append(
      XCallbackActionDocu(
        name: "PlayRandomSongs",
        description: "Plays \(player.maxSongsToAddOnce) random songs from library",
        exampleURLs: [
          "amperfy://x-callback-url/playRandomSongs",
          "amperfy://x-callback-url/playRandomSongs?onlyCached=1",
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
        ]
      )
    )
    CallbackURLKit.register(action: "playRandomSongs") { parameters, success, failure, cancel in
      var isOnlyUseCached = false
      if let onlyCachedStringRaw = parameters
        .first(where: { $0.key == NSUserActivity.ActivityKeys.onlyCached.rawValue })?.value,
        let onlyCachedRaw = Int(onlyCachedStringRaw),
        onlyCachedRaw <= 1 {
        isOnlyUseCached = onlyCachedRaw == 1
      }

      let songs = self.library.getSongs()
        .filterCached(dependigOn: isOnlyUseCached)[randomPick: self.player.maxSongsToAddOnce]
      let playerContext = PlayContext(name: "Random Songs", playables: songs)
      self.player.play(context: playerContext)
      success(nil)
    }

    documentation.append(
      XCallbackActionDocu(
        name: "Play",
        description: "Changes the play state of the player to play",
        exampleURLs: [
          "amperfy://x-callback-url/play",
        ],
        action: "play",
        parameters: [
        ]
      )
    )
    CallbackURLKit.register(action: "play") { parameters, success, failure, cancel in
      self.player.play()
      success(nil)
    }

    documentation.append(
      XCallbackActionDocu(
        name: "Pause",
        description: "Changes the play state of the player to pause",
        exampleURLs: [
          "amperfy://x-callback-url/pause",
        ],
        action: "pause",
        parameters: [
        ]
      )
    )
    CallbackURLKit.register(action: "pause") { parameters, success, failure, cancel in
      self.player.pause()
      success(nil)
    }

    documentation.append(
      XCallbackActionDocu(
        name: "TogglePlayPause",
        description: "Toggles the play state of the player (play/pause)",
        exampleURLs: [
          "amperfy://x-callback-url/togglePlayPause",
        ],
        action: "togglePlayPause",
        parameters: [
        ]
      )
    )
    CallbackURLKit.register(action: "togglePlayPause") { parameters, success, failure, cancel in
      self.player.togglePlayPause()
      success(nil)
    }

    documentation.append(
      XCallbackActionDocu(
        name: "PlayNext",
        description: "The next track will be played",
        exampleURLs: [
          "amperfy://x-callback-url/playNext",
        ],
        action: "playNext",
        parameters: [
        ]
      )
    )
    CallbackURLKit.register(action: "playNext") { parameters, success, failure, cancel in
      self.player.playNext()
      success(nil)
    }

    documentation.append(
      XCallbackActionDocu(
        name: "PlayPreviousOrReplay",
        description: "The previous track will be played (if the tracked plays longer than \(AudioPlayer.replayInsteadPlayPreviousTimeInSec) seconds the track starts from the beginning)",
        exampleURLs: [
          "amperfy://x-callback-url/playPreviousOrReplay",
        ],
        action: "playPreviousOrReplay",
        parameters: [
        ]
      )
    )
    CallbackURLKit
      .register(action: "playPreviousOrReplay") { parameters, success, failure, cancel in
        self.player.playPreviousOrReplay()
        success(nil)
      }

    documentation.append(
      XCallbackActionDocu(
        name: "SetShuffle",
        description: "Sets the shuffle state of the player",
        exampleURLs: [
          "amperfy://x-callback-url/setShuffle?shuffleOption=1",
        ],
        action: "setShuffle",
        parameters: [
          XCallbackActionParameterDocu(
            name: NSUserActivity.ActivityKeys.shuffleOption.rawValue,
            type: "Int",
            isMandatory: true,
            description: "0 (false) or 1 (true)"
          ),
        ]
      )
    )
    CallbackURLKit.register(action: "setShuffle") { parameters, success, failure, cancel in
      guard let shuffleStringRaw = parameters
        .first(where: { $0.key == NSUserActivity.ActivityKeys.shuffleOption.rawValue })?.value
      else {
        failure(NSError.error(
          code: .missingParameter,
          failureReason: "Parameter shuffleOption not provided."
        ))
        return
      }
      guard let shuffleRaw = Int(shuffleStringRaw),
            shuffleRaw >= 0,
            shuffleRaw <= 1 else {
        failure(NSError.error(
          code: .missingParameter,
          failureReason: "Parameter shuffleOption is not valid."
        ))
        return
      }
      if self.player.isShuffle, shuffleRaw == 0 {
        self.player.toggleShuffle()
      } else if !self.player.isShuffle, shuffleRaw == 1 {
        self.player.toggleShuffle()
      }
      success(nil)
    }

    documentation.append(
      XCallbackActionDocu(
        name: "SetRepeat",
        description: "Sets the shuffle state of the player",
        exampleURLs: [
          "amperfy://x-callback-url/setRepeat?repeatOption=2",
        ],
        action: "setRepeat",
        parameters: [
          XCallbackActionParameterDocu(
            name: NSUserActivity.ActivityKeys.repeatOption.rawValue,
            type: "Int",
            isMandatory: true,
            description: "0 (off), 1 (all), 2 (single)"
          ),
        ]
      )
    )
    CallbackURLKit.register(action: "setRepeat") { parameters, success, failure, cancel in
      guard let repeatStringRaw = parameters
        .first(where: { $0.key == NSUserActivity.ActivityKeys.repeatOption.rawValue })?.value
      else {
        failure(NSError.error(
          code: .missingParameter,
          failureReason: "Parameter repeatOption not provided."
        ))
        return
      }
      guard let repeatRaw = Int16(repeatStringRaw),
            let repeatInput = RepeatMode(rawValue: repeatRaw) else {
        failure(NSError.error(
          code: .missingParameter,
          failureReason: "Parameter repeatOption is not valid."
        ))
        return
      }
      self.player.setRepeatMode(repeatInput)
      success(nil)
    }

    documentation.append(
      XCallbackActionDocu(
        name: "SetOfflineMode",
        description: "Sets the Amperfy offline mode to active/inactive",
        exampleURLs: [
          "amperfy://x-callback-url/setOfflineMode?offlineMode=1",
        ],
        action: "setOfflineMode",
        parameters: [
          XCallbackActionParameterDocu(
            name: NSUserActivity.ActivityKeys.offlineMode.rawValue,
            type: "Int",
            isMandatory: true,
            description: "0 (inactive) or 1 (active)"
          ),
        ]
      )
    )
    CallbackURLKit.register(action: "setOfflineMode") { parameters, success, failure, cancel in
      guard let offlineModeStringRaw = parameters
        .first(where: { $0.key == NSUserActivity.ActivityKeys.offlineMode.rawValue })?.value
      else {
        failure(NSError.error(
          code: .missingParameter,
          failureReason: "Parameter offlineMode not provided."
        ))
        return
      }
      guard let offlineMode = Int(offlineModeStringRaw),
            offlineMode >= 0,
            offlineMode <= 1 else {
        failure(NSError.error(
          code: .missingParameter,
          failureReason: "Parameter offlineMode is not valid."
        ))
        return
      }
      self.storage.settings.isOfflineMode = offlineMode == 1
      success(nil)
    }

    documentation.append(
      XCallbackActionDocu(
        name: "RateCurrentlyPlayingSong",
        description: "Rate the currently playing song.",
        exampleURLs: [
          "amperfy://x-callback-url/rateCurrentlyPlayingSong?rating=0",
          "amperfy://x-callback-url/rateCurrentlyPlayingSong?rating=5",
        ],
        action: "rateCurrentlyPlayingSong",
        parameters: [
          XCallbackActionParameterDocu(
            name: NSUserActivity.ActivityKeys.rating.rawValue,
            type: "Int",
            isMandatory: true,
            description: "Rating must be between 0 and 5"
          ),
        ]
      )
    )
    CallbackURLKit
      .register(action: "rateCurrentlyPlayingSong") { parameters, success, failure, cancel in
        guard let ratingRaw = parameters
          .first(where: { $0.key == NSUserActivity.ActivityKeys.rating.rawValue })?.value else {
          failure(NSError.error(
            code: .missingParameter,
            failureReason: "Parameter rating not provided."
          ))
          return
        }
        guard let rating = Int(ratingRaw),
              rating >= 0,
              rating <= 5 else {
          failure(NSError.error(
            code: .missingParameter,
            failureReason: "Parameter rating is not valid. Must be between 0 and 5."
          ))
          return
        }
        guard self.storage.settings.isOnlineMode else {
          failure(NSError.error(
            code: .missingParameter,
            failureReason: "Rating can only be changed in Online Mode."
          ))
          return
        }
        guard let currentlyPlaying = self.player.currentlyPlaying else {
          failure(NSError.error(
            code: .missingParameter,
            failureReason: "There is no song currently playing."
          ))
          return
        }
        guard let song = currentlyPlaying.asSong else {
          failure(NSError.error(code: .missingParameter, failureReason: "Only songs can be rated."))
          return
        }

        song.rating = rating
        self.storage.main.saveContext()
        Task { @MainActor in
          do {
            try await self.librarySyncer.setRating(song: song, rating: rating)
          } catch {
            // ignore error here
          }
          success(nil)
        }
      }

    documentation.append(
      XCallbackActionDocu(
        name: "FavoriteCurrentlyPlayingSong",
        description: "Mark the currently playing song as favorite.",
        exampleURLs: [
          "amperfy://x-callback-url/favoriteCurrentlyPlayingSong?favorite=0",
          "amperfy://x-callback-url/favoriteCurrentlyPlayingSong?favorite=1",
        ],
        action: "favoriteCurrentlyPlayingSong",
        parameters: [
          XCallbackActionParameterDocu(
            name: NSUserActivity.ActivityKeys.favorite.rawValue,
            type: "Int",
            isMandatory: true,
            description: "0 (no favorite) or 1 (favorite)"
          ),
        ]
      )
    )
    CallbackURLKit
      .register(action: "favoriteCurrentlyPlayingSong") { parameters, success, failure, cancel in
        guard let favoriteRaw = parameters
          .first(where: { $0.key == NSUserActivity.ActivityKeys.favorite.rawValue })?.value
        else {
          failure(NSError.error(
            code: .missingParameter,
            failureReason: "Parameter favorite not provided."
          ))
          return
        }
        guard let favorite = Int(favoriteRaw),
              favorite >= 0,
              favorite <= 1 else {
          failure(NSError.error(
            code: .missingParameter,
            failureReason: "Parameter favorite is not valid."
          ))
          return
        }
        guard self.storage.settings.isOnlineMode else {
          failure(NSError.error(
            code: .missingParameter,
            failureReason: "Favorite can only be changed in Online Mode."
          ))
          return
        }

        guard let currentlyPlaying = self.player.currentlyPlaying else {
          failure(NSError.error(
            code: .missingParameter,
            failureReason: "There is no song currently playing."
          ))
          return
        }
        guard currentlyPlaying.isSong else {
          failure(NSError.error(code: .missingParameter, failureReason: "Only songs can be rated."))
          return
        }
        guard currentlyPlaying.isFavorite != (favorite == 1) else {
          // do nothing
          success(nil)
          return
        }

        Task { @MainActor in
          do {
            try await currentlyPlaying.remoteToggleFavorite(syncer: self.librarySyncer)
          } catch {
            // ignore error here
          }
          success(nil)
        }
      }
  }

  @MainActor
  public struct AmperfyMediaIntentItemResult {
    var playableContainer: PlayableContainable?
    var playableElements: [AbstractPlayable]?
    var item: INMediaItem
  }

  public func handleIncomingPlayMediaIntent(playMediaIntent: INPlayMediaIntent)
    -> AmperfyMediaIntentItemResult? {
    // intent interpretion is only working if media search is provided
    guard let mediaSearch = playMediaIntent.mediaSearch else {
      eventLogger.debug(topic: "Siri Play Media Intent", message: "Error: No media search provided")
      return nil
    }

    eventLogger.debug(
      topic: "Siri Play Media Intent",
      message: "Request details:\n \(playMediaIntent.description)\n\(mediaSearch.description)"
    )

    var result: AmperfyMediaIntentItemResult?
    let playableContainerType = PlayableContainerType
      .fromINMediaItemType(type: mediaSearch.mediaType)
    if playableContainerType != .unknown ||
      mediaSearch.mediaType == .music ||
      mediaSearch.mediaType == .radioStation ||
      mediaSearch.mediaType == .station ||
      mediaSearch.mediaType == .algorithmicRadioStation {
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
      if mediaSearch.mediaType == .music ||
        mediaSearch.mediaType == .radioStation ||
        mediaSearch.mediaType == .station ||
        mediaSearch.mediaType == .algorithmicRadioStation {
        os_log("Play Music", log: self.log, type: .info)
        let playableElements = library.getRandomSongs(onlyCached: storage.settings.isOfflineMode)
        result = AmperfyMediaIntentItemResult(
          playableElements: playableElements,
          item: INMediaItem(
            identifier: nil,
            title: "Random Songs",
            type: INMediaItemType.music,
            artwork: nil
          )
        )
      } else if mediaSearch.mediaType == .podcastShow ||
        mediaSearch.mediaType == .podcastEpisode ||
        mediaSearch.mediaType == .podcastStation ||
        mediaSearch.mediaType == .podcastPlaylist {
        os_log("Play Podcasts", log: self.log, type: .info)
        let playableElements = library.getNewestPodcastEpisode(count: 1)
        if !playableElements.isEmpty {
          result = AmperfyMediaIntentItemResult(
            playableElements: playableElements,
            item: INMediaItem(
              identifier: nil,
              title: playableElements[0].title,
              type: INMediaItemType.podcastEpisode,
              artwork: nil,
              artist: playableElements[0].creatorName
            )
          )
        }
      } else if let mediaName = mediaSearch.mediaName {
        os_log(
          "Search explicitly in %ss: <%s>",
          log: self.log,
          type: .info,
          playableContainerType.description,
          mediaName
        )
        if let playableContainer = getPlayableContainer(
          searchTerm: mediaName,
          searchCategory: playableContainerType
        ) {
          result = AmperfyMediaIntentItemResult(
            playableContainer: playableContainer,
            item: INMediaItem(
              identifier: nil,
              title: playableContainer.name,
              type: mediaSearch.mediaType,
              artwork: nil,
              artist: playableContainer.subsubtitle
            )
          )
        }
      } else if let genres = mediaSearch.genreNames {
        os_log(
          "Search explicitly in genres: <%s>",
          log: self.log,
          type: .info,
          genres.joined(separator: ", ")
        )
        for genre in genres {
          guard result == nil else { break }
          os_log("Search explicitly in genre: <%s>", log: self.log, type: .info, genre)
          if let playableContainer = getPlayableContainer(
            searchTerm: genre,
            searchCategory: .genre
          ) {
            result = AmperfyMediaIntentItemResult(
              playableContainer: playableContainer,
              item: INMediaItem(
                identifier: nil,
                title: genre,
                type: INMediaItemType.genre,
                artwork: nil
              )
            )
          }
        }
      }
    } else {
      // Do a full search due to missing media type
      if let mediaName = mediaSearch.mediaName {
        // "play <title>" => mediaType: 0; mediaName: title; artistNames: -
        // "play <title> by <artist>" => mediaType: 0; mediaName: title; artistNames: artist
        if let artistName = mediaSearch.artistName {
          os_log(
            "Search implicitly in songs: <%s> - <%s>",
            log: self.log,
            type: .info,
            artistName,
            mediaName
          )
          if let playableContainer = getSong(songName: mediaName, artistName: artistName) {
            result = AmperfyMediaIntentItemResult(
              playableContainer: playableContainer,
              item: INMediaItem(
                identifier: nil,
                title: playableContainer.name,
                type: INMediaItemType.song,
                artwork: nil,
                artist: playableContainer.subtitle
              )
            )
          }
        }
        if result == nil {
          os_log("Search implicitly in playlists: <%s>", log: self.log, type: .info, mediaName)
          if let playableContainer = getPlayableContainer(
            searchTerm: mediaName,
            searchCategory: .playlist
          ) {
            result = AmperfyMediaIntentItemResult(
              playableContainer: playableContainer,
              item: INMediaItem(
                identifier: nil,
                title: playableContainer.name,
                type: INMediaItemType.playlist,
                artwork: nil
              )
            )
          }
        }
        if result == nil {
          os_log("Search implicitly in artists: <%s>", log: self.log, type: .info, mediaName)
          if let playableContainer = getPlayableContainer(
            searchTerm: mediaName,
            searchCategory: .artist
          ) {
            result = AmperfyMediaIntentItemResult(
              playableContainer: playableContainer,
              item: INMediaItem(
                identifier: nil,
                title: playableContainer.name,
                type: INMediaItemType.artist,
                artwork: nil
              )
            )
          }
        }
        if result == nil {
          os_log("Search implicitly in podcasts: <%s>", log: self.log, type: .info, mediaName)
          if let playableContainer = getPlayableContainer(
            searchTerm: mediaName,
            searchCategory: .podcast
          ) {
            result = AmperfyMediaIntentItemResult(
              playableContainer: playableContainer,
              item: INMediaItem(
                identifier: nil,
                title: playableContainer.name,
                type: INMediaItemType.podcastShow,
                artwork: nil
              )
            )
          }
        }
        if result == nil {
          os_log("Search implicitly in albums: <%s>", log: self.log, type: .info, mediaName)
          if let playableContainer = getPlayableContainer(
            searchTerm: mediaName,
            searchCategory: .album
          ) {
            result = AmperfyMediaIntentItemResult(
              playableContainer: playableContainer,
              item: INMediaItem(
                identifier: nil,
                title: playableContainer.name,
                type: INMediaItemType.album,
                artwork: nil
              )
            )
          }
        }
        if result == nil {
          os_log("Search implicitly in songs: <%s>", log: self.log, type: .info, mediaName)
          if let playableContainer = getPlayableContainer(
            searchTerm: mediaName,
            searchCategory: .song
          ) {
            result = AmperfyMediaIntentItemResult(
              playableContainer: playableContainer,
              item: INMediaItem(
                identifier: nil,
                title: playableContainer.name,
                type: INMediaItemType.song,
                artwork: nil,
                artist: playableContainer.subtitle
              )
            )
          }
        }
        if result == nil {
          os_log(
            "Search implicitly in podcastEpisodes: <%s>",
            log: self.log,
            type: .info,
            mediaName
          )
          if let playableContainer = getPlayableContainer(
            searchTerm: mediaName,
            searchCategory: .podcastEpisode
          ) {
            result = AmperfyMediaIntentItemResult(
              playableContainer: playableContainer,
              item: INMediaItem(
                identifier: nil,
                title: playableContainer.name,
                type: INMediaItemType.podcastEpisode,
                artwork: nil,
                artist: playableContainer.subtitle
              )
            )
          }
        }
      } else if let genres = mediaSearch.genreNames {
        os_log(
          "Search implicitly in genres: <%s>",
          log: self.log,
          type: .info,
          genres.joined(separator: ", ")
        )
        for genre in genres {
          guard result == nil else { break }
          os_log("Search implicitly in genre: <%s>", log: self.log, type: .info, genre)
          if let playableContainer = getPlayableContainer(
            searchTerm: genre,
            searchCategory: .genre
          ) {
            result = AmperfyMediaIntentItemResult(
              playableContainer: playableContainer,
              item: INMediaItem(
                identifier: nil,
                title: playableContainer.name,
                type: INMediaItemType.genre,
                artwork: nil
              )
            )
          }
        }
      }
    }
    if let result = result {
      var playableDetailString = "-"
      if let playableContainer = result.playableContainer {
        playableDetailString = String(describing: playableContainer)
        playableDetailString += ": " + playableContainer.name
        if let subtitle = playableContainer.subtitle {
          playableDetailString += " - " + subtitle
        }
        if let subsubtitle = playableContainer.subsubtitle {
          playableDetailString += " - " + subsubtitle
        }
      }
      eventLogger.debug(
        topic: "Siri Play Media Intent",
        message: "Response:\n\(result.item.description)\nLibrary Element: \(playableDetailString)\nShuffle/Random Items Count: \(result.playableElements?.count ?? 0)"
      )
    } else {
      os_log("No playable container found", log: self.log, type: .info)
      eventLogger.debug(topic: "Siri Play Media Intent", message: "Response: No media found")
    }
    lastResult = result
    return result
  }

  @MainActor
  public func handleIncomingIntent(userActivity: NSUserActivity) async -> Bool {
    guard userActivity.activityType == NSStringFromClass(SearchAndPlayIntent.self) ||
      userActivity.activityType == NSUserActivity.searchAndPlayActivityType ||
      userActivity.activityType == NSStringFromClass(PlayIDIntent.self) ||
      userActivity.activityType == NSUserActivity.playIdActivityType ||
      userActivity.activityType == NSStringFromClass(PlayRandomSongsIntent.self) ||
      userActivity.activityType == NSUserActivity.playRandomSongsActivityType
    else {
      return false
    }
    if userActivity.activityType == NSUserActivity.searchAndPlayActivityType || userActivity
      .activityType == NSStringFromClass(SearchAndPlayIntent.self),
      let searchTerm = userActivity
      .userInfo?[NSUserActivity.ActivityKeys.searchTerm.rawValue] as? String,
      let searchCategoryRaw = userActivity
      .userInfo?[NSUserActivity.ActivityKeys.searchCategory.rawValue] as? Int,
      let searchCategory = PlayableContainerType(rawValue: searchCategoryRaw) {
      var shuffleOption = false
      var repeatOption = RepeatMode.off

      if let shuffleUserRaw = userActivity
        .userInfo?[NSUserActivity.ActivityKeys.shuffleOption.rawValue] as? Int,
        let shuffleUser = ShuffleType(rawValue: shuffleUserRaw) {
        shuffleOption = shuffleUser == .on
      }
      if let repeatUserRaw = userActivity
        .userInfo?[NSUserActivity.ActivityKeys.repeatOption.rawValue] as? Int,
        let repeatUser = RepeatType(rawValue: repeatUserRaw) {
        repeatOption = RepeatMode.fromIntent(type: repeatUser)
      }

      let playableContainer = getPlayableContainer(
        searchTerm: searchTerm,
        searchCategory: searchCategory
      )
      return await play(
        container: playableContainer,
        shuffleOption: shuffleOption,
        repeatOption: repeatOption
      )
    } else if userActivity.activityType == NSUserActivity.playIdActivityType || userActivity
      .activityType == NSStringFromClass(PlayIDIntent.self),
      let id = userActivity.userInfo?[NSUserActivity.ActivityKeys.id.rawValue] as? String,
      let libraryElementTypeRaw = userActivity
      .userInfo?[NSUserActivity.ActivityKeys.libraryElementType.rawValue] as? Int,
      let libraryElementType = PlayableContainerType(rawValue: libraryElementTypeRaw) {
      var shuffleOption = false
      var repeatOption = RepeatMode.off

      if let shuffleUserRaw = userActivity
        .userInfo?[NSUserActivity.ActivityKeys.shuffleOption.rawValue] as? Int,
        let shuffleUser = ShuffleType(rawValue: shuffleUserRaw) {
        shuffleOption = shuffleUser == .on
      }
      if let repeatUserRaw = userActivity
        .userInfo?[NSUserActivity.ActivityKeys.repeatOption.rawValue] as? Int,
        let repeatUser = RepeatType(rawValue: repeatUserRaw) {
        repeatOption = RepeatMode.fromIntent(type: repeatUser)
      }

      let playableContainer = getPlayableContainer(id: id, libraryElementType: libraryElementType)
      return await play(
        container: playableContainer,
        shuffleOption: shuffleOption,
        repeatOption: repeatOption
      )
    } else if let playRandomSongsIntent = userActivity.playRandomSongsIntent {
      let cacheOnly = playRandomSongsIntent.filterOption == .cache
      let songs = library.getSongs()
        .filterCached(dependigOn: cacheOnly)[randomPick: player.maxSongsToAddOnce]
      let playerContext = PlayContext(name: "Random Songs", playables: songs)
      return play(context: playerContext, shuffleOption: true, repeatOption: .off)

    } else {
      return false
    }
  }

  private func getPlayableContainer(
    searchTerm: String,
    searchCategory: PlayableContainerType
  )
    -> PlayableContainable? {
    var playableContainer: PlayableContainable?

    switch searchCategory {
    case .unknown:
      fallthrough
    case .song:
      playableContainer = FuzzySearcher.findBestMatch(in: library.getSongs(), search: searchTerm)
        .first
    case .artist:
      playableContainer = FuzzySearcher.findBestMatch(in: library.getArtists(), search: searchTerm)
        .first
    case .podcastEpisode:
      playableContainer = FuzzySearcher.findBestMatch(
        in: library.getPodcastEpisodes(),
        search: searchTerm
      ).first
    case .playlist:
      playableContainer = FuzzySearcher
        .findBestMatch(in: library.getPlaylists(), search: searchTerm).first
    case .album:
      playableContainer = FuzzySearcher.findBestMatch(in: library.getAlbums(), search: searchTerm)
        .first
    case .genre:
      playableContainer = FuzzySearcher.findBestMatch(in: library.getGenres(), search: searchTerm)
        .first
    case .podcast:
      playableContainer = FuzzySearcher.findBestMatch(in: library.getPodcasts(), search: searchTerm)
        .first
    }
    return playableContainer
  }

  private func getSong(songName: String, artistName: String) -> PlayableContainable? {
    let foundPlayables = FuzzySearcher.findBestMatch(in: library.getSongs(), search: songName)
    let foundSongs = foundPlayables.compactMap { $0 as? Song }
    let artists = foundSongs.compactMap { $0.artist }
    let matchingArtistsRaw = FuzzySearcher.findBestMatch(in: artists, search: artistName)
    let matchingArtists = matchingArtistsRaw.compactMap { $0 as? Artist }
    let foundSong = foundSongs.lazy
      .filter { song in matchingArtists.contains(where: { artist in song.artist == artist }) }.first
    return foundSong
  }

  private func getPlayableContainer(
    id: String,
    libraryElementType: PlayableContainerType
  )
    -> PlayableContainable? {
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
      playableContainer = library.getAlbum(id: id, isDetailFaultResolution: false)
    case .genre:
      playableContainer = library.getGenre(id: id)
    case .podcast:
      playableContainer = library.getPodcast(id: id)
    }
    return playableContainer
  }

  @MainActor
  public func playLastResult(
    shuffleOption: Bool,
    repeatOption: RepeatMode
  ) async
    -> Bool {
    guard let lastResult = lastResult else { return false }
    self.lastResult = nil

    if let playableContainer = lastResult.playableContainer {
      os_log(
        "Play container <%s> (shuffle: %s, repeat: %s)",
        log: self.log,
        type: .info,
        playableContainer.name,
        shuffleOption.description,
        repeatOption.description
      )
      return await play(
        container: playableContainer,
        shuffleOption: shuffleOption,
        repeatOption: repeatOption
      )
    } else if let playableElements = lastResult.playableElements {
      os_log(
        "Play Music (shuffle: %s, repeat: %s)",
        log: self.log,
        type: .info,
        shuffleOption.description,
        repeatOption.description
      )
      return play(
        context: PlayContext(name: "Siri Intent", playables: playableElements),
        shuffleOption: shuffleOption,
        repeatOption: repeatOption
      )
    } else {
      return false
    }
  }

  @MainActor
  private func play(
    container: PlayableContainable?,
    shuffleOption: Bool,
    repeatOption: RepeatMode
  ) async
    -> Bool {
    guard let container = container else { return false }
    do {
      if container is Playlist {
        if storage.settings.isOnlineMode, networkMonitor.isWifiOrEthernet {
          os_log(
            "Fetch playlist start: %s",
            log: self.log,
            type: .info,
            container.name
          )
          try await container.fetch(
            storage: storage,
            librarySyncer: librarySyncer,
            playableDownloadManager: playableDownloadManager
          )
          os_log(
            "Fetch playlist done: %s",
            log: self.log,
            type: .info,
            container.name
          )
        } else {
          os_log(
            "No fetch for playlist needed: %s",
            log: self.log,
            type: .info,
            container.name
          )
        }
      } else {
        os_log(
          "No fetch required for: %s",
          log: self.log,
          type: .info,
          container.name
        )
      }
    } catch {
      // do nothing
    }
    return play(
      context: PlayContext(containable: container),
      shuffleOption: shuffleOption,
      repeatOption: repeatOption
    )
  }

  private func play(context: PlayContext, shuffleOption: Bool, repeatOption: RepeatMode) -> Bool {
    if shuffleOption {
      player.playShuffled(context: context)
    } else {
      player.play(context: context)
    }
    player.setRepeatMode(repeatOption)
    return true
  }
}

extension PlayableContainerType {
  public var description: String {
    switch self {
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
    switch type {
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

extension NSUserActivity {
  var playRandomSongsIntent: PlayRandomSongsIntent? {
    interaction?.intent as? PlayRandomSongsIntent
  }
}
