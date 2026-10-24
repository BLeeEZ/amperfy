//
//  Created by Dimitrios Chatzieleftheriou on 16/06/2020.
//  Copyright © 2020 Decimal. All rights reserved.
//
//  Inspired by Thong Nguyen's StreamingKit. All rights reserved.
//

import AVFoundation
import CoreAudio
import OSLog

// MARK: - AudioConvertStatus

enum AudioConvertStatus: Int32 {
  case done = 100
  case processed = 0
}

// MARK: - AudioConvertInfo

struct AudioConvertInfo {
  var done: Bool
  let numberOfPackets: UInt32
  var audioBuffer = AudioBuffer()
  let packDescription: UnsafeMutablePointer<AudioStreamPacketDescription>?
}

// MARK: - FileStreamProcessorEffect

enum FileStreamProcessorEffect {
  case processSource
  case raiseError(AudioPlayerError)
}

// MARK: - AudioFileStreamProcessor

/// An object that handles the processing of AudioFileStream, its packets etc.
final class AudioFileStreamProcessor {
  private let maxCompressedPacketForBitrate = 4096

  var fileStreamCallback: ((FileStreamProcessorEffect) -> ())?

  private let playerContext: AudioPlayerContext
  private let rendererContext: AudioRendererContext
  private let outputAudioFormat: AudioStreamBasicDescription

  // Add Ogg Vorbis processor
  private lazy var oggVorbisProcessor = OggVorbisStreamProcessor(
    playerContext: playerContext,
    rendererContext: rendererContext,
    outputAudioFormat: outputAudioFormat
  )

  var audioFileStream: AudioFileStreamID?
  var audioConverter: AudioConverterRef?
  var discontinuous: Bool = false
  var inputFormat = AudioStreamBasicDescription()

  /// Where a FLAC seek should land; checked against the first frame received.
  private struct FlacSeekCheck {
    let requestedTime: Double
    let byteOffset: Int64
    let attempt: Int
    var buffer = Data()
  }

  private var flacSeekCheck: FlacSeekCheck?
  private static let flacSeekTolerance: Double = 1
  private static let flacSeekMaxAttempts = 4
  private static let flacSeekMaxScanBytes = 1 << 20

  var currentFileFormat: String = ""
  let fileFormatsForDelayedConverterCreation: Set = ["fa4m", "f4pm"]

  // Track if we're processing Ogg Vorbis
  private var isProcessingOggVorbis: Bool = false

  var isFileStreamOpen: Bool {
    audioFileStream != nil || isProcessingOggVorbis
  }

  init(
    playerContext: AudioPlayerContext,
    rendererContext: AudioRendererContext,
    outputAudioFormat: AudioStreamBasicDescription
  ) {
    self.playerContext = playerContext
    self.rendererContext = rendererContext
    self.outputAudioFormat = outputAudioFormat

    // Set up Ogg Vorbis processor callback
    oggVorbisProcessor.processorCallback = { [weak self] effect in
      self?.fileStreamCallback?(effect)
    }
  }

  /// Opens the `AudioFileStream`
  ///
  /// - parameter fileHint: An `AudioFileTypeID` value indicating the file type.
  ///
  /// - Returns: An `OSStatus` value indicating if an error occurred or not.

  func openFileStream(with fileHint: AudioFileTypeID) -> OSStatus {
    // Check if this is an Ogg Vorbis file
    if fileHint == kAudioFileOggType {
      isProcessingOggVorbis = true
      return noErr
    } else {
      isProcessingOggVorbis = false
      let data = UnsafeMutableRawPointer.from(object: self)
      return AudioFileStreamOpen(
        data,
        _propertyListenerProc,
        _propertyPacketsProc,
        fileHint,
        &audioFileStream
      )
    }
  }

  /// Closes the currently open `AudioFileStream` instance, if opened.
  func closeFileStreamIfNeeded() {
    if isProcessingOggVorbis {
      isProcessingOggVorbis = false
      oggVorbisProcessor.cleanup()
      return
    }

    guard let fileStream = audioFileStream else {
      Logger.debug("audio file stream not opened", category: .generic)
      return
    }
    AudioFileStreamClose(fileStream)
    audioFileStream = nil
  }

  /// Parses the given data using `AudioFileStreamParseBytes`
  ///
  /// - parameter data: A `Data` object containing the audio data to be parsed.
  ///
  /// - Returns: An `OSStatus` value indicating if an error occurred or not.
  func parseFileStreamBytes(data: Data) -> OSStatus {
    guard !data.isEmpty else { return 0 }

    // Check if we're processing Ogg Vorbis
    if isProcessingOggVorbis {
      return oggVorbisProcessor.parseOggVorbisData(data: data)
    }

    guard let stream = audioFileStream else { return 0 }
    var data = data
    if flacSeekCheck != nil {
      guard let aligned = alignFlacSeek(with: data) else { return noErr }
      data = aligned
    }
    let flags: AudioFileStreamParseFlags = discontinuous ? .discontinuity : .init()
    return data.withUnsafeBytes { buffer -> OSStatus in
      AudioFileStreamParseBytes(stream, UInt32(buffer.count), buffer.baseAddress, flags)
    }
  }

