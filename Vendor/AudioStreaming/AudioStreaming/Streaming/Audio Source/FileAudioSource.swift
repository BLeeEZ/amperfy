//
//  Created by Dimitrios Chatzieleftheriou on 11/11/2020.
//  Copyright © 2020 Decimal. All rights reserved.
//

import AVFoundation
import Foundation

// MARK: - FileAudioSource

final class FileAudioSource: NSObject, CoreAudioStreamSource {
  weak var delegate: AudioStreamSourceDelegate?

  var underlyingQueue: DispatchQueue

  var position: Int
  var length: Int

  var audioFileHint: AudioFileTypeID {
    audioFileType(fileExtension: url.pathExtension)
  }

  private var isMp4: Bool {
    audioFileHint == kAudioFileM4AType || audioFileHint == kAudioFileMPEG4Type
  }

  private var mp4IsAlreadyOptimized: Bool = false

  private var seekOffset: Int

  private let url: URL
  private let fileManager: FileManager

  private var readSize: Int
  private var buffer: UnsafeMutablePointer<UInt8>
  private var inputStream: InputStream?

  private var mp4Restructure: Mp4Restructure
  private var mp4ProbeBuffer: Data = .init()

  init(
    url: URL,
    fileManager: FileManager = .default,
    underlyingQueue: DispatchQueue,
    readSize: Int = 64 * 1024
  ) {
    self.url = url
    self.underlyingQueue = underlyingQueue
    self.fileManager = fileManager
    self.readSize = readSize
    self.mp4Restructure = Mp4Restructure()
    self.buffer = UnsafeMutablePointer.uint8pointer(of: readSize)
    self.seekOffset = 0
    self.position = 0
    self.length = 0
  }

  deinit {
    buffer.deallocate()
    mp4Restructure.clear()
  }

  func close() {
    guard let inputStream = inputStream else {
      return
    }
    CFReadStreamSetDispatchQueue(inputStream, nil)
    inputStream.close()
    inputStream.delegate = nil
  }

  // no-op
  func suspend() {}

  func resume() {
    guard let inputStream = inputStream else {
      return
    }
    CFReadStreamSetDispatchQueue(inputStream, underlyingQueue)
  }

  func seek(at offset: Int) {
    do {
      try performOpen(seek: offset)
    } catch {
      delegate?.errorOccurred(source: self, error: error)
    }
  }

  private func performOpen(seek seekOffset: Int) throws {
    var reopened = false
    let status = inputStream?.streamStatus ?? .closed
    if status == .atEnd || status == .closed || status == .error {
      reopened = true
      close()
      try open()
    }

    var offset = seekOffset
    if isMp4, mp4Restructure.dataOptimized {
      offset = mp4Restructure.seekAdjusted(offset: seekOffset)
    }

    if inputStream?.setProperty(offset, forKey: .fileCurrentOffsetKey) == true {
      position = offset
    } else {
      position = 0
    }

    if !reopened {
      underlyingQueue.async { [weak self] in
        if self?.inputStream?.hasBytesAvailable == true {
          self?.dataAvailable()
        }
      }
    }
  }

  private func dataAvailable() {
    guard let inputStream = inputStream else { return }
    let read = inputStream.read(buffer, maxLength: readSize)
    if read > 0 {
      let data = Data(bytes: buffer, count: read)
      if isMp4, !mp4IsAlreadyOptimized {
        if !mp4Restructure.dataOptimized {
          do {
            mp4ProbeBuffer.append(data)
            switch try mp4Restructure.checkIsOptimized(data: mp4ProbeBuffer) {
            case .undetermined:
              // Not enough bytes yet; wait for more data before deciding
              break
            case .optimized:
              mp4IsAlreadyOptimized = true
              mp4ProbeBuffer = Data()
              delegate?.dataAvailable(source: self, data: data)
            case let .needsRestructure(moovOffset):
              mp4ProbeBuffer = Data()
              try performMp4Restructure(inputStream: inputStream, moovOffset: moovOffset)
            }
          } catch {
            delegate?.errorOccurred(source: self, error: error)
          }
        } else {
          delegate?.dataAvailable(source: self, data: data)
        }
      } else {
        delegate?.dataAvailable(source: self, data: data)
      }
      position += read
    } else {
      position += getCurrentOffsetFromStream()
    }
  }

