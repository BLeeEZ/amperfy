//
//  Created by Dimitrios Chatzieleftheriou on 29/05/2020.
//  Copyright © 2020 Decimal. All rights reserved.
//

import AVFoundation

// MARK: - MetadataStreamSourceDelegate

protocol MetadataStreamSourceDelegate: AnyObject {
  func didReceiveMetadata(metadata: Result<[String: String], MetadataParsingError>)
}

// MARK: - MetadataStreamSource

protocol MetadataStreamSource {
  var delegate: MetadataStreamSourceDelegate? { get set }

  /// Returns `true` when the stream header has indicated that we can process metadata, otherwise `false`.
  var canProcessMetadata: Bool { get }

  /// Assigns the metadata step of the metadata
  func metadataAvailable(step: Int)

  /// Process the received data and extract the metadata if any, returns audio data only.
  /// - parameter data: A `Data` object for parsing any metadata
  /// - returns: The extracted audio `Data`
  func processMetadata(data: Data) -> Data

  /// Resets the processor
  func reset()
}

// MARK: - MetadataStreamProcessor

///
///
/// Metadata from Shoutcast/Icecast servers are included in the audio stream.
/// There's a header value which you get on the HTTP headers *Icy-metaint* this value is the audio bytes between
/// the metadata.
/// ```
/// ============================================
/// [ audio data ][byte][metadata][ audio data ]
/// ============================================
/// ```
///
/// Reference:
/// [SmackFu Shoutcast](https://web.archive.org/web/20190521203350/https://www.smackfu.com/stuff/programming/shoutcast.html)
///
final class MetadataStreamProcessor: MetadataStreamSource {
  weak var delegate: MetadataStreamSourceDelegate?

  var canProcessMetadata: Bool {
    metadataStep > 0
  }

  /// An `Int` read from http header value of `Icy-metaint` header
  private var metadataStep = 0

  /// The `Data` to write the metadata
  private var metadata = Data()
  private var metadataLength: Int = 0

  private var audioDataBytesRead: Int = 0

  private let parser: AnyParser<Data, MetadataOutput>

  init(parser: AnyParser<Data, MetadataOutput>) {
    self.parser = parser
  }

  func metadataAvailable(step: Int) {
    metadataStep = step
  }

  func reset() {
    metadata = Data()
    metadataLength = 0
    audioDataBytesRead = 0
  }

  // MARK: Process Metadata

  @inline(__always)
  func processMetadata(data: Data) -> Data {
    data.withUnsafeBytes { buffer -> Data in
      guard !buffer.isEmpty else { return data }
      var audioData = Data()
      var bytesRead = 0
      let bytes = buffer.baseAddress!.assumingMemoryBound(to: UInt8.self)
      /// read through the bytes
      while bytesRead < buffer.count {
        let remainingBytes = buffer.count - bytesRead
        let pointer = bytes + bytesRead
        if metadataLength > 0 {
          // we have metadata to read, extract it and add it to the temp holder
          let remainingMetaBytes = metadataLength - metadata.count
          let bytesToAppend = min(remainingMetaBytes, remainingBytes)
          metadata.append(pointer, count: bytesToAppend)

          if metadata.count == metadataLength {
            // we have extracted the metadata, so we can parse
            let processedMetadata = parser.parse(input: metadata)
            delegate?.didReceiveMetadata(metadata: processedMetadata)

            metadata.count = 0
            metadataLength = 0
            audioDataBytesRead = 0
          }

          bytesRead += bytesToAppend
        } else if audioDataBytesRead == metadataStep {
          // we've hit the step of the metadata
          let metaLength = Int(pointer.pointee) * 16
          // check to see if there's available metadata
          if metaLength > 0 {
            metadataLength = Int(metaLength)
          } else {
            audioDataBytesRead = 0
          }
          bytesRead += 1
        } else {
          /// extract audio only content
          let audioBytesToRead = min(metadataStep - audioDataBytesRead, remainingBytes)
          audioData.append(pointer, count: audioBytesToRead)

          audioDataBytesRead += audioBytesToRead
          bytesRead += audioBytesToRead
        }
      }
      return audioData
    }
  }
}