  /// Flushes any remaining packets from the AudioFileStream parser.
  ///
  /// This must be called at the end of a stream to ensure the final packet is delivered,
  /// particularly important for formats like FLAC that use sync words to determine packet boundaries.
  ///
  /// As documented in AudioFileStream.h:
  /// "At the end of the stream, this function must be called once with null data pointer
  /// and zero data byte size to flush any remaining packets out of the parser."
  ///
  /// - Returns: An `OSStatus` value indicating if an error occurred or not.
  func flushRemainingPackets() -> OSStatus {
    // Ogg Vorbis doesn't need flushing (handled internally)
    if isProcessingOggVorbis {
      return noErr
    }

    guard let stream = audioFileStream else { return noErr }

    // Call AudioFileStreamParseBytes with 0 bytes and nil data to flush the final packet
    let status = AudioFileStreamParseBytes(stream, 0, nil, [])

    if status != noErr {
      Logger.debug("Failed to flush AudioFileStream packets: \(status)", category: .generic)
    }

    return status
  }

  func processSeek() {
    guard let readingEntry = playerContext.audioReadingEntry else {
      return
    }

    // If processing Ogg Vorbis, use the Ogg Vorbis processor
    if isProcessingOggVorbis {
      oggVorbisProcessor.processSeek()
      return
    }

    guard let stream = audioFileStream else { return }

    guard readingEntry
      .calculatedBitrate() > 0.0 || (playerContext.audioPlayingEntry?.length ?? 0) > 0 else {
      return
    }

    let dataOffset = Double(readingEntry.audioStreamState.dataOffset)
    let dataLengthInBytes = Double(readingEntry.audioDataLengthBytes())
    let entryDuration = readingEntry.duration()
    let duration = entryDuration < readingEntry.progress && entryDuration > 0 ? readingEntry
      .progress : entryDuration

    guard duration > 0.0 else { return }

    var seekByteOffset =
      Int64(dataOffset + (readingEntry.seekRequest.time / duration) * dataLengthInBytes)

    if seekByteOffset > readingEntry
      .length - (2 * Int(readingEntry.processedPacketsState.bufferSize)) {
      seekByteOffset = Int64(
        readingEntry
          .length - (2 * Int(readingEntry.processedPacketsState.bufferSize))
      )
    }

    readingEntry.lock.lock()
    readingEntry.seekTime = readingEntry.seekRequest.time
    readingEntry.lock.unlock()

    let bitrate = readingEntry.calculatedBitrate()
    if readingEntry.packetDuration > 0, bitrate > 0 {
      var ioFlags = AudioFileStreamSeekFlags(rawValue: 0)
      var packetsAlignedByteOffset: Int64 = 0
      let seekPacket = Int64(floor(readingEntry.seekRequest.time / readingEntry.packetDuration))

      let seekStatus = AudioFileStreamSeek(stream, seekPacket, &packetsAlignedByteOffset, &ioFlags)
      let dataOffset = Int64(readingEntry.audioStreamState.dataOffset)
      if seekStatus == noErr, !ioFlags.contains(.offsetIsEstimated) {
        let delta = Double((seekByteOffset - dataOffset) - packetsAlignedByteOffset) / (bitrate * 8)
        readingEntry.lock.lock()
        readingEntry.seekTime -= delta
        readingEntry.lock.unlock()
        seekByteOffset = packetsAlignedByteOffset + dataOffset
      }
    }

    if let converted = audioConverter {
      AudioConverterReset(converted)
    }

    // FLAC has no fixed bytes per second, so the offset is only an estimate.
    // Hold the data back until a frame header shows where it landed.
    if readingEntry.audioStreamFormat.mFormatID == kAudioFormatFLAC,
       seekByteOffset > Int64(readingEntry.audioStreamState.dataOffset) {
      flacSeekCheck = FlacSeekCheck(
        requestedTime: readingEntry.seekRequest.time,
        byteOffset: seekByteOffset,
        attempt: 1
      )
    } else {
      flacSeekCheck = nil
    }

    readingEntry.reset()
    readingEntry.seek(at: Int(seekByteOffset))
    rendererContext.waitingForDataAfterSeekFrameCount.write { $0 = 0 }
    playerContext.setInternalState(to: .waitingForDataAfterSeek)
    rendererContext.resetBuffers()
  }

