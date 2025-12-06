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
  }

  override func createParserDelegate() {
    let prefetch = library.getElements(
      account: account,
      prefetchIDs: ssIdParserDelegate.prefetchIDs
    )
    ssParserDelegate = SsPodcastParserDelegate(
      performanceMonitor: MOCK_PerformanceMonitor(), prefetch: prefetch, account: account,
      library: library,
      parseNotifier: nil
    )
  }

  override func checkCorrectParsing() {
    ssParserDelegate?.performPostParseOperations()

    prefetchIdTester.checkPrefetchIdCounts(
      artworkCount: 4,
      podcastEpisodeCount: 2,
      podcastCount: 3,
      artworkFetchCount: 2, // the podcast episodes cover itself is not created
      podcastEpisodeFetchCount: 0, // no episodes are parsed
      podcastFetchCount: 2 // one podcast has an error
    )

    let podcasts = library.getPodcasts(for: account).sorted(by: { Int($0.id)! < Int($1.id)! })
    XCTAssertEqual(podcasts.count, 2)

    var podcast = podcasts[0]
    XCTAssertEqual(podcast.account?.serverHash, TestAccountInfo.test1ServerHash)
    XCTAssertEqual(podcast.account?.userHash, TestAccountInfo.test1UserHash)
    XCTAssertEqual(podcast.id, "1")
    XCTAssertEqual(podcast.title, "Dr Karl and the < Naked Scientist")
    XCTAssertEqual(
      podcast.depiction,
      "Dr Chris Smith aka The < Naked Scientist with the latest news from the world of science and Dr Karl answers listeners' science questions."
    )
    XCTAssertEqual(podcast.artwork?.account?.serverHash, TestAccountInfo.test1ServerHash)
    XCTAssertEqual(podcast.artwork?.account?.userHash, TestAccountInfo.test1UserHash)
    XCTAssertEqual(podcast.artwork?.type, "")
    XCTAssertEqual(podcast.artwork?.id, "pod-1")
    XCTAssertFalse(podcast.isCached)

    podcast = podcasts[1]
    XCTAssertEqual(podcast.account?.serverHash, TestAccountInfo.test1ServerHash)
    XCTAssertEqual(podcast.account?.userHash, TestAccountInfo.test1UserHash)
    XCTAssertEqual(podcast.id, "2")
    XCTAssertEqual(podcast.title, "NRK P1 - Herreavdelingen")
    XCTAssertEqual(
      podcast.depiction,
      "Et program der herrene Yan Friis og Finn Bjelke møtes og musikk nytes."
    )
    XCTAssertEqual(podcast.artwork?.account?.serverHash, TestAccountInfo.test1ServerHash)
    XCTAssertEqual(podcast.artwork?.account?.userHash, TestAccountInfo.test1UserHash)
    XCTAssertEqual(podcast.artwork?.type, "")
    XCTAssertEqual(podcast.artwork?.id, "pod-2")
    XCTAssertFalse(podcast.isCached)
  }
}
