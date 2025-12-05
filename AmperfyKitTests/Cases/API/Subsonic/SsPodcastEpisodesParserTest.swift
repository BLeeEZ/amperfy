//
//  SsPodcastEpisodesParserTest.swift
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

class SsPodcastEpisodesParserTest: AbstractSsParserTest {
  var testPodcast: Podcast?

  override func setUp() async throws {
    try await super.setUp()
    xmlData = getTestFileData(name: "podcast_example_1")
    testPodcast = library.createPodcast(account: account)
    testPodcast?.id = "1"
  }

  override func createParserDelegate() {
    let prefetch = library.getElements(
      account: account,
      prefetchIDs: ssIdParserDelegate.prefetchIDs
    )
    ssParserDelegate = SsPodcastEpisodeParserDelegate(
      performanceMonitor: MOCK_PerformanceMonitor(),
      podcast: testPodcast!, prefetch: prefetch, account: account,
      library: library
    )
  }

  func testCacheParsing() {
    guard let podcast = testPodcast else { XCTFail(); return }

    testParsing()
    XCTAssertFalse((ssParserDelegate as! SsPlayableParserDelegate).isCollectionCached)

    // mark all songs cached
    for episode in podcast.episodes {
      episode.relFilePath = URL(string: "jop")
    }
    testParsing()
    XCTAssertTrue((ssParserDelegate as! SsPlayableParserDelegate).isCollectionCached)

    // mark all songs cached execept the last one
    for episode in podcast.episodes {
      episode.relFilePath = URL(string: "jop")
    }
    podcast.episodes.last?.relFilePath = nil
    testParsing()
    XCTAssertFalse((ssParserDelegate as! SsPlayableParserDelegate).isCollectionCached)
  }

  override func checkCorrectParsing() {
    ssParserDelegate?.performPostParseOperations()
    guard let podcast = testPodcast else { XCTFail(); return }
    XCTAssertEqual(podcast.episodes.count, 2)

    prefetchIdTester.checkPrefetchIdCounts(
      artworkCount: 3,
      podcastEpisodeCount: 2,
      podcastCount: 1,
      artworkFetchCount: 2, // the podcast cover itself is not created
      podcastLibraryCount: 1 // the podcast for this test created in setup
    )

    // episodes are sorted by publish date
    var episode = podcast.episodes[1]
    XCTAssertEqual(episode.account?.serverHash, TestAccountInfo.test1ServerHash)
    XCTAssertEqual(episode.account?.userHash, TestAccountInfo.test1UserHash)
    XCTAssertEqual(episode.id, "34")
    XCTAssertEqual(episode.title, "Scorpions have re-evolved < eyes")
    XCTAssertEqual(
      episode.depiction,
      "This week < Dr Chris fills us in on the UK's largest free science festival, plus all this week's big scientific discoveries."
    )
    XCTAssertEqual(episode.publishDate.timeIntervalSince1970, 1296744403) // "2011-02-03T14:46:43"
    XCTAssertEqual(episode.streamId, "523")
    XCTAssertEqual(episode.podcastStatus, .completed)
    XCTAssertEqual(episode.podcast?.account?.serverHash, TestAccountInfo.test1ServerHash)
    XCTAssertEqual(episode.podcast?.account?.userHash, TestAccountInfo.test1UserHash)
    XCTAssertEqual(episode.podcast, podcast)
    XCTAssertNil(episode.disk)
    XCTAssertEqual(episode.track, 0)
    XCTAssertEqual(episode.duration, 3146)
    XCTAssertEqual(episode.year, 2011)
    XCTAssertEqual(episode.bitrate, 128000)
    XCTAssertEqual(episode.contentType, "audio/mpeg")
    XCTAssertNil(episode.url)
    XCTAssertEqual(episode.size, 78421341)
    XCTAssertEqual(episode.artwork?.account?.serverHash, TestAccountInfo.test1ServerHash)
    XCTAssertEqual(episode.artwork?.account?.userHash, TestAccountInfo.test1UserHash)
    XCTAssertEqual(episode.artwork?.type, "")
    XCTAssertEqual(episode.artwork?.id, "24")

    episode = podcast.episodes[0]
    XCTAssertEqual(episode.account?.serverHash, TestAccountInfo.test1ServerHash)
    XCTAssertEqual(episode.account?.userHash, TestAccountInfo.test1UserHash)
    XCTAssertEqual(episode.id, "35")
    XCTAssertEqual(episode.title, "Scar tissue and snake venom treatment")
    XCTAssertEqual(
      episode.depiction,
      "This week Dr Karl tells the gruesome tale of a surgeon who operated on himself."
    )
    XCTAssertEqual(episode.publishDate.timeIntervalSince1970, 1315068472) // "2011-09-03T16:47:52"
    XCTAssertEqual(episode.streamId, "524")
    XCTAssertEqual(episode.podcastStatus, .completed)
    XCTAssertEqual(episode.podcast?.account?.serverHash, TestAccountInfo.test1ServerHash)
    XCTAssertEqual(episode.podcast?.account?.userHash, TestAccountInfo.test1UserHash)
    XCTAssertEqual(episode.podcast, podcast)
    XCTAssertNil(episode.disk)
    XCTAssertEqual(episode.track, 0)
    XCTAssertEqual(episode.duration, 3099)
    XCTAssertEqual(episode.year, 2011)
    XCTAssertEqual(episode.bitrate, 128000)
    XCTAssertEqual(episode.contentType, "audio/mpeg")
    XCTAssertNil(episode.url)
    XCTAssertEqual(episode.size, 45624671)
    XCTAssertEqual(episode.artwork?.account?.serverHash, TestAccountInfo.test1ServerHash)
    XCTAssertEqual(episode.artwork?.account?.userHash, TestAccountInfo.test1UserHash)
    XCTAssertEqual(episode.artwork?.type, "")
    XCTAssertEqual(episode.artwork?.id, "27")

    // denormalized value -> will be updated at save context
    library.saveContext()
    XCTAssertEqual(podcast.episodeCount, 2)
  }
}
