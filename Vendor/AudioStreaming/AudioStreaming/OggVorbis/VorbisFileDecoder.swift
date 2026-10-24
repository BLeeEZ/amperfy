import AudioCodecs
import AVFoundation
import Foundation
import OSLog

/// A simple decoder for Ogg Vorbis files using libvorbisfile
final class VorbisFileDecoder {
  // Core properties
  private var stream: VFStreamRef?
  private var vf: VFFileRef?

  // Audio format properties
  private(set) var sampleRate: Int = 0
  private(set) var channels: Int = 0
  private(set) var durationSeconds: Double = -1
  private(set) var totalPcmSamples: Int64 = -1
  private(set) var nominalBitrate: Int = 0
  private(set) var processingFormat: AVAudioFormat?

  // Thread safety
  private let decoderLock = NSLock()

  // Silent frame generation
  private var silentFrameBuffer: UnsafeMutablePointer<Float>?
  private var silentFrameSize = 0

  /// Create the stream buffer with specified capacity
  /// - Parameter capacityBytes: Size of the ring buffer in bytes
  func create(capacityBytes: Int) {
    decoderLock.lock()
    defer { decoderLock.unlock() }

    stream = VFStreamCreate(capacityBytes)
  }

  /// Clean up resources
  func destroy() {
    decoderLock.lock()
    defer { decoderLock.unlock() }

    if let vf = vf { VFClear(vf) }
    if let stream = stream { VFStreamDestroy(stream) }
    vf = nil
    stream = nil

    if let silentFrameBuffer = silentFrameBuffer {
      silentFrameBuffer.deallocate()
      self.silentFrameBuffer = nil
    }
  }

  deinit {
    destroy()
  }

  /// Push data into the stream buffer
  /// - Parameter data: The Ogg Vorbis data to decode
  func push(_ data: Data) {
    decoderLock.lock()
    defer { decoderLock.unlock() }

    data.withUnsafeBytes { rawBuf in
      guard let base = rawBuf.baseAddress?.assumingMemoryBound(to: UInt8.self),
            !rawBuf.isEmpty,
            let stream = stream else { return }

      VFStreamPush(stream, base, rawBuf.count)
    }
  }

  /// Get the number of bytes currently available in the stream buffer
  /// - Returns: Number of bytes available
  func availableBytes() -> Int {
    decoderLock.lock()
    defer { decoderLock.unlock() }

    guard let stream = stream else { return 0 }
    return Int(VFStreamAvailableBytes(stream))
  }

  /// Mark the end of the stream
  func markEOF() {
    decoderLock.lock()
    defer { decoderLock.unlock() }

    if let stream = stream {
      VFStreamMarkEOF(stream)
    }
  }

  /// Try to open the Vorbis file if enough data is available
  /// - Throws: Error if opening fails
  func openIfNeeded() throws {
    decoderLock.lock()
    defer { decoderLock.unlock() }

    guard vf == nil, let stream = stream else { return }

    var outVF: VFFileRef?
    let rc = VFOpen(stream, &outVF)
    if rc < 0 {
      Logger.error("Failed to open Vorbis file", category: .audioRendering)
      throw NSError(
        domain: "VorbisFileDecoder",
        code: Int(rc),
        userInfo: [NSLocalizedDescriptionKey: "Failed to open Vorbis file"]
      )
    }

    vf = outVF

    // Get stream info
    var info = VFStreamInfo()
    if VFGetInfo(outVF, &info) == 0 {
      sampleRate = Int(info.sample_rate)
      channels = Int(info.channels)
      totalPcmSamples = Int64(info.total_pcm_samples)
      durationSeconds = info.duration_seconds
      nominalBitrate = Int(info.bitrate_nominal)

      // Create audio format
      let layoutTag: AudioChannelLayoutTag
      switch channels {
      case 1: layoutTag = kAudioChannelLayoutTag_Mono
      case 2: layoutTag = kAudioChannelLayoutTag_Stereo
      // Vorbis uses FL, FC, FR, RL, RR, LFE channel order. The MPEG
      // 5.1 layout instead expects FL, FR, FC, LFE, RL, RR, so tagging
      // Vorbis PCM as MPEG 5.1 misidentifies four of the six channels.
      // Ogg_5_1 describes the channel order emitted by the Vorbis decoder.
      case 6: layoutTag = kAudioChannelLayoutTag_Ogg_5_1
      default: layoutTag = kAudioChannelLayoutTag_Unknown | UInt32(channels)
      }

      let channelLayout = AVAudioChannelLayout(layoutTag: layoutTag)!

      processingFormat = AVAudioFormat(
        commonFormat: .pcmFormatFloat32,
        sampleRate: Double(sampleRate),
        interleaved: false,
        channelLayout: channelLayout
      )

      // Create silent frame buffer
      silentFrameSize = 1024 * channels
      silentFrameBuffer = UnsafeMutablePointer<Float>.allocate(capacity: silentFrameSize)
      for i in 0 ..< silentFrameSize {
        silentFrameBuffer?[i] = 0.0
      }
    } else {
      Logger.error("Failed to get stream info", category: .audioRendering)
    }
  }

  /// Read decoded frames into an AVAudioPCMBuffer
  /// - Parameters:
  ///   - buffer: The buffer to fill with audio data
  ///   - frameCount: Maximum number of frames to read
  /// - Returns: Number of frames read, 0 on EOF, negative on error
  func readFrames(into buffer: AVAudioPCMBuffer, frameCount: Int) -> Int {
    decoderLock.lock()
    defer { decoderLock.unlock() }

    guard let vf = vf, buffer.format.channelCount > 0 else {
      return generateSilentFrames(into: buffer, frameCount: frameCount)
    }

    // Get float channel data from buffer
    guard let floatChannelData = buffer.floatChannelData else {
      return generateSilentFrames(into: buffer, frameCount: frameCount)
    }

    // Read deinterleaved frames directly
    let maxFrames = min(frameCount, Int(buffer.frameCapacity))
    var pcmChannels: UnsafeMutablePointer<UnsafeMutablePointer<Float>?>?
    let framesRead = Int(VFReadFloat(vf, &pcmChannels, Int32(maxFrames)))

    // If no frames were read, generate silent frames instead of returning 0
    if framesRead <= 0 {
      return generateSilentFrames(into: buffer, frameCount: frameCount)
    }

    // Copy deinterleaved data directly (no conversion needed!)
    guard let pcm = pcmChannels else {
      return generateSilentFrames(into: buffer, frameCount: frameCount)
    }

    let channelCount = min(Int(buffer.format.channelCount), channels)
    for ch in 0 ..< channelCount {
      guard let input = pcm[ch] else { continue }
      let output = floatChannelData[ch]
      memcpy(output, input, framesRead * MemoryLayout<Float>.stride)
    }

    return framesRead
  }

  /// Generate silent frames when no real audio data is available
  /// This prevents EOF detection by never returning 0 frames
  private func generateSilentFrames(into buffer: AVAudioPCMBuffer, frameCount: Int) -> Int {
    guard let floatChannelData = buffer.floatChannelData,
          channels > 0 else { return 1 }

    // Use a small frame count to ensure we keep checking for real data
    let framesToGenerate = min(128, frameCount)

    // Fill buffer with zeros
    for ch in 0 ..< min(Int(buffer.format.channelCount), channels) {
      let dst = floatChannelData[ch]
      for frame in 0 ..< framesToGenerate {
        dst[frame] = 0.0
      }
    }

    return framesToGenerate
  }

  /// Reset the decoder state
  func reset() {
    destroy()
  }
}
