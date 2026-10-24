//
//  Created by Dimitrios Chatzieleftheriou on 09/07/2020.
//  Copyright © 2020 Decimal. All rights reserved.
//

import Foundation
import OSLog

public struct AudioPlayerConfiguration: Equatable {
  /// All pending items will be flushed when seeking a track if this is set to `true`
  let flushQueueOnSeek: Bool
  /// The size of the decompressed buffer.
  let bufferSizeInSeconds: Double
  /// Number of seconds of audio required to before playback first starts.
  /// - note: Must be larger that `bufferSizeInSeconds`
  let secondsRequiredToStartPlaying: Double
  /// Number of seconds of audio required after seek occurs.
  let gracePeriodAfterSeekInSeconds: Double
  /// Number of seconds of audio required to before playback resumes after a buffer underrun
  /// - note: Must be larger that `bufferSizeInSeconds`
  let secondsRequiredToStartPlayingAfterBufferUnderrun: Int

  /// Enables the internal logs
  let enableLogs: Bool

  public static let `default` = AudioPlayerConfiguration(
    flushQueueOnSeek: false,
    bufferSizeInSeconds: 10,
    secondsRequiredToStartPlaying: 1,
    gracePeriodAfterSeekInSeconds: 0.5,
    secondsRequiredToStartPlayingAfterBufferUnderrun: 7,
    enableLogs: false
  )
  /// Initializes the configuration for the `AudioPlayer`
  ///
  /// Parameters are pre set for convenience
  ///
  /// - parameter flushQueueOnSeek: All pending items will be flushed when seeking a track if this is set to `true`
  /// - parameter bufferSizeInSeconds: The size of the decompressed buffer.
  /// - parameter secondsRequiredToStartPlaying: Number of seconds of audio required to before playback first starts.
  /// - parameter gracePeriodAfterSeekInSeconds: Number of seconds of audio required after seek occurs.
  /// - parameter secondsRequiredToStartPlayingAfterBufferUnderrun: Number of seconds of audio required to before playback resumes after a buffer underrun
  /// - parameter enableLogs: Enables the internal logs
  ///
  public init(
    flushQueueOnSeek: Bool = true,
    bufferSizeInSeconds: Double = 10,
    secondsRequiredToStartPlaying: Double = 1,
    gracePeriodAfterSeekInSeconds: Double = 0.5,
    secondsRequiredToStartPlayingAfterBufferUnderrun: Int = 1,
    enableLogs: Bool = true
  ) {
    self.flushQueueOnSeek = flushQueueOnSeek
    self.bufferSizeInSeconds = bufferSizeInSeconds
    self.secondsRequiredToStartPlaying = secondsRequiredToStartPlaying
    self.gracePeriodAfterSeekInSeconds = gracePeriodAfterSeekInSeconds
    self
      .secondsRequiredToStartPlayingAfterBufferUnderrun =
      secondsRequiredToStartPlayingAfterBufferUnderrun
    self.enableLogs = enableLogs
    Logger.isEnabled = enableLogs
  }

  /// Normalize values on any zero values passed
  func normalizeValues() -> AudioPlayerConfiguration {
    let defaults = AudioPlayerConfiguration.default

    let bufferSizeInSeconds = bufferSizeInSeconds == 0
      ? defaults.bufferSizeInSeconds
      : bufferSizeInSeconds

    let secondsRequiredToStartPlaying = secondsRequiredToStartPlaying == 0
      ? defaults.secondsRequiredToStartPlaying
      : secondsRequiredToStartPlaying

    let gracePeriodAfterSeekInSeconds = gracePeriodAfterSeekInSeconds == 0
      ? defaults.gracePeriodAfterSeekInSeconds
      : gracePeriodAfterSeekInSeconds

    let secondsRequiredToStartPlayingAfterBufferUnderrun =
      secondsRequiredToStartPlayingAfterBufferUnderrun == 0
        ? defaults.secondsRequiredToStartPlayingAfterBufferUnderrun
        : secondsRequiredToStartPlayingAfterBufferUnderrun

    return AudioPlayerConfiguration(
      flushQueueOnSeek: flushQueueOnSeek,
      bufferSizeInSeconds: bufferSizeInSeconds,
      secondsRequiredToStartPlaying: secondsRequiredToStartPlaying,
      gracePeriodAfterSeekInSeconds: gracePeriodAfterSeekInSeconds,
      secondsRequiredToStartPlayingAfterBufferUnderrun: secondsRequiredToStartPlayingAfterBufferUnderrun,
      enableLogs: enableLogs
    )
  }
}
