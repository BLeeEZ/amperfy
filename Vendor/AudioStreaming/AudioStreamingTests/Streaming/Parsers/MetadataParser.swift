//
//  MetadataParser.swift
//  AudioStreamingTests
//
//  Created by Dimitrios Chatzieleftheriou on 01/06/2020.
//  Copyright © 2020 Decimal. All rights reserved.
//

import XCTest

@testable import AudioStreaming

class MetadataParserTests: XCTestCase {
  /// NOTE: Usual metadata values from icy stream are in the following format
  /// "StreamTtitle='A song title - Artist';StreamProducer='A producer'"

  func testParserOutputsCorrectResultFromCorrectData() throws {
    let string = "StreamTitle='A song - Artist';StreamSong='A song';StreamArtist='Artist';"
    let data = string.data(using: .utf8)!

    let parser = MetadataParser()

    let output = parser.parse(input: data)

    switch output {
    case let .success(values):
      XCTAssertFalse(values.isEmpty)
      XCTAssertEqual(values["StreamTitle"], "A song - Artist")
      XCTAssertEqual(values["StreamSong"], "A song")
      XCTAssertEqual(values["StreamArtist"], "Artist")
    case .failure:
      XCTFail()
    }
  }

  func testParserOutputsCorrectResultFromActualRawDataOfAudioStream() throws {
    let string = "StreamTitle=\'Gramatik - In This Whole World (Original Mix)\';\0\0\0\0"
    let data = string.data(using: .utf8)!

    let parser = MetadataParser()

    let output = parser.parse(input: data)

    switch output {
    case let .success(values):
      XCTAssertFalse(values.isEmpty)
      XCTAssertEqual(values["StreamTitle"], "Gramatik - In This Whole World (Original Mix)")
    case .failure:
      XCTFail()
    }
  }

  func testParserOutputsCorrectResultWhenEntryContainsEqualSign() throws {
    let string =
      "StreamTitle=\'Gramatik - In This Whole World (Original Mix)\';StreamUrl=\'\';track_info=\'k4Smc3RhdHVzoUihQNJiGp6BpHR5cGWhVKJpZKhNWDUxMTYzNISmc3RhdHVzoUOhQNJiGp9cpHR5cGWhVKJpZKhNWDUxMDM3MoSmc3RhdHVzoUOhQNJiGqAqpHR5cGWhVKJpZKhNWDUxMjA5Ng==\';UTC=\'20220226T214447.206\';\0\0\0\0\0\0\0\0\0"
    let data = string.data(using: .utf8)!

    let parser = MetadataParser()

    let output = parser.parse(input: data)

    switch output {
    case let .success(values):
      XCTAssertFalse(values.isEmpty)
      XCTAssertEqual(values["StreamTitle"], "Gramatik - In This Whole World (Original Mix)")
      XCTAssertEqual(values["StreamUrl"], "")
      XCTAssertEqual(
        values["track_info"],
        "k4Smc3RhdHVzoUihQNJiGp6BpHR5cGWhVKJpZKhNWDUxMTYzNISmc3RhdHVzoUOhQNJiGp9cpHR5cGWhVKJpZKhNWDUxMDM3MoSmc3RhdHVzoUOhQNJiGqAqpHR5cGWhVKJpZKhNWDUxMjA5Ng=="
      )
      XCTAssertEqual(values["UTC"], "20220226T214447.206")
    case .failure:
      XCTFail()
    }
  }

  func testParserOutputsFailureOnEmptyStringData() throws {
    let data = "".data(using: .utf8)!
    let parser = MetadataParser()

    let output = parser.parse(input: data)

    switch output {
    case .success:
      XCTFail()
    case let .failure(error):
      XCTAssertEqual(error, MetadataParsingError.empty)
    }
  }
}
