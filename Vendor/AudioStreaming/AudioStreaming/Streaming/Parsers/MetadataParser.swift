//
//  Created by Dimitrios Chatzieleftheriou on 28/05/2020.
//  Copyright © 2020 Decimal. All rights reserved.
//

import Foundation

// MARK: - MetadataParsingError

public enum MetadataParsingError: Error, Equatable {
  case unableToParse
  case empty
}

typealias MetadataOutput = Result<[String: String], MetadataParsingError>

// MARK: - MetadataParser

struct MetadataParser: Parser {
  typealias Input = Data
  typealias Output = MetadataOutput

  func parse(input: Data) -> MetadataOutput {
    guard let string = String(data: input, encoding: .utf8) else { return .failure(.unableToParse) }
    // remove added bytes (zeros) and separate the string on every ';' char
    let pairs = string.trimmingCharacters(in: CharacterSet(charactersIn: "\0"))
      .components(separatedBy: ";")
    let metadata = pairs.reduce(into: [String: String]()) { result, next in
      let split = next.split(
        separator: "=",
        maxSplits: 1,
        omittingEmptySubsequences: true
      )
      .map(String.init)
      if let key = split.first,
         let value = split.last?.replacingOccurrences(of: "'", with: ""), !key.isEmpty {
        result[key] = value
      }
    }
    guard !metadata.isEmpty else { return .failure(.empty) }
    return .success(metadata)
  }
}
