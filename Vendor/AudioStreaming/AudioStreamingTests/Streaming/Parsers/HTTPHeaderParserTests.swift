//
//  Created by Dimitrios Chatzieleftheriou on 01/06/2020.
//  Copyright © 2020 Decimal. All rights reserved.
//

import AudioToolbox.AudioFile
import XCTest

@testable import AudioStreaming

class HTTPHeaderParserTests: XCTestCase {
  func testReturnNilWhenHeaderFieldsAreEmpty() throws {
    // Given
    let parser = HTTPHeaderParser()

    // When
    let httpURLResponse = HTTPURLResponse(
      url: URL(string: "www.google.com")!,
      statusCode: 200,
      httpVersion: "",
      headerFields: [:]
    )

    let output = parser.parse(input: httpURLResponse!)

    // Then
    // should return nil on empty headers
    XCTAssertNil(output)
  }

  func testReturnCorrectValuesOnNormalRequest() throws {
    // Given
    let parser = HTTPHeaderParser()

    // When
    let headers: [String: String] =
      [
        HeaderField.contentLength: "1000",
        HeaderField.contentType: "audio/mp3",
        IcyHeaderField.icyMetaint: "16000",
      ]
    let httpURLResponse = HTTPURLResponse(
      url: URL(string: "www.google.com")!,
      statusCode: 200,
      httpVersion: "",
      headerFields: headers
    )

    let output = parser.parse(input: httpURLResponse!)

    // Then
    XCTAssertNotNil(output)
    XCTAssertEqual(output!.fileLength, 1000)
    XCTAssertEqual(output!.typeId, kAudioFileMP3Type)
    XCTAssertEqual(output!.metadataStep, 16000)
  }

  func testReturnCorectValuesOnCaseInsensitiveHeaderFiels() throws {
    // Given
    let parser = HTTPHeaderParser()

    // When
    let headers: [String: String] =
      [
        HeaderField.contentLength.lowercased(): "1000",
        HeaderField.contentType.lowercased(): "audio/mp3",
        IcyHeaderField.icyMetaint.lowercased(): "16000",
      ]
    let httpURLResponse = HTTPURLResponse(
      url: URL(string: "www.google.com")!,
      statusCode: 200,
      httpVersion: "",
      headerFields: headers
    )

    let output = parser.parse(input: httpURLResponse!)

    // Then
    XCTAssertNotNil(output)
    XCTAssertEqual(output!.fileLength, 1000)
    XCTAssertEqual(output!.typeId, kAudioFileMP3Type)
    XCTAssertEqual(output!.metadataStep, 16000)
  }
}
