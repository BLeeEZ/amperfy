//
//  Created by Dimitrios Chatzieleftheriou on 25/10/2020.
//  Copyright © 2020 Decimal. All rights reserved.
//

import AVFoundation

// MARK: - OggVorbisStreamInfo

struct OggVorbisStreamInfo {
  var serialNumber: UInt32 = 0
  var pageCount: UInt64 = 0
  var totalSamples: UInt64 = 0
  var sampleRate: UInt32 = 0
  var channels: UInt8 = 0
  var bitRate: UInt32 = 0
  var nominalBitrate: UInt32 = 0
  var minBitrate: UInt32 = 0
  var maxBitrate: UInt32 = 0
  var blocksize0: Int = 0
  var blocksize1: Int = 0
  var commentHeader: [String: String] = [:]

  // For seeking
  var granulePosition: Int64 = 0
  var pageOffsets: [Int64] = []
  var pageGranules: [Int64] = []
}

// MARK: - AudioStreamState

final class AudioStreamState {
  var processedDataFormat: Bool = false
  var dataOffset: UInt64 = 0
  var dataByteCount: UInt64?
  var dataPacketOffset: UInt64?
  var dataPacketCount: Double = 0
  var streamFormat = AudioStreamBasicDescription()
  var bitRate: Double?

  // Flag to indicate when the audio format is ready for decoding
  var readyForDecoding: Bool = false

  // Add Ogg Vorbis-specific metadata
  var oggVorbisStreamInfo: OggVorbisStreamInfo?
  var hasAttemptedOggVorbisParse: Bool = false
  var initialOggBytes: Data?
}
