//
//  Created by Dimitrios Chatzieleftheriou on 22/11/2025.
//  Copyright © 2025 Decimal. All rights reserved.
//

import Foundation

// MARK: - AudioPlayerLoopMode

/// Defines the loop/repeat mode for the audio player
public enum AudioPlayerLoopMode: Equatable {
  /// No looping - plays through the queue once
  case off
  /// Loop the current track
  /// - Parameter times: Number of times to loop (nil = infinite)
  case single(times: Int?)
  /// Loop the entire queue
  /// - Parameter times: Number of times to loop (nil = infinite)
  case all(times: Int?)
}

// MARK: - LoopEntryInfo

/// Stores information needed to recreate an audio entry for looping
internal struct LoopEntryInfo: Equatable {
  let url: URL
  let headers: [String: String]
}