  /// Handles the first bytes after a FLAC seek. Finds the first frame header,
  /// which gives the exact sample position. If the estimate missed by more than
  /// `flacSeekTolerance`, seeks again from an offset corrected by the measured
  /// bytes per second. Otherwise sets the entry's seek time to the real
  /// position, so the shown time is right, and returns the bytes from that
  /// frame on. Returns nil while more data is needed or a new seek is pending.
  private func alignFlacSeek(with data: Data) -> Data? {
    guard var check = flacSeekCheck, let entry = playerContext.audioReadingEntry else {
      flacSeekCheck = nil
      return data
    }
    check.buffer.append(data)

    entry.lock.lock()
    let format = entry.audioStreamFormat
    let dataOffset = Int64(entry.audioStreamState.dataOffset)
    let length = Int64(entry.length)
    entry.lock.unlock()

    guard format.mSampleRate > 0,
          let frame = FlacFrameLocator.firstFrame(
            in: check.buffer,
            channels: Int(format.mChannelsPerFrame),
            sampleRate: Int(format.mSampleRate),
            blockSize: Int(format.mFramesPerPacket)
          )
    else {
      if check.buffer.count > Self.flacSeekMaxScanBytes || format.mSampleRate <= 0 {
        flacSeekCheck = nil
        return check.buffer
      }
      flacSeekCheck = check
      return nil
    }

    let actualTime = Double(frame.firstSample) / format.mSampleRate
    let frameByteOffset = check.byteOffset + Int64(frame.offset)
    if abs(check.requestedTime - actualTime) > Self.flacSeekTolerance,
       check.attempt < Self.flacSeekMaxAttempts, actualTime > 0 {
      let bytesPerSecond = Double(frameByteOffset - dataOffset) / actualTime
      var next = dataOffset + Int64(check.requestedTime * bytesPerSecond)
      if length > 0 { next = min(next, length - 1) }
      if next > dataOffset, next != check.byteOffset {
        Logger.debug(
          "FLAC seek landed at \(actualTime)s for \(check.requestedTime)s; retrying",
          category: .generic
        )
        flacSeekCheck = FlacSeekCheck(
          requestedTime: check.requestedTime,
          byteOffset: next,
          attempt: check.attempt + 1
        )
        entry.reset()
        entry.seek(at: Int(next))
        return nil
      }
    }

    entry.lock.lock()
    entry.seekTime = actualTime
    entry.lock.unlock()
    flacSeekCheck = nil
    return check.buffer.subdata(in: frame.offset ..< check.buffer.count)
  }

  /// Creates an `AudioConverter` instance to be used for converting the remote audio data to the canonical audio format
  ///
  /// - parameter fromFormat: An `AudioStreamBasicDescription` indicating the format of the remote audio
  /// - parameter toFormat: An `AudioStreamBasicDescription` indicating the local format in which the fromFormat will be converted to.
  func createAudioConverter(
    from fromFormat: AudioStreamBasicDescription,
    to toFormat: AudioStreamBasicDescription
  ) {
    var inputFormat = fromFormat
    if let converter = audioConverter {
      if memcmp(&inputFormat, &self.inputFormat, MemoryLayout<AudioStreamBasicDescription>.size) ==
        0 {
        AudioConverterReset(converter)
        return
      }
    }
    disposeAudioConverter()

    var classDesc = AudioClassDescription()
    var outputFormat = toFormat
    if getHardwareCodecClassDescription(formatId: inputFormat.mFormatID, classDesc: &classDesc) {
      AudioConverterNewSpecific(&inputFormat, &outputFormat, 1, &classDesc, &audioConverter)
    }

    if audioConverter == nil {
      let audioConverterStatus = AudioConverterNew(&inputFormat, &outputFormat, &audioConverter)
      guard audioConverterStatus == noErr else {
        let audioConverterError = AudioConverterError(osstatus: audioConverterStatus)
        fileStreamCallback?(.raiseError(.audioSystemError(.converterError(audioConverterError))))
        return
      }
    }
    configureChannelLayouts(for: audioConverter, inputChannels: inputFormat.mChannelsPerFrame)
    self.inputFormat = inputFormat
    assignMagicCookieToConverterIfNeeded()
  }

  private func configureChannelLayouts(
    for converter: AudioConverterRef?,
    inputChannels: UInt32
  ) {
    guard let converter else { return }

    if let inputLayoutTag = channelLayoutTag(for: inputChannels),
       let inputLayout = AVAudioChannelLayout(layoutTag: inputLayoutTag) {
      AudioConverterSetProperty(
        converter,
        kAudioConverterInputChannelLayout,
        UInt32(MemoryLayout<AudioChannelLayout>.size),
        inputLayout.layout
      )
    }

    guard let outputLayout = AVAudioChannelLayout(
      layoutTag: kAudioChannelLayoutTag_MPEG_5_1_A
    ) else { return }
    AudioConverterSetProperty(
      converter,
      kAudioConverterOutputChannelLayout,
      UInt32(MemoryLayout<AudioChannelLayout>.size),
      outputLayout.layout
    )
  }

