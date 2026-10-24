//
//  Created by Dimitrios Chatzieleftheriou on 02/06/2020.
//  Copyright © 2020 Decimal. All rights reserved.
//

import Foundation

// MARK: - AudioPlayer.InternalState

extension AudioPlayer {
  struct InternalState: OptionSet {
    var rawValue: Int

    static let initial = InternalState([])
    static let running = InternalState(rawValue: 1)
    static let playing = InternalState(rawValue: (1 << 1) | InternalState.running.rawValue)
    static let rebuffering = InternalState(rawValue: (1 << 2) | InternalState.running.rawValue)
    static let waitingForData = InternalState(rawValue: (1 << 3) | InternalState.running.rawValue)
    static let waitingForDataAfterSeek = InternalState(
      rawValue: (1 << 4) | InternalState.running
        .rawValue
    )
    static let paused = InternalState(rawValue: (1 << 5) | InternalState.running.rawValue)
    static let stopped = InternalState(rawValue: 1 << 9)
    static let pendingNext = InternalState(rawValue: 1 << 10)
    static let disposed = InternalState(rawValue: 1 << 30)
    static let error = InternalState(rawValue: 1 << 31)

    static let waiting = [.waitingForData, waitingForDataAfterSeek, .rebuffering]
  }
}

/// Helper method that returns `AudioPlayerState` and `StopReason` based on the given `InternalState`
/// - Parameter internalState: A value of `InternalState`
/// - Returns: A tuple of `(AudioPlayerState, AudioPlayerStopReason)`
func playerStateAndStopReason(
  for internalState: AudioPlayer.InternalState
)
  -> (state: AudioPlayerState, stopReason: AudioPlayerStopReason?) {
  switch internalState {
  case .initial:
    return (.ready, AudioPlayerStopReason.none)
  case .playing, .running, .waitingForDataAfterSeek:
    return (.playing, AudioPlayerStopReason.none)
  case .pendingNext, .rebuffering, .waitingForData:
    return (.bufferring, AudioPlayerStopReason.none)
  case .stopped:
    return (.stopped, nil)
  case .paused:
    return (.paused, AudioPlayerStopReason.none)
  case .disposed:
    return (.disposed, .userAction)
  case .error:
    return (.error, AudioPlayerStopReason.error)
  default:
    return (.ready, AudioPlayerStopReason.none)
  }
}

// MARK: - AudioPlayerState

public enum AudioPlayerState: Equatable, Sendable {
  case ready
  case running
  case playing
  case bufferring
  case paused
  case stopped
  case error
  case disposed
}

// MARK: - AudioPlayerStopReason

public enum AudioPlayerStopReason: Equatable, Sendable {
  case none
  case eof
  case userAction
  case error
  case disposed
}

// MARK: - AudioPlayerError

public enum AudioPlayerError: LocalizedError, Equatable, Sendable {
  case streamParseBytesFailure(AudioFileStreamError)
  case audioSystemError(AudioSystemError)
  case codecError
  case dataNotFound
  case networkError(NetworkError)
  case other

  public var errorDescription: String? {
    switch self {
    case let .streamParseBytesFailure(status):
      return "Couldn't parse the bytes from the stream. Status: \(status)"
    case let .audioSystemError(error):
      return error.errorDescription
    case .codecError:
      return "Codec error while parsing data packets"
    case .dataNotFound:
      return "No data supplied from network stream"
    case let .networkError(error):
      return error.localizedDescription
    case .other:
      return "Audio Player error"
    }
  }
}

// MARK: - AudioSystemError

public enum AudioSystemError: LocalizedError, Equatable, Sendable {
  case engineFailure
  case playerNotFound
  case playerStartError
  case fileStreamError(AudioFileStreamError)
  case converterError(AudioConverterError)
  case codecError

  public var errorDescription: String? {
    switch self {
    case .engineFailure: return "Audio engine couldn't start"
    case .playerNotFound: return "Player not found"
    case .playerStartError: return "Player couldn't start"
    case let .fileStreamError(error):
      return "Audio file stream error'd: \(error)"
    case let .converterError(error):
      return "Audio converter error'd: \(error)"
    case .codecError:
      return "Audio codec error"
    }
  }
}
