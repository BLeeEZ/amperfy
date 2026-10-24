//
//  IcycastHeaderParser.swift
//  AudioStreaming
//
//  Created by Dimitrios C on 14/02/2021.
//  Copyright © 2021 Decimal. All rights reserved.
//

import Foundation

struct IcycastHeaderParser: Parser {
  func parse(input: Data) -> HTTPHeaderParserOutput? {
    guard let icecastValue = String(data: input, encoding: .utf8) else {
      return nil
    }
    let headers = icecastValue.components(separatedBy: CharacterSet(charactersIn: "\r\n"))
    var result = [String: String]()
    for header in headers where !header.isEmpty {
      let values = header.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: true)
      if let key = values.first, let value = values.last {
        result[String(key)] = String(value)
      }
    }
    let metadataStep = Int(result[IcyHeaderField.icyMetaint] ?? "") ?? 0
    let contentType = result[HeaderField.contentType.lowercased()] ?? "audio/mpeg"
    let typeId = audioFileType(mimeType: contentType)

    return HTTPHeaderParserOutput(
      fileLength: 0,
      typeId: typeId,
      metadataStep: metadataStep,
      seekable: false
    )
  }
}