  private func channelLayoutTag(for channelCount: UInt32) -> AudioChannelLayoutTag? {
    switch channelCount {
    case 1: kAudioChannelLayoutTag_Mono
    case 2: kAudioChannelLayoutTag_Stereo
    case 6: kAudioChannelLayoutTag_MPEG_5_1_A
    default: nil
    }
  }

  private func assignMagicCookieToConverterIfNeeded() {
    // magic cookie info
    if let fileStream = audioFileStream {
      var cookieSize: UInt32 = 0
      guard AudioFileStreamGetPropertyInfo(
        fileStream,
        kAudioFileStreamProperty_MagicCookieData,
        &cookieSize,
        nil
      ) == noErr else {
        return
      }
      var cookie: [UInt8] = Array(repeating: 0, count: Int(cookieSize))
      guard AudioFileStreamGetProperty(
        fileStream,
        kAudioFileStreamProperty_MagicCookieData,
        &cookieSize,
        &cookie
      ) == noErr else {
        return
      }
      guard let converter = audioConverter else {
        fileStreamCallback?(.raiseError(.audioSystemError(.fileStreamError(.unknownError))))
        return
      }
      guard AudioConverterSetProperty(
        converter,
        kAudioConverterDecompressionMagicCookie,
        cookieSize,
        cookie
      ) == noErr else {
        fileStreamCallback?(.raiseError(.audioSystemError(.fileStreamError(.unknownError))))
        return
      }
    }
  }

  /// Disposes the `AudioConverter` instance, if any.
  private func disposeAudioConverter() {
    guard let converter = audioConverter else { return }
    AudioConverterDispose(converter)
    audioConverter = nil
  }

  /// Parses any relevant properties as received by the opened `AudioFileStream`
  ///
  /// - parameter fileStream: An instance of `AudioFileStreamID` that is used to get information from.
  /// - parameter propertyId: A value of `AudioFileStreamPropertyID` indicating the file stream property.
  /// - parameter flags: A value of `UnsafeMutablePointer<AudioFileStreamPropertyFlags>`

  func propertyListenerProc(
    fileStream: AudioFileStreamID,
    propertyId: AudioFileStreamPropertyID,
    flags _: UnsafeMutablePointer<AudioFileStreamPropertyFlags>
  ) {
    guard let entry = playerContext.audioReadingEntry else { return }
    switch propertyId {
    case kAudioFileStreamProperty_DataOffset:
      processDataOffset(entry: entry, fileStream: fileStream)
    case kAudioFileStreamProperty_FileFormat:
      processFileFormat(fileStream: fileStream)
    case kAudioFileStreamProperty_DataFormat:
      processDataFormat(entry: entry, fileStream: fileStream)
    case kAudioFileStreamProperty_AudioDataByteCount:
      processDataByteCount(entry: entry, fileStream: fileStream)
    case kAudioFileStreamProperty_AudioDataPacketCount:
      processAudioDataPacketCount(entry: entry, fileStream: fileStream)
    case kAudioFileStreamProperty_BitRate:
      processBitRate(entry: entry, fileStream: fileStream)
    case kAudioFileStreamProperty_ReadyToProducePackets:
      // check converter for discontinuous stream
      assignMagicCookieToConverterIfNeeded()
      processPacketUpperBoundAndMaxPacketSize(entry: entry, fileStream: fileStream)
      processReadyToProducePackets(entry: entry, fileStream: fileStream)
    case kAudioFileStreamProperty_FormatList:
      processFormatList(entry: entry, fileStream: fileStream)
    case kAudioFileStreamProperty_PacketTableInfo:
      processPacketTableInfo(entry: entry, fileStream: fileStream)
    default:
      break
    }
  }

  // MARK: AudioFileStream properties Processing

  private func processDataOffset(entry: AudioEntry, fileStream: AudioFileStreamID) {
    var offset: UInt64 = 0
    fileStreamGetProperty(
      value: &offset,
      fileStream: fileStream,
      propertyId: kAudioFileStreamProperty_DataOffset
    )
    entry.lock.lock(); defer { entry.lock.unlock() }
    entry.audioStreamState.processedDataFormat = true
    entry.audioStreamState.dataOffset = offset
  }

