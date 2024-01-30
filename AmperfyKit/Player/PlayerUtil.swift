//
//  PlayerUtil.swift
//  AmperfyKit
//
//  Created by Maximilian Bauer on 18.11.21.
//  Copyright (c) 2021 Maximilian Bauer. All rights reserved.
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
import MediaPlayer
import Intents

public protocol MusicPlayable {
    func didStartPlaying()
    func didPause()
    func didStopPlaying()
    func didElapsedTimeChange()
    func didPlaylistChange()
    func didArtworkChange()
    func didShuffleChange()
    func didRepeatChange()
}

extension MusicPlayable {
    func didShuffleChange() {}
    func didRepeatChange() {}
    func errorOccured(error: Error) {}
}

public enum RepeatMode: Int16 {
    case off
    case all
    case single

    public var nextMode: RepeatMode {
        switch self {
        case .off:
            return .all
        case .all:
            return .single
        case .single:
            return .off
        }
    }
    
    public var description : String {
        switch self {
        case .off: return "Off"
        case .all: return "All"
        case .single: return "Single"
        }
    }
    
    public  var asMPRepeatType: MPRepeatType {
        switch self {
        case .off: return .off
        case .all: return .all
        case .single: return .one
        }
    }
    
    public static func fromMPRepeatType(type: MPRepeatType) -> RepeatMode {
        switch type {
        case .off:
            return .off
        case .one:
            return .single
        case .all:
            return .all
        default:
            return .off
        }
    }
    
    public static func fromINPlaybackRepeatMode(mode: INPlaybackRepeatMode) -> RepeatMode {
        switch mode {
        case .unknown:
            return .off
        case .none:
            return .off
        case .all:
            return .all
        case .one:
            return .single
        @unknown default:
            return .off
        }
    }
    
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

public enum PlayerQueueType: Int, CaseIterable {
    case prev = 0
    case user
    case next
    
    public var description : String {
        switch self {
        case .prev: return "Previous"
        case .user: return "Next in Queue"
        case .next: return "Next"
        }
    }
}

public struct PlayerIndex: Equatable {
    let queueType: PlayerQueueType
    let index: Int
    
    public init(queueType: PlayerQueueType, index: Int) {
        self.queueType = queueType
        self.index = index
    }
    
    public static func create(from indexPath: IndexPath) -> PlayerIndex? {
        guard let queueType = PlayerQueueType(rawValue: indexPath.section) else { return nil }
        return PlayerIndex(queueType: queueType, index: indexPath.row)
    }
}
