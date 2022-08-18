//
//  SwipeActionSettings.swift
//  AmperfyKit
//
//  Created by Maximilian Bauer on 06.02.22.
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
import UIKit

public enum SwipeActionType: Int, CaseIterable {
    case insertUserQueue = 0
    case appendUserQueue = 1
    case insertContextQueue = 2
    case appendContextQueue = 3
    case download = 4
    case removeFromCache = 5
    case addToPlaylist = 6
    case play = 7
    case playShuffled = 8
    case insertPodcastQueue = 9
    case appendPodcastQueue = 10
    case favorite = 11

    public var displayName: String {
        switch self {
        case .insertUserQueue:
            return "Insert User Queue"
        case .appendUserQueue:
            return "Append User Queue"
        case .insertContextQueue:
            return "Insert Context Queue"
        case .appendContextQueue:
            return "Append Context Queue"
        case .download:
            return "Download"
        case .removeFromCache:
            return "Remove from Cache"
        case .addToPlaylist:
            return "Add to Playlist"
        case .play:
            return "Play"
        case .playShuffled:
            return "Play shuffled"
        case .insertPodcastQueue:
            return "Insert Podcast Queue"
        case .appendPodcastQueue:
            return "Append Podcast Queue"
        case .favorite:
            return "Favorite"
        }
    }

    public var settingsName: String {
        switch self {
        case .insertUserQueue:
            return "Insert in User Queue"
        case .appendUserQueue:
            return "Append to User Queue"
        case .insertContextQueue:
            return "Insert in Context Queue"
        case .appendContextQueue:
            return "Append to Context Queue"
        case .download:
            return "Download"
        case .removeFromCache:
            return "Remove from Cache"
        case .addToPlaylist:
            return "Add to Playlist"
        case .play:
            return "Play"
        case .playShuffled:
            return "Play shuffled"
        case .insertPodcastQueue:
            return "Insert in Podcast Queue"
        case .appendPodcastQueue:
            return "Append to Podcast Queue"
        case .favorite:
            return "Mark as Favorite"
        }
    }

    public var image: UIImage {
        switch self {
        case .insertUserQueue:
            return UIImage.userQueueInsert
        case .appendUserQueue:
            return UIImage.userQueueAppend
        case .insertContextQueue:
            return UIImage.contextQueueInsert
        case .appendContextQueue:
            return UIImage.contextQueueAppend
        case .download:
            return UIImage.download
        case .removeFromCache:
            return UIImage.trash
        case .addToPlaylist:
            return UIImage.playlistBlack
        case .play:
            return UIImage.play
        case .playShuffled:
            return UIImage.shuffle
        case .insertPodcastQueue:
            return UIImage.podcastQueueInsert
        case .appendPodcastQueue:
            return UIImage.podcastQueueAppend
        case .favorite:
            return UIImage.heartFill
        }
    }
}

public struct SwipeActionSettings {
    public var combined: [[SwipeActionType]]

    public var leading: [SwipeActionType] {
        return combined[0]
    }
    public var trailing: [SwipeActionType] {
        return combined[1]
    }
    public var notUsed: [SwipeActionType] {
        return combined[2]
    }
    
    public init(leading: [SwipeActionType], trailing: [SwipeActionType]) {
        let notUsedSet = Set(SwipeActionType.allCases).subtracting(Set(leading)).subtracting(Set(trailing))
        combined = [ leading, trailing, Array(notUsedSet) ]
    }
    
    public static var defaultSettings: SwipeActionSettings {
        return SwipeActionSettings(
            leading: [
                .appendContextQueue,
                .insertContextQueue

            ], trailing: [
                .appendUserQueue,
                .insertUserQueue,
                .appendPodcastQueue,
                .insertPodcastQueue,
                .download
        ])
    }
}

public struct SwipeActionContext {
    public let containable: PlayableContainable
    private let customPlayContext: PlayContext?

    public var playables: [AbstractPlayable] { return containable.playables }
    public var playContext: PlayContext {
        return customPlayContext ?? PlayContext(containable: containable)
    }

    public init(containable: PlayableContainable, playContext: PlayContext? = nil) {
        self.containable = containable
        self.customPlayContext = playContext
    }
}
