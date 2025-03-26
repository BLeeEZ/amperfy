//
//  SsLyricsBySongId2ParserTest.swift
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

class SsLyricsBySongId2ParserTest: AbstractSsParserTest {
  override func setUp() async throws {
    try await super.setUp()
    xmlData = getTestFileData(name: "getLyricsBySongId_example_2")
    ssParserDelegate = SsLyricsParserDelegate(performanceMonitor: MOCK_PerformanceMonitor())
  }

  override func createParserDelegate() {
    ssParserDelegate = SsLyricsParserDelegate(performanceMonitor: MOCK_PerformanceMonitor())
  }

  override func checkCorrectParsing() {
    guard let lyricsParser = ssParserDelegate as? SsLyricsParserDelegate,
          let lyricsList = lyricsParser.lyricsList
    else {
      XCTFail()
      return
    }
    prefetchIdTester.checkPrefetchIdCounts()

    XCTAssertEqual(lyricsList.lyrics.count, 2)

    var structuredLyrics = lyricsList.lyrics[0]
    XCTAssertEqual(structuredLyrics.displayArtist, "Muse")
    XCTAssertEqual(structuredLyrics.displayTitle, "Hysteria")
    XCTAssertEqual(structuredLyrics.lang, "en")
    XCTAssertEqual(structuredLyrics.offset, -100)
    XCTAssertTrue(structuredLyrics.synced)
    XCTAssertEqual(structuredLyrics.line.count, 3)
    XCTAssertEqual(structuredLyrics.line[0].start, 0)
    XCTAssertEqual(structuredLyrics.line[0].value, "It's bugging me")
    XCTAssertEqual(structuredLyrics.line[1].start, 2000)
    XCTAssertEqual(structuredLyrics.line[1].value, "Grating me")
    XCTAssertEqual(structuredLyrics.line[2].start, 3001)
    XCTAssertEqual(structuredLyrics.line[2].value, "And twisting me around...")

    structuredLyrics = lyricsList.lyrics[1]
    XCTAssertEqual(structuredLyrics.displayArtist, "Mu2se")
    XCTAssertEqual(structuredLyrics.displayTitle, "Hy2steria")
    XCTAssertEqual(structuredLyrics.lang, "de")
    XCTAssertEqual(structuredLyrics.offset, 100)
    XCTAssertFalse(structuredLyrics.synced)
    XCTAssertEqual(structuredLyrics.line.count, 3)
    XCTAssertEqual(structuredLyrics.line[0].start, nil)
    XCTAssertEqual(structuredLyrics.line[0].value, "It's bugging2 me")
    XCTAssertEqual(structuredLyrics.line[1].start, nil)
    XCTAssertEqual(structuredLyrics.line[1].value, "Grating2 me")
    XCTAssertEqual(structuredLyrics.line[2].start, nil)
    XCTAssertEqual(structuredLyrics.line[2].value, "And twisting2 me around...")
  }
}