  private func processReadyToProducePackets(entry: AudioEntry, fileStream: AudioFileStreamID) {
    var packetCount: UInt64 = 0
    var packetCountSize = UInt32(MemoryLayout.size(ofValue: packetCount))
    AudioFileStreamGetProperty(
      fileStream,
      kAudioFileStreamProperty_AudioDataPacketCount,
      &packetCountSize,
      &packetCount
    )
    entry.lock.lock(); defer { entry.lock.unlock() }
    entry.audioStreamState.dataPacketCount = Double(packetCount)
    let entryFormatID = entry.audioStreamFormat.mFormatID
    let isFLAC = entryFormatID == kAudioFormatFLAC
    if entryFormatID != kAudioFormatLinearPCM, !isFLAC {
      discontinuous = true
    }
  }

  private func processFileFormat(fileStream: AudioFileStreamID) {
    var fileFormat: [UInt8] = Array(repeating: 0, count: 4)
    var size = UInt32(4)
    AudioFileStreamGetProperty(fileStream, kAudioFileStreamProperty_FileFormat, &size, &fileFormat)
    if let stringFileFormat = String(data: Data(fileFormat), encoding: .utf8) {
      currentFileFormat = stringFileFormat
    }
  }

  private func processDataFormat(entry: AudioEntry, fileStream: AudioFileStreamID) {
    var audioStreamFormat = AudioStreamBasicDescription()
    entry.lock.lock(); defer { entry.lock.unlock() }
    if !entry.audioStreamState.processedDataFormat {
      fileStreamGetProperty(
        value: &audioStreamFormat,
        fileStream: fileStream,
        propertyId: kAudioFileStreamProperty_DataFormat
      )

      if entry.audioStreamFormat.mFormatID == 0 {
        entry.audioStreamFormat = audioStreamFormat
      }

      entry.sampleRate = Float(audioStreamFormat.mSampleRate)
      entry.packetDuration = Double(audioStreamFormat.mFramesPerPacket) / Double(entry.sampleRate)

      var packetBufferSize: UInt32 = 0
      var status = fileStreamGetProperty(
        value: &packetBufferSize,
        fileStream: fileStream,
        propertyId: kAudioFileStreamProperty_PacketSizeUpperBound
      )
      if status != 0 || packetBufferSize == 0 {
        status = fileStreamGetProperty(
          value: &packetBufferSize,
          fileStream: fileStream,
          propertyId: kAudioFileStreamProperty_MaximumPacketSize
        )
        if status != 0 || packetBufferSize == 0 {
          packetBufferSize = 2048 // default value
        }
      }

      entry.processedPacketsState.bufferSize = packetBufferSize

      if !fileFormatsForDelayedConverterCreation.contains(currentFileFormat) {
        createAudioConverter(from: entry.audioStreamFormat, to: outputAudioFormat)
      }

      // The channel count is known now; let the player match the hardware output.
      fileStreamCallback?(.processSource)
    }
  }

  private func processPacketUpperBoundAndMaxPacketSize(
    entry: AudioEntry,
    fileStream: AudioFileStreamID
  ) {
    var packetBufferSize: UInt32 = 0
    var status = fileStreamGetProperty(
      value: &packetBufferSize,
      fileStream: fileStream,
      propertyId: kAudioFileStreamProperty_PacketSizeUpperBound
    )
    if status != 0 || packetBufferSize == 0 {
      status = fileStreamGetProperty(
        value: &packetBufferSize,
        fileStream: fileStream,
        propertyId: kAudioFileStreamProperty_MaximumPacketSize
      )
      if status != 0 || packetBufferSize == 0 {
        packetBufferSize = 2048 // default value
      }
    }
    entry.lock.withLock {
      entry.processedPacketsState.bufferSize = packetBufferSize
    }
  }

  private func processDataByteCount(entry: AudioEntry, fileStream: AudioFileStreamID) {
    var audioDataByteCount: UInt64 = 0
    fileStreamGetProperty(
      value: &audioDataByteCount,
      fileStream: fileStream,
      propertyId: kAudioFileStreamProperty_AudioDataByteCount
    )
    entry.lock.lock(); defer { entry.lock.unlock() }
    entry.audioStreamState.dataByteCount = audioDataByteCount
  }

  private func processAudioDataPacketCount(entry: AudioEntry, fileStream: AudioFileStreamID) {
    var audioDataPacketCount: UInt64 = 0
    fileStreamGetProperty(
      value: &audioDataPacketCount,
      fileStream: fileStream,
      propertyId: kAudioFileStreamProperty_AudioDataPacketCount
    )
    entry.lock.lock(); defer { entry.lock.unlock() }
    entry.audioStreamState.dataPacketOffset = audioDataPacketCount
  }

  private func processBitRate(entry: AudioEntry, fileStream: AudioFileStreamID) {
    var bitRate: UInt32 = 0
    let status = fileStreamGetProperty(
      value: &bitRate,
      fileStream: fileStream,
      propertyId: kAudioFileStreamProperty_BitRate
    )
    guard status == noErr else { return }
    entry.lock.lock(); defer { entry.lock.unlock() }
    entry.audioStreamState.bitRate = Double(bitRate)
  }

