//
//  Created by Dimitrios Chatzieleftheriou on 27/05/2020.
//  Copyright © 2020 Decimal. All rights reserved.
//

import AudioToolbox
import Foundation

// MARK: - AudioStreamSourceDelegate

public protocol AudioStreamSourceDelegate: AnyObject {
  /// Indicates that there's data available
  func dataAvailable(source: CoreAudioStreamSource, data: Data)
  /// Indicates an error occurred
  func errorOccurred(source: CoreAudioStreamSource, error: Error)
  /// Indicates end of file has occurred
  func endOfFileOccurred(source: CoreAudioStreamSource)
  /// Indicates metadata read from stream
  func metadataReceived(data: [String: String])
}

// MARK: - CoreAudioStreamSource

public protocol CoreAudioStreamSource: AnyObject {
  /// An `Int` that represents the position of the audio
  var position: Int { get }
  /// The length of the audio in bytes
  var length: Int { get }

  /// An `AudioStreamSourceDelegate` object to listen for events from the source
  var delegate: AudioStreamSourceDelegate? { get set }

  /// Closes the underlying stream
  func close()

  /// Suspends the underlying stream
  func suspend()

  /// Resumes the underlying stream
  func resume()

  /// Seeks the stream at the specified offset
  func seek(at offset: Int)

  /// The file type, eg `mp3`, `aac`
  var audioFileHint: AudioFileTypeID { get }

  /// The `DispatchQueue` network object will receive data
  var underlyingQueue: DispatchQueue { get }
}

// MARK: - AudioStreamSource

protocol AudioStreamSource: CoreAudioStreamSource {
  /// A `MetadataStreamSource` object that handles the metadata parsing
  var metadataStreamProcessor: MetadataStreamSource { get }
}
