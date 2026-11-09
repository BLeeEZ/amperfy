//
//  SsOpenSubsonicExtensions2ParserTest.swift
//  AmperfyKitTests
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

/// getOpenSubsonicExtensions of Navidrome 0.64.2
class SsOpenSubsonicExtensions2ParserTest: AbstractSsParserTest {
  override func setUp() async throws {
    try await super.setUp()
    xmlData = getTestFileData(name: "OpenSubsonicExtensions_example_2")
  }

  override func createParserDelegate() {
    ssParserDelegate =
      SsOpenSubsonicExtensionsParserDelegate(performanceMonitor: MOCK_PerformanceMonitor())
  }

  override func checkCorrectParsing() {
    guard let extensionsParser = ssParserDelegate as? SsOpenSubsonicExtensionsParserDelegate
    else {
      XCTFail()
      return
    }
    prefetchIdTester.checkPrefetchIdCounts()

    let response = extensionsParser.openSubsonicExtensionsResponse

    XCTAssertEqual(response.status, "ok")
    XCTAssertEqual(response.type, "navidrome")
    XCTAssertEqual(response.serverVersion, "0.64.2 (10114574)")
    XCTAssertEqual(response.openSubsonic, true)

    XCTAssertEqual(response.supportedExtensions, [
      "transcodeOffset",
      "formPost",
      "songLyrics",
      "indexBasedQueue",
      "transcoding",
      "playbackReport",
      "topSongsByArtistId",
    ])
    XCTAssertEqual(response.supportedExtensionVersions["songLyrics"], [1, 2])
    XCTAssertEqual(response.supportedExtensionVersions["indexBasedQueue"], [1])
    XCTAssertEqual(response.supportedExtensionVersions.count, 7)

    XCTAssertTrue(response.isExtensionSupported("songLyrics", minVersion: 1))
    XCTAssertTrue(response.isExtensionSupported("songLyrics", minVersion: 2))
    XCTAssertFalse(response.isExtensionSupported("songLyrics", minVersion: 3))
    XCTAssertTrue(response.isExtensionSupported("formPost", minVersion: 1))
    XCTAssertFalse(response.isExtensionSupported("formPost", minVersion: 2))
    XCTAssertFalse(response.isExtensionSupported("unknownExtension", minVersion: 1))
  }
}