  private func processPacketTableInfo(entry: AudioEntry, fileStream: AudioFileStreamID) {
    var pti = AudioFilePacketTableInfo(
      mNumberValidFrames: 0,
      mPrimingFrames: 0,
      mRemainderFrames: 0
    )
    let status = fileStreamGetProperty(
      value: &pti,
      fileStream: fileStream,
      propertyId: kAudioFileStreamProperty_PacketTableInfo
    )
    guard status == noErr else { return }
    // Use valid frames to refine duration if present
    entry.lock.lock(); defer { entry.lock.unlock() }
    if pti.mNumberValidFrames > 0 {
      entry.audioStreamState.dataPacketCount = Double(pti.mNumberValidFrames) / Double(max(
        1,
        entry.audioStreamFormat.mFramesPerPacket
      ))
    }
  }

  private func processFormatList(entry: AudioEntry, fileStream: AudioFileStreamID) {
    let info = fileStreamGetPropertyInfo(
      fileStream: fileStream,
      propertyId: kAudioFileStreamProperty_FormatList
    )
    guard info.status == noErr, info.size > 0 else { return }

    let itemStride = MemoryLayout<AudioFormatListItem>.stride
    let itemCount = Int(info.size) / itemStride
    guard itemCount > 0 else { return }

    var list = [AudioFormatListItem](repeating: AudioFormatListItem(), count: itemCount)
    var size = UInt32(itemCount * itemStride)
    AudioFileStreamGetProperty(fileStream, kAudioFileStreamProperty_FormatList, &size, &list)

    var chosenASBD: AudioStreamBasicDescription?
    for i in 0 ..< itemCount {
      let asbd = list[i].mASBD
      let formatId = asbd.mFormatID
      if formatId == kAudioFormatMPEG4AAC_HE || formatId == kAudioFormatMPEG4AAC_HE_V2 {
        chosenASBD = asbd
        break
      }
      if chosenASBD == nil {
        chosenASBD = asbd
      }
    }

    if let asbd = chosenASBD {
      entry.lock.withLock { entry.audioStreamFormat = asbd }
      if fileFormatsForDelayedConverterCreation.contains(currentFileFormat) {
        createAudioConverter(from: asbd, to: outputAudioFormat)
      }
      fileStreamCallback?(.processSource)
    }
  }

  // MARK: Packets Proc

