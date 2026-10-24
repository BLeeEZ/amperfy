//
//  Created by Dimitrios Chatzieleftheriou on 10/06/2020.
//  Copyright © 2020 Decimal. All rights reserved.
//

import AVFoundation
import CoreAudio

var maxFramesPerSlice: AVAudioFrameCount = 8192

// MARK: - AudioRendererContext

final class AudioRendererContext {
  let waiting = Atomic<Bool>(false)

  let lock = UnfairLock()

  let bufferContext: BufferContext

  let audioBuffer: AudioBuffer
  let inOutAudioBufferList: UnsafeMutablePointer<AudioBufferList>

  let packetsSemaphore = DispatchSemaphore(value: 0)

  let framesRequiredToStartPlaying: Double
  let framesRequiredAfterRebuffering: Double
  let framesRequiredForDataAfterSeekPlaying: Double

  let waitingForDataAfterSeekFrameCount = Atomic<Int32>(0)

  private let configuration: AudioPlayerConfiguration

  init(configuration: AudioPlayerConfiguration, outputAudioFormat: AVAudioFormat) {
    self.configuration = configuration

    let canonicalStream = outputAudioFormat.basicStreamDescription

    self
      .framesRequiredToStartPlaying = Double(canonicalStream.mSampleRate) *
      Double(configuration.secondsRequiredToStartPlaying)
    self
      .framesRequiredAfterRebuffering = Double(canonicalStream.mSampleRate) *
      Double(configuration.secondsRequiredToStartPlayingAfterBufferUnderrun)
    self
      .framesRequiredForDataAfterSeekPlaying = Double(canonicalStream.mSampleRate) *
      Double(configuration.gracePeriodAfterSeekInSeconds)

    let dataByteSize = Int(canonicalStream.mSampleRate * configuration.bufferSizeInSeconds) *
      Int(canonicalStream.mBytesPerFrame)
    self.inOutAudioBufferList = allocateBufferList(
      dataByteSize: dataByteSize,
      channelCount: canonicalStream.mChannelsPerFrame
    )

    self.audioBuffer = inOutAudioBufferList[0].mBuffers

    let bufferTotalFrameCount = UInt32(dataByteSize) / canonicalStream.mBytesPerFrame

    self.bufferContext = BufferContext(
      sizeInBytes: canonicalStream.mBytesPerFrame,
      totalFrameCount: bufferTotalFrameCount
    )
  }

  func fillSilenceAudioBuffer() {
    let count = Int(bufferContext.totalFrameCount * bufferContext.sizeInBytes)
    memset(audioBuffer.mData, 0, count)
  }

  /// Deallocates buffer resources
  func clean() {
    inOutAudioBufferList.deallocate()
    audioBuffer.mData?.deallocate()
  }

  /// Resets the `BufferContext`
  func resetBuffers() {
    lock.lock(); defer { lock.unlock() }
    bufferContext.frameStartIndex = 0
    bufferContext.frameUsedCount = 0
  }
}

/// Allocates a buffer list
///
/// - parameter dataByteSize: An `Int` value indicating the size that the buffer will hold
/// - Returns: An `UnsafeMutablePointer<AudioBufferList>` object
private func allocateBufferList(
  dataByteSize: Int,
  channelCount: UInt32
)
  -> UnsafeMutablePointer<AudioBufferList> {
  let _bufferList = AudioBufferList.allocate(maximumBuffers: 1)

  _bufferList[0].mDataByteSize = UInt32(dataByteSize)
  let alignment = MemoryLayout<UInt8>.alignment
  let mData = UnsafeMutableRawPointer.allocate(byteCount: dataByteSize, alignment: alignment)
  _bufferList[0].mData = mData
  _bufferList[0].mNumberChannels = channelCount

  return _bufferList.unsafeMutablePointer
}
