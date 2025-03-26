//
//  SsOpenSubsonicExtensionsParserTest.swift
//  AmperfyKitTests
//
//  Created by Maximilian Bauer on 16.06.24.
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

class SsOpenSubsonicExtensionsParserTest: AbstractSsParserTest {
  override func setUp() async throws {
    try await super.setUp()
    xmlData = getTestFileData(name: "OpenSubsonicExtensions_example_1")
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
    XCTAssertEqual(response.version, "1.16.1")
    XCTAssertEqual(response.type, "navidrome")
    XCTAssertEqual(response.serverVersion, "0.52.5 (c5560888)")
    XCTAssertEqual(response.openSubsonic, true)

    XCTAssertEqual(response.supportedExtensions.count, 3)

    XCTAssertEqual(response.supportedExtensions[0], "transcodeOffset")
    XCTAssertEqual(response.supportedExtensions[1], "formPost")
    XCTAssertEqual(response.supportedExtensions[2], "songLyrics")
  }
}