  func propertyPacketsProc(
    inNumberBytes: UInt32,
    inNumberPackets: UInt32,
    inInputData: UnsafeRawPointer,
    inPacketDescriptions: UnsafeMutablePointer<AudioStreamPacketDescription>?
  ) {
    guard let entry = playerContext.audioReadingEntry else { return }
    guard entry.audioStreamState.processedDataFormat else { return }

    guard let converter = audioConverter else {
      Logger.error("Couldn't find audio converter", category: .audioRendering)
      return
    }

    if let playingEntry = playerContext.audioPlayingEntry,
       playingEntry.seekRequest.requested, playingEntry.calculatedBitrate() > 0 {
      fileStreamCallback?(.processSource)
      if rendererContext.waiting.value {
        rendererContext.packetsSemaphore.signal()
      }
      return
    }

    // reset discontinuity
    discontinuous = false

    var convertInfo = AudioConvertInfo(
      done: false,
      numberOfPackets: inNumberPackets,
      packDescription: inPacketDescriptions
    )
    convertInfo.audioBuffer.mData = UnsafeMutableRawPointer(mutating: inInputData)
    convertInfo.audioBuffer.mDataByteSize = inNumberBytes
    if let playingAudioStreamFormat = playerContext.audioPlayingEntry?.audioStreamFormat {
      convertInfo.audioBuffer.mNumberChannels = playingAudioStreamFormat.mChannelsPerFrame
    }

    updateProcessedPackets(
      inPacketDescriptions: inPacketDescriptions,
      inNumberPackets: inNumberPackets
    )

    var status: OSStatus = noErr
    packetProcess: while status == noErr {
      rendererContext.lock.lock()
      let bufferContext = rendererContext.bufferContext
      var used = bufferContext.frameUsedCount
      var start = bufferContext.frameStartIndex
      var end = (bufferContext.frameStartIndex + bufferContext.frameUsedCount) % bufferContext
        .totalFrameCount

      var framesLeftInBuffer = bufferContext.totalFrameCount - used
      rendererContext.lock.unlock()

      if framesLeftInBuffer == 0 {
        while true {
          rendererContext.lock.lock()
          let bufferContext = rendererContext.bufferContext
          used = bufferContext.frameUsedCount
          start = bufferContext.frameStartIndex
          end = (bufferContext.frameStartIndex + bufferContext.frameUsedCount) % bufferContext
            .totalFrameCount
          framesLeftInBuffer = bufferContext.totalFrameCount - used
          rendererContext.lock.unlock()
          if framesLeftInBuffer > 0 {
            break
          }
          if playerContext.internalState == .disposed
            || playerContext.internalState == .pendingNext
            || playerContext.internalState == .stopped {
            return
          }

          if let playingEntry = playerContext.audioPlayingEntry,
             playingEntry.seekRequest.requested, playingEntry.calculatedBitrate() > 0 {
            fileStreamCallback?(.processSource)
            if rendererContext.waiting.value {
              rendererContext.packetsSemaphore.signal()
            }
            return
          }

          rendererContext.waiting.write { $0 = true }
          rendererContext.packetsSemaphore.wait()
          rendererContext.waiting.write { $0 = false }
        }
      }

      let localBufferList = AudioBufferList.allocate(maximumBuffers: 1)
      defer { localBufferList.unsafeMutablePointer.deallocate() }

      if end >= start {
        var framesAdded: UInt32 = 0
        var framesToDecode: UInt32 = rendererContext.bufferContext.totalFrameCount - end

        let offset = Int(end * rendererContext.bufferContext.sizeInBytes)
        prefillLocalBufferList(
          bufferList: localBufferList,
          dataOffset: offset,
          framesToDecode: framesToDecode
        )

        status = AudioConverterFillComplexBuffer(
          converter,
          _converterCallback,
          &convertInfo,
          &framesToDecode,
          localBufferList.unsafeMutablePointer,
          nil
        )

        framesAdded = framesToDecode

        if status == AudioConvertStatus.done.rawValue {
          fillUsedFrames(framesCount: framesAdded)
          return
        } else if status != 0 {
          fileStreamCallback?(.raiseError(.codecError))
          return
        }

        framesToDecode = start
        if framesToDecode == 0 {
          fillUsedFrames(framesCount: framesAdded)
          continue packetProcess
        }
        prefillLocalBufferList(
          bufferList: localBufferList,
          dataOffset: 0,
          framesToDecode: framesToDecode
        )

        status = AudioConverterFillComplexBuffer(
          converter,
          _converterCallback,
          &convertInfo,
          &framesToDecode,
          localBufferList.unsafeMutablePointer,
          nil
        )

        framesAdded += framesToDecode

        if status == AudioConvertStatus.done.rawValue {
          fillUsedFrames(framesCount: framesAdded)
          return
        } else if status == AudioConvertStatus.processed.rawValue {
          fillUsedFrames(framesCount: framesAdded)
          continue packetProcess
        } else if status != 0 {
          fileStreamCallback?(.raiseError(.codecError))
          return
        }
      } else {
        var framesAdded: UInt32 = 0
        var framesToDecode: UInt32 = start - end

        let offset = Int(end * rendererContext.bufferContext.sizeInBytes)
        prefillLocalBufferList(
          bufferList: localBufferList,
          dataOffset: offset,
          framesToDecode: framesToDecode
        )

        status = AudioConverterFillComplexBuffer(
          converter,
          _converterCallback,
          &convertInfo,
          &framesToDecode,
          localBufferList.unsafeMutablePointer,
          nil
        )

        framesAdded = framesToDecode
        if status == AudioConvertStatus.done.rawValue {
          fillUsedFrames(framesCount: framesAdded)
          return
        } else if status == AudioConvertStatus.processed.rawValue {
          fillUsedFrames(framesCount: framesAdded)
          continue packetProcess
        } else if status != 0 {
          fileStreamCallback?(.raiseError(.codecError))
          return
        }
      }
    }
  }

  /// Fills the `AudioBuffer` with data as required
  ///
  /// - parameter list: An `UnsafeMutableAudioBufferListPointer` object representing the buffer list be filled with data
  /// - parameter dataOffset: An `Int` value indicating any offset to be applied to the buffer data
  /// - parameter framesToDecode: An `UInt32` value indicating the frames to be decoded, used in calculating the data size of the buffer.
  @inline(__always)
  private func prefillLocalBufferList(
    bufferList: UnsafeMutableAudioBufferListPointer,
    dataOffset: Int,
    framesToDecode: UInt32
  ) {
    if let mData = rendererContext.audioBuffer.mData {
      bufferList[0].mData = dataOffset > 0 ? mData + dataOffset : mData
    }
    bufferList[0].mDataByteSize = framesToDecode * rendererContext.bufferContext.sizeInBytes
    bufferList[0].mNumberChannels = rendererContext.audioBuffer.mNumberChannels
  }

