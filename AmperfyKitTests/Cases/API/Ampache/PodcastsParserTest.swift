//
//  PodcastsParserTest.swift
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

class PodcastsParserTest: AbstractAmpacheTest {
  override func setUp() async throws {
    try await super.setUp()
    xmlData = getTestFileData(name: "podcasts")
  }

  override func createParserDelegate() {
    let prefetch = library.getElements(account: account, prefetchIDs: idParserDelegate.prefetchIDs)
    parserDelegate = PodcastParserDelegate(
      performanceMonitor: MOCK_PerformanceMonitor(), prefetch: prefetch, account: account,
      library: library,
      parseNotifier: nil
    )
  }

  override func checkCorrectParsing() {
    parserDelegate?.performPostParseOperations()

    prefetchIdTester.checkPrefetchIdCounts(
      artworkCount: 3,
      podcastCount: 3
    )

    let podcasts = library.getPodcasts(for: account)
    XCTAssertEqual(podcasts.count, 3)

    var podcast = podcasts[0]
    XCTAssertEqual(podcast.account?.serverHash, TestAccountInfo.test1ServerHash)
    XCTAssertEqual(podcast.account?.userHash, TestAccountInfo.test1UserHash)
    XCTAssertEqual(podcast.id, "1")
    XCTAssertEqual(podcast.title, "60-Second < Science")
    XCTAssertEqual(podcast.rating, 2)
    XCTAssertFalse(podcast.isCached)
    XCTAssertEqual(
      podcast.depiction,
      "Tune in every < weekday for quick reports and commentaries on the world of science—it'll just take a minute"
    )
    XCTAssertEqual(podcast.artwork?.type, "podcast")
    XCTAssertEqual(podcast.artwork?.id, "1")

    podcast = podcasts[1]
    XCTAssertEqual(podcast.account?.serverHash, TestAccountInfo.test1ServerHash)
    XCTAssertEqual(podcast.account?.userHash, TestAccountInfo.test1UserHash)
    XCTAssertEqual(podcast.id, "2")
    XCTAssertEqual(podcast.title, "Plays Well with Others")
    XCTAssertEqual(podcast.rating, 0)
    XCTAssertFalse(podcast.isCached)
    XCTAssertEqual(
      podcast.depiction,
      "From Creative Commons, a podcast about the art and science of collaboration. With a focus on the tools, techniques, and mechanics of collaboration, we explore how today's most interesting collaborators are making new things, solving old problems, and getting things done — together. Hosted by Creative Commons CEO Ryan Merkley."
    )
    XCTAssertEqual(podcast.artwork?.account?.serverHash, TestAccountInfo.test1ServerHash)
    XCTAssertEqual(podcast.artwork?.account?.userHash, TestAccountInfo.test1UserHash)
    XCTAssertEqual(podcast.artwork?.type, "podcast")
    XCTAssertEqual(podcast.artwork?.id, "2")

    podcast = podcasts[2]
    XCTAssertEqual(podcast.account?.serverHash, TestAccountInfo.test1ServerHash)
    XCTAssertEqual(podcast.account?.userHash, TestAccountInfo.test1UserHash)
    XCTAssertEqual(podcast.id, "5")
    XCTAssertEqual(podcast.title, "Trace")
    XCTAssertEqual(podcast.rating, 1)
    XCTAssertFalse(podcast.isCached)
    XCTAssertEqual(
      podcast.depiction,
      "Lawyer Nicola Gobbo represented some of Australia’s most dangerous criminals, all the while secretly working as a police informer. Why did she do it, and how was it allowed to happen? For the first time, she tells the full story behind why she became an informer, and what happened when her double life was exposed to the world."
    )
    XCTAssertEqual(podcast.artwork?.account?.serverHash, TestAccountInfo.test1ServerHash)
    XCTAssertEqual(podcast.artwork?.account?.userHash, TestAccountInfo.test1UserHash)
    XCTAssertEqual(podcast.artwork?.type, "podcast")
    XCTAssertEqual(podcast.artwork?.id, "5")
  }
}
