//
//  IcycastHeadersProcessor.swift
//  AudioStreaming
//
//  Created by Dimitrios C on 14/02/2021.
//  Copyright © 2021 Decimal. All rights reserved.
//

import Foundation

/// ICY is built on HTTP some old servers might still send headers in the stream.
/// From a server point of view, this should be considered deprecated and should not be used as it might break HTML5 compatibility.
/// Although there are some servers still using this, this class will extract those headers from the stream
///
/// The format of the headers is as follows:
/// ```
/// =================================================================
/// [ ICY 200 OK                                                    ]
/// [ icy-mentaint: the number of bytes between 2 metadata chunks   ]
/// [ icy-br: send the bitrate in kilobits per second               ]
/// [ icy-genre: sends the genre                                    ]
/// [ icy-name: sends the stream's name                             ]
/// [ icy-url: is the URL of the radio station                      ]
/// [ icy-pub: can be 1 or 0 to tell if it is listed or not         ]
/// =================================================================
/// ```

final class IcycastHeadersProcessor {
  private var icecastHeaders = Data(capacity: 1024)
  private var searchComplete = false
  private var iceHeaderAvailable = false

  func reset() {
    icecastHeaders = Data(capacity: 1024)
    searchComplete = false
    iceHeaderAvailable = false
  }

  @inline(__always)
  func process(data: Data) -> (Data?, Data) {
    let stopProcessingCheckOne: [UInt8] = Array("\n\n".utf8)
    let stopProcessingCheckTwo: [UInt8] = Array("\r\n\r\n".utf8)
    let icyPrefix: [UInt8] = Array("ICY ".utf8)
    let httpPrefix: [UInt8] = Array("HTTP".utf8)
    return data.withUnsafeBytes { buffer -> (Data?, Data) in
      guard !buffer.isEmpty else { return (nil, data) }
      var bytesRead = 0
      let bytes = buffer.baseAddress!.assumingMemoryBound(to: UInt8.self)
      // Read through the bytes and stop when our search is complete
      // Since we don't know the amount of bytes to be processed
      // we add each character up until we found on of the checks as defined above.
      while bytesRead < buffer.count, !searchComplete {
        let pointer = bytes + bytesRead
        icecastHeaders.append(pointer, count: 1)

        if icecastHeaders.count >= stopProcessingCheckOne.count {
          if icecastHeaders.suffix(stopProcessingCheckOne.count) == stopProcessingCheckOne {
            iceHeaderAvailable = true
            searchComplete = true
            break
          }
        }

        if icecastHeaders.count >= stopProcessingCheckTwo.count {
          if icecastHeaders.suffix(stopProcessingCheckTwo.count) == stopProcessingCheckTwo {
            iceHeaderAvailable = true
            searchComplete = true
            break
          }
        }

        if icecastHeaders.count >= icyPrefix.count {
          // in case the first 4 chars are not "ICY " nor "HTTP" then we stop the flow
          if icecastHeaders[..<icyPrefix.count].elementsEqual(icyPrefix) == false,
             icecastHeaders[..<httpPrefix.count].elementsEqual(httpPrefix) == false {
            iceHeaderAvailable = false
            searchComplete = true
          }
        }

        bytesRead += 1
      }
      if !iceHeaderAvailable {
        return (nil, data)
      }
      let extractedAudio = data[icecastHeaders.count...]
      iceHeaderAvailable = false
      return (icecastHeaders, extractedAudio)
    }
  }
}
