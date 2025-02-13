//
//  AuthParserTest.swift
//  AmperfyKitTests
//
//  Created by Maximilian Bauer on 01.06.21.
//  Copyright (c) 2021 Maximilian Bauer. All rights reserved.
//
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program.  If not, see <http://www.gnu.org/licenses/>.
//

@testable import AmperfyKit
import XCTest

class AuthParserTest: XCTestCase {
  var xmlData: Data!

  override func setUp() {
    xmlData = getTestFileData(name: "handshake")
  }

  func testParsing() {
    let parserDelegate = AuthParserDelegate(performanceMonitor: MOCK_PerformanceMonitor())
    let parser = XMLParser(data: xmlData)
    parser.delegate = parserDelegate
    parser.parse()

    XCTAssertNil(parserDelegate.error)
    XCTAssertEqual(parserDelegate.serverApiVersion, "5.0.0")
    guard let handshake = parserDelegate.authHandshake else { XCTFail(); return }
    XCTAssertEqual(handshake.token, "cfj3f237d563f479f5223k23189dbb34")
    XCTAssertEqual(handshake.sessionExpire, "2021-03-31T18:16:10+10:00".asIso8601Date)
    XCTAssertEqual(
      handshake.libraryChangeDates.dateOfLastAdd,
      "2021-03-31T13:32:27+10:00".asIso8601Date
    )
    XCTAssertEqual(
      handshake.libraryChangeDates.dateOfLastClean,
      "2021-03-31T17:15:18+10:00".asIso8601Date
    )
    XCTAssertEqual(
      handshake.libraryChangeDates.dateOfLastUpdate,
      "2021-03-31T17:15:25+10:00".asIso8601Date
    )
    XCTAssertEqual(handshake.songCount, 55)
    XCTAssertEqual(handshake.artistCount, 16)
    XCTAssertEqual(handshake.albumCount, 8)
    XCTAssertEqual(handshake.genreCount, 6)
    XCTAssertEqual(handshake.playlistCount, 19)
    XCTAssertEqual(handshake.podcastCount, 3)
    XCTAssertEqual(handshake.videoCount, 2)
  }
}