  /// Advances the processed frames for buffer and reading entry
  ///
  /// - parameter frameCount: An `UInt32` value to be added to the used count of the buffers.
  @inline(__always)
  private func fillUsedFrames(framesCount: UInt32) {
    rendererContext.lock.lock()
    rendererContext.bufferContext.frameUsedCount += framesCount
    rendererContext.lock.unlock()

    playerContext.audioReadingEntry?.lock.lock()
    playerContext.audioReadingEntry?.framesState.queued += Int(framesCount)
    playerContext.audioReadingEntry?.lock.unlock()
  }

  @inline(__always)
  private func updateProcessedPackets(
    inPacketDescriptions: UnsafeMutablePointer<AudioStreamPacketDescription>?,
    inNumberPackets: UInt32
  ) {
    guard let inPacketDescriptions = inPacketDescriptions else { return }
    guard let readingEntry = playerContext.audioReadingEntry else { return }
    let processedPackCount = readingEntry.processedPacketsState.count
    if processedPackCount < maxCompressedPacketForBitrate {
      let count = min(Int(inNumberPackets), maxCompressedPacketForBitrate - Int(processedPackCount))
      for i in 0 ..< count {
        let packet = inPacketDescriptions[i]
        let packetSize: UInt32 = packet.mDataByteSize
        readingEntry.lock.lock()
        readingEntry.processedPacketsState.sizeTotal += packetSize
        readingEntry.processedPacketsState.count += 1
        readingEntry.lock.unlock()
      }
    }
  }
}

// MARK: - AudioFileStream proc method

private func _propertyListenerProc(
  clientData: UnsafeMutableRawPointer,
  fileStream: AudioFileStreamID,
  propertyId: AudioFileStreamPropertyID,
  flags: UnsafeMutablePointer<AudioFileStreamPropertyFlags>
) {
  let processor = clientData.to(type: AudioFileStreamProcessor.self)
  processor.propertyListenerProc(
    fileStream: fileStream,
    propertyId: propertyId,
    flags: flags
  )
}

private func _propertyPacketsProc(
  clientData: UnsafeMutableRawPointer,
  inNumberBytes: UInt32,
  inNumberPackets: UInt32,
  inInputData: UnsafeRawPointer,
  inPacketDescriptions: UnsafeMutablePointer<AudioStreamPacketDescription>?
) {
  let processor = clientData.to(type: AudioFileStreamProcessor.self)
  processor.propertyPacketsProc(
    inNumberBytes: inNumberBytes,
    inNumberPackets: inNumberPackets,
    inInputData: inInputData,
    inPacketDescriptions: inPacketDescriptions
  )
}

// MARK: - AudioConverterFillComplexBuffer callback method

private func _converterCallback(
  inAudioConverter _: AudioConverterRef,
  ioNumberDataPackets: UnsafeMutablePointer<UInt32>,
  ioData: UnsafeMutablePointer<AudioBufferList>,
  outDataPacketDescription: UnsafeMutablePointer<
    UnsafeMutablePointer<AudioStreamPacketDescription>?
  >?,
  inUserData: UnsafeMutableRawPointer?
)
  -> OSStatus {
  guard let convertInfo = inUserData?.assumingMemoryBound(to: AudioConvertInfo.self)
  else { return 0 }

  // we need to tell the converter to stop converting after it should stop converting
  if convertInfo.pointee.done {
    ioNumberDataPackets.pointee = 0
    return AudioConvertStatus.done.rawValue
  }
  // calculate the input buffer
  ioData.pointee.mNumberBuffers = 1
  ioData.pointee.mBuffers = convertInfo.pointee.audioBuffer

  // output the packet descriptions
  if outDataPacketDescription != nil {
    outDataPacketDescription?.pointee = convertInfo.pointee.packDescription
  }

  ioNumberDataPackets.pointee = convertInfo.pointee.numberOfPackets
  convertInfo.pointee.done = true

  return AudioConvertStatus.processed.rawValue
}

// MARK: HardwareCodedClass method

private func getHardwareCodecClassDescription(
  formatId: UInt32,
  classDesc: UnsafeMutablePointer<AudioClassDescription>
)
  -> Bool {
  #if os(iOS)
    var size: UInt32 = 0
    let formatIdSize = UInt32(MemoryLayout.size(ofValue: formatId))
    var id = formatId
    if AudioFormatGetPropertyInfo(kAudioFormatProperty_Decoders, formatIdSize, &id, &size) !=
      noErr {
      return false
    }
    let count = Int(size) / MemoryLayout<AudioClassDescription>.size
    var encoderDescriptions = Array(repeating: AudioClassDescription(), count: count)
    if AudioFormatGetProperty(
      kAudioFormatProperty_Decoders,
      formatIdSize,
      &id,
      &size,
      &encoderDescriptions
    ) != noErr {
      return false
    }

    for item in encoderDescriptions
      where item.mManufacturer == kAppleHardwareAudioCodecManufacturer {
      classDesc.pointee = item
      return true
    }
  #endif
  return false
}