  func performMp4Restructure(inputStream: InputStream, moovOffset: Int) throws {
    let offsetAccepted = inputStream.setProperty(moovOffset, forKey: .fileCurrentOffsetKey)
    if !offsetAccepted {
      delegate?.errorOccurred(
        source: self,
        error: inputStream.streamError ?? AudioSystemError.playerStartError
      )
      return
    }

    // Read moov header (8 bytes)
    var header = [UInt8](repeating: 0, count: 8)
    let headerRead = inputStream.read(&header, maxLength: 8)
    guard headerRead == 8 else {
      delegate?.errorOccurred(source: self, error: AudioSystemError.playerStartError)
      return
    }

    // Parse size and type (big endian)
    let size32 = Data(header[0 ..< 4]).withUnsafeBytes { $0.load(as: UInt32.self) }.bigEndian
    let type32 = Data(header[4 ..< 8]).withUnsafeBytes { $0.load(as: UInt32.self) }.bigEndian
    guard Int(type32) == Atoms.moov else {
      delegate?.errorOccurred(source: self, error: Mp4RestructureError.missingMoovAtom)
      return
    }

    var moovSize = Int(size32)
    var moovData = Data(header)

    // Extended size (64-bit)
    if moovSize == 1 {
      var ext = [UInt8](repeating: 0, count: 8)
      let extRead = inputStream.read(&ext, maxLength: 8)
      guard extRead == 8 else {
        delegate?.errorOccurred(source: self, error: AudioSystemError.playerStartError)
        return
      }
      let ext64 = Data(ext).withUnsafeBytes { $0.load(as: UInt64.self) }.bigEndian
      moovSize = Int(ext64)
      moovData.append(contentsOf: ext)
    }

    let remaining = moovSize - moovData.count
    if remaining < 0 {
      delegate?.errorOccurred(source: self, error: AudioSystemError.playerStartError)
      return
    }
    if remaining > 0 {
      var buffer = [UInt8](repeating: 0, count: remaining)
      var total = 0
      while total < remaining {
        let readBytes = buffer.withUnsafeMutableBytes { ptr -> Int in
          let base = ptr.baseAddress!.assumingMemoryBound(to: UInt8.self).advanced(by: total)
          return inputStream.read(base, maxLength: remaining - total)
        }
        guard readBytes > 0 else {
          delegate?.errorOccurred(source: self, error: AudioSystemError.playerStartError)
          return
        }
        total += readBytes
      }
      moovData.append(contentsOf: buffer)
    }

    let moovResult = try mp4Restructure.restructureMoov(data: moovData)
    delegate?.dataAvailable(source: self, data: moovResult.initialData)
    if !inputStream.setProperty(moovResult.mdatOffset, forKey: .fileCurrentOffsetKey) {
      delegate?.errorOccurred(source: self, error: AudioSystemError.playerStartError)
    }
  }

  private func open() throws {
    guard let inputStream = InputStream(url: url) else {
      throw AudioSystemError.playerStartError
    }
    self.inputStream = inputStream
    CFReadStreamSetDispatchQueue(inputStream, underlyingQueue)
    inputStream.delegate = self
    inputStream.open()

    let attributes = try fileManager.attributesOfItem(atPath: url.path)
    length = (attributes[.size] as? Int) ?? 0
  }

  private func getCurrentOffsetFromStream() -> Int {
    guard let stream = inputStream else {
      return 0
    }
    return (stream.property(forKey: .fileCurrentOffsetKey) as? Int) ?? 0
  }
}

// MARK: StreamDelegate

extension FileAudioSource: StreamDelegate {
  func stream(_: Stream, handle eventCode: Stream.Event) {
    switch eventCode {
    case .hasBytesAvailable:
      dataAvailable()
    case .endEncountered:
      delegate?.endOfFileOccurred(source: self)
    case .errorOccurred:
      delegate?.errorOccurred(source: self, error: AudioPlayerError.codecError)
    default:
      break
    }
  }
}
