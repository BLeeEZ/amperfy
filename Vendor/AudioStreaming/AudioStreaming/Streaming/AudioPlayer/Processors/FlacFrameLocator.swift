//
//  FlacFrameLocator.swift
//  AudioStreaming
//

import Foundation

/// Finds FLAC frame headers in raw stream bytes.
///
/// A seek in a FLAC stream starts at an estimated byte offset, because FLAC has
/// no fixed bytes per second. Every frame header carries the number of its first
/// sample, so the first header after that offset tells where playback really is.
/// The header is validated against the stream's channel count and sample rate
/// and by its CRC-8, so audio data that happens to look like a sync code is
/// skipped.
enum FlacFrameLocator {
  struct Frame: Equatable {
    /// Offset of the frame header from the start of the searched bytes.
    let offset: Int
    /// Number of the frame's first sample, counted from the start of the stream.
    let firstSample: Int64
  }

  /// - Parameter blockSize: the stream's block size (STREAMINFO maximum block
  ///   size, `mFramesPerPacket`). Fixed-block-size frames are numbered, and only
  ///   the last frame may be shorter, so it is the size to multiply by.
  static func firstFrame<C: RandomAccessCollection>(
    in bytes: C,
    channels: Int,
    sampleRate: Int,
    blockSize: Int
  )
    -> Frame?
    where C.Element == UInt8, C.Index == Int {
    var i = bytes.startIndex
    while i + 1 < bytes.endIndex {
      if bytes[i] == 0xFF, bytes[i + 1] & 0xFE == 0xF8,
         let sample = firstSample(
           ofHeaderAt: i,
           in: bytes,
           channels: channels,
           sampleRate: sampleRate,
           streamBlockSize: blockSize
         ) {
        return Frame(offset: i - bytes.startIndex, firstSample: sample)
      }
      i += 1
    }
    return nil
  }

  private static func firstSample<C: RandomAccessCollection>(
    ofHeaderAt start: Int, in bytes: C, channels: Int, sampleRate: Int, streamBlockSize: Int
  )
    -> Int64? where C.Element == UInt8, C.Index == Int {
    let end = bytes.endIndex
    guard start + 4 < end else { return nil }
    let variableBlockSize = bytes[start + 1] & 0x01 == 1
    let blockSizeCode = bytes[start + 2] >> 4
    let sampleRateCode = bytes[start + 2] & 0x0F
    let channelCode = bytes[start + 3] >> 4
    let sampleSizeCode = (bytes[start + 3] >> 1) & 0x07
    guard blockSizeCode != 0, sampleRateCode != 0x0F, channelCode <= 10,
          sampleSizeCode != 3, bytes[start + 3] & 0x01 == 0
    else { return nil }
    guard (channelCode < 8 ? Int(channelCode) + 1 : 2) == channels else { return nil }
    if let rate = fixedSampleRate(code: sampleRateCode), rate != sampleRate { return nil }

    // Frame or sample number, coded like UTF-8 (up to 7 bytes).
    var p = start + 4
    let lead = bytes[p]
    var number: Int64
    let continuation: Int
    switch lead {
    case 0x00 ..< 0x80: number = Int64(lead); continuation = 0
    case 0xC0 ..< 0xE0: number = Int64(lead & 0x1F); continuation = 1
    case 0xE0 ..< 0xF0: number = Int64(lead & 0x0F); continuation = 2
    case 0xF0 ..< 0xF8: number = Int64(lead & 0x07); continuation = 3
    case 0xF8 ..< 0xFC: number = Int64(lead & 0x03); continuation = 4
    case 0xFC ..< 0xFE: number = Int64(lead & 0x01); continuation = 5
    case 0xFE: number = 0; continuation = 6
    default: return nil
    }
    guard p + continuation < end else { return nil }
    for k in stride(from: 1, through: continuation, by: 1) {
      let b = bytes[p + k]
      guard b & 0xC0 == 0x80 else { return nil }
      number = number << 6 | Int64(b & 0x3F)
    }
    p += 1 + continuation

    let blockSize: Int
    switch blockSizeCode {
    case 1: blockSize = 192
    case 2 ... 5: blockSize = 576 << (Int(blockSizeCode) - 2)
    case 6:
      guard p < end else { return nil }
      blockSize = Int(bytes[p]) + 1
      p += 1
    case 7:
      guard p + 1 < end else { return nil }
      blockSize = (Int(bytes[p]) << 8 | Int(bytes[p + 1])) + 1
      p += 2
    default: blockSize = 256 << (Int(blockSizeCode) - 8)
    }
    switch sampleRateCode {
    case 12: p += 1
    case 13, 14: p += 2
    default: break
    }
    guard p < end, crc8(bytes, from: start, to: p) == bytes[p] else { return nil }
    // With a fixed block size the header holds the frame number.
    return variableBlockSize ? number : number *
      Int64(streamBlockSize > 0 ? streamBlockSize : blockSize)
  }

  private static func fixedSampleRate(code: UInt8) -> Int? {
    switch code {
    case 1: return 88200
    case 2: return 176_400
    case 3: return 192_000
    case 4: return 8000
    case 5: return 16000
    case 6: return 22050
    case 7: return 24000
    case 8: return 32000
    case 9: return 44100
    case 10: return 48000
    case 11: return 96000
    default: return nil // 0: from STREAMINFO; 12–14: stored in the header
    }
  }

  /// CRC-8 with polynomial x^8 + x^2 + x + 1, as used by FLAC frame headers.
  private static func crc8<C: RandomAccessCollection>(_ bytes: C, from: Int, to: Int) -> UInt8
    where C.Element == UInt8, C.Index == Int {
    var crc: UInt8 = 0
    for i in from ..< to {
      crc ^= bytes[i]
      for _ in 0 ..< 8 {
        crc = crc & 0x80 != 0 ? (crc << 1) ^ 0x07 : crc << 1
      }
    }
    return crc
  }
}
