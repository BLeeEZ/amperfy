//
//  SsPodcastParserTest.swift
//  AmperfyKitTests
//
//  Created by Maximilian Bauer on 25.06.21.
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

class SsPodcastParserTest: AbstractSsParserTest {
  override func setUp() async throws {
    try await super.setUp()
    xmlData = getTestFileData(name: "podcasts_example_1")
    ssParserDelegate = SsPodcastParserDelegate(
      performanceMonitor: MOCK_PerformanceMonitor(),
      library: library,
      parseNotifier: nil
    )
  }

  override func recreateParserDelegate() {
    ssParserDelegate = SsPodcastParserDelegate(
      performanceMonitor: MOCK_PerformanceMonitor(),
      library: library,
      parseNotifier: nil
    )
  }

  override func checkCorrectParsing() {
    ssParserDelegate?.performPostParseOperations()
    let podcasts = library.getPodcasts().sorted(by: { Int($0.id)! < Int($1.id)! })
    XCTAssertEqual(podcasts.count, 2)

    var podcast = podcasts[0]
    XCTAssertEqual(podcast.id, "1")
    XCTAssertEqual(podcast.title, "Dr Karl and the < Naked Scientist")
    XCTAssertEqual(
      podcast.depiction,
      "Dr Chris Smith aka The < Naked Scientist with the latest news from the world of science and Dr Karl answers listeners' science questions."
    )
    XCTAssertEqual(podcast.artwork?.url, "")
    XCTAssertEqual(podcast.artwork?.type, "")
    XCTAssertEqual(podcast.artwork?.id, "pod-1")
    XCTAssertFalse(podcast.isCached)

    podcast = podcasts[1]
    XCTAssertEqual(podcast.id, "2")
    XCTAssertEqual(podcast.title, "NRK P1 - Herreavdelingen")
    XCTAssertEqual(
      podcast.depiction,
      "Et program der herrene Yan Friis og Finn Bjelke møtes og musikk nytes."
    )
    XCTAssertEqual(podcast.artwork?.url, "")
    XCTAssertEqual(podcast.artwork?.type, "")
    XCTAssertEqual(podcast.artwork?.id, "pod-2")
    XCTAssertFalse(podcast.isCached)
  }
}
