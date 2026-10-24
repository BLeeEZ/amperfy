//
//  HardwareOutput.swift
//  AudioStreaming
//

import AVFoundation

/// Chooses what the player hands to the audio hardware.
///
/// The player decodes every track into one canonical 5.1 stream. iOS decides
/// from the hardware stream whether content is multichannel: it shows Spatial
/// Audio for multichannel output and offers "Spatialize Stereo" for stereo. So
/// a stereo or mono track goes out as stereo (the front pair, where the
/// converter places it), and a multichannel track goes out in the canonical
/// layout.
enum HardwareOutput {
  /// Hardware channel count for a source, or nil while the source format is unknown.
  static func channelCount(forSourceChannels source: UInt32, canonicalChannels: UInt32) -> UInt32? {
    guard source > 0 else { return nil }
    return source > 2 ? canonicalChannels : 2
  }

  /// Copies the front left and right channels of interleaved canonical audio
  /// into an interleaved stereo buffer.
  static func copyFrontPair(
    from source: UnsafePointer<Float>,
    sourceChannels: Int,
    to destination: UnsafeMutablePointer<Float>,
    frames: Int
  ) {
    for frame in 0 ..< frames {
      destination[2 * frame] = source[sourceChannels * frame]
      destination[2 * frame + 1] = source[sourceChannels * frame + 1]
    }
  }

  /// Interleaved float stereo at the canonical sample rate.
  static func stereoFormat(like canonical: AVAudioFormat) -> AVAudioFormat {
    AVAudioFormat(
      commonFormat: .pcmFormatFloat32,
      sampleRate: canonical.sampleRate,
      channels: 2,
      interleaved: true
    )!
  }
}
