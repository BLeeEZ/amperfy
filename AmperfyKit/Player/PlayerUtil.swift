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
import Intents
import MediaPlayer

// MARK: - MusicPlayable

@MainActor
public protocol MusicPlayable: AnyObject {
  func didStartPlayingFromBeginning()
  func didStartPlaying()
  func didPause()
  func didStopPlaying()
  func didElapsedTimeChange()
  func didLyricsTimeChange(time: CMTime) // high refresh count
  func didPlaylistChange()
  func didArtworkChange()
  func didShuffleChange()
  func didRepeatChange()
  func didPlaybackRateChange()
}

extension MusicPlayable {
  public func didLyricsTimeChange(time: CMTime) {} // make it an optional method
}

extension MusicPlayable {
  func didShuffleChange() {}
  func didRepeatChange() {}
  func didPlaybackRateChange() {}
  func errorOccurred(error: Error) {}
}

// MARK: - RepeatMode

public enum RepeatMode: Int16, CaseIterable {
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

  public var description: String {
    switch self {
    case .off: return "Off"
    case .all: return "All"
    case .single: return "Single"
    }
  }

  public var asMPRepeatType: MPRepeatType {
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
}

// MARK: - PlaybackRate

public enum PlaybackRate: Int, CaseIterable {
  case dot5 = 0
  case dot75
  case one
  case oneDot25
  case oneDot5
  case oneDot75
  case two

  public static func create(from playbackRate: Double) -> PlaybackRate {
    var rate = PlaybackRate.one
    if playbackRate < 0.4 {
      rate = .one
    } else if playbackRate < 0.6 {
      rate = .dot5
    } else if playbackRate < 0.8 {
      rate = .dot75
    } else if playbackRate < 1.1 {
      rate = .one
    } else if playbackRate < 1.3 {
      rate = .oneDot25
    } else if playbackRate < 1.6 {
      rate = .oneDot5
    } else if playbackRate < 1.8 {
      rate = .oneDot75
    } else if playbackRate < 2.1 {
      rate = .two
    } else {
      rate = .one
    }
    return rate
  }

  public var asDouble: Double {
    switch self {
    case .dot5: return 0.5
    case .dot75: return 0.75
    case .one: return 1
    case .oneDot25: return 1.25
    case .oneDot5: return 1.5
    case .oneDot75: return 1.75
    case .two: return 2
    }
  }

  public var description: String {
    switch self {
    case .dot5: return "0.5x"
    case .dot75: return "0.75x"
    case .one: return "1x"
    case .oneDot25: return "1.25x"
    case .oneDot5: return "1.5x"
    case .oneDot75: return "1.75x"
    case .two: return "2x"
    }
  }
}

// MARK: - PlayerQueueType

public enum PlayerQueueType: Int, CaseIterable {
  case prev = 0
  case user = 2
  case next = 3

  public var description: String {
    switch self {
    case .prev: return "Previous"
    case .user: return "Next in Queue"
    case .next: return "Next"
    }
  }
}

// MARK: - PlayerIndex

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

  public var asIndexPath: IndexPath {
    IndexPath(row: index, section: queueType.rawValue)
  }
}
