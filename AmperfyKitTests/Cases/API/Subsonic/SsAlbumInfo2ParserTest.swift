//
//  SsAlbumInfo2ParserTest.swift
//  AmperfyKitTests
//
//  Created by Ziwei Wu on 23.10.26.
//  Copyright (c) 2026 Maximilian Bauer. All rights reserved.
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

class SsAlbumInfo2ParserTest: AbstractSsParserTest {
  override func setUp() async throws {
    try await super.setUp()
    xmlData = getTestFileData(name: "albumInfo2_example_1")
    ssParserDelegate = SsDepictionParserDelegate(performanceMonitor: MOCK_PerformanceMonitor())
  }

  override func createParserDelegate() {
    ssParserDelegate = SsDepictionParserDelegate(performanceMonitor: MOCK_PerformanceMonitor())
  }

  override func checkCorrectParsing() {
    guard let depictionParser = ssParserDelegate as? SsDepictionParserDelegate else {
      XCTFail()
      return
    }
    prefetchIdTester.checkPrefetchIdCounts()

    XCTAssertEqual(
      depictionParser.depiction,
      "Paranoid is the second studio album by Black Sabbath. <a target='_blank' href=\"http://www.last.fm/music/Black+Sabbath/Paranoid\">Read more on Last.fm</a>."
    )
  }
}
