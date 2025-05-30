//
//  PodcastEpisodesParserTest.swift
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

class PodcastEpisodesParserTest: AbstractAmpacheTest {
  var testPodcast: Podcast?

  override func setUp() async throws {
    try await super.setUp()
    xmlData = getTestFileData(name: "podcast_episodes")
    testPodcast = library.createPodcast()
  }

  override func createParserDelegate() {
    let prefetch = library.getElements(prefetchIDs: idParserDelegate.prefetchIDs)
    parserDelegate = PodcastEpisodeParserDelegate(
      performanceMonitor: MOCK_PerformanceMonitor(),
      podcast: testPodcast!, prefetch: prefetch,
      library: library
    )
  }

  func testCacheParsing() {
    guard let podcast = testPodcast else { XCTFail(); return }
    testParsing()
    XCTAssertFalse((parserDelegate as! PlayableParserDelegate).isCollectionCached)

    // mark all songs cached
    for song in podcast.episodes {
      song.relFilePath = URL(string: "jop")
    }
    testParsing()
    XCTAssertTrue((parserDelegate as! PlayableParserDelegate).isCollectionCached)

    // mark all songs cached exect the last one
    for song in podcast.episodes {
      song.relFilePath = URL(string: "jop")
    }
    podcast.episodes.last?.relFilePath = nil
    testParsing()
    XCTAssertFalse((parserDelegate as! PlayableParserDelegate).isCollectionCached)
  }

  override func checkCorrectParsing() {
    parserDelegate?.performPostParseOperations()

    prefetchIdTester.checkPrefetchIdCounts(
      artworkCount: 1,
      podcastEpisodeCount: 4,
      podcastCount: 0,
      podcastLibraryCount: 1 // the one create for this test
    )

    guard let podcast = testPodcast else { XCTFail(); return }
    XCTAssertEqual(podcast.episodes.count, 4)

    var episode = podcast.episodes[0]
    XCTAssertEqual(episode.id, "44")
    XCTAssertEqual(
      episode.title,
      "COVID, Quickly, Episode < 3: Vaccine Inequality--plus Your Body the Variant Fighter"
    )
    XCTAssertEqual(episode.rating, 5)
    XCTAssertEqual(
      episode.depiction,
      "Today we bring you < the third episode in a new podcast series: COVID, Quickly. Every two weeks, Scientific American’s senior health editors Tanya...\n"
    )
    XCTAssertEqual(episode.publishDate.timeIntervalSince1970, 1616815800) // "3/27/21, 3:30 AM"
    XCTAssertNil(episode.streamId)
    XCTAssertEqual(episode.podcastStatus, .completed)
    XCTAssertEqual(episode.podcast, podcast)
    XCTAssertNil(episode.disk)
    XCTAssertEqual(episode.track, 0)
    XCTAssertEqual(episode.duration, 325)
    XCTAssertEqual(episode.year, 0)
    XCTAssertEqual(episode.bitrate, 0)
    XCTAssertEqual(episode.contentType, "audio/mpeg")
    XCTAssertEqual(
      episode.url,
      "https://music.com.au/play/index.php?ssid=cfj3f237d563f479f5223k23189dbb34&type=podcast_episode&oid=44&uid=4&format=raw&player=api&name=60-Second%20Science%20-%20COVID-%20Quickly-%20Episode%203-%20Vaccine%20Inequality-plus%20Your%20Body%20the%20Variant%20Fighter.mp3"
    )
    XCTAssertEqual(episode.size, 5460000)
    XCTAssertEqual(episode.artwork?.type, "podcast")
    XCTAssertEqual(episode.artwork?.id, "1")

    episode = podcast.episodes[2]
    XCTAssertEqual(episode.id, "46")
    XCTAssertEqual(episode.title, "Smartphones Can Hear the Shape of Your Door Keys")
    XCTAssertEqual(episode.rating, 0)
    XCTAssertEqual(
      episode.depiction,
      "Can you pick a lock with just a smartphone? New research shows that doing so is possible."
    )
    XCTAssertEqual(episode.publishDate.timeIntervalSince1970, 1616104800) // "3/18/21, 10:00 PM"
    XCTAssertNil(episode.streamId)
    XCTAssertEqual(episode.podcastStatus, .downloading)
    XCTAssertEqual(episode.podcast, podcast)
    XCTAssertNil(episode.disk)
    XCTAssertEqual(episode.track, 0)
    XCTAssertEqual(episode.duration, 222)
    XCTAssertEqual(episode.year, 0)
    XCTAssertEqual(episode.bitrate, 0)
    XCTAssertEqual(episode.contentType, "")
    XCTAssertEqual(
      episode.url,
      "https://music.com.au/play/index.php?ssid=cfj3f237d563f479f5223k23189dbb34&type=podcast_episode&oid=46&uid=4&format=raw&player=api&name=60-Second%20Science%20-%20Smartphones%20Can%20Hear%20the%20Shape%20of%20Your%20Door%20Keys."
    )
    XCTAssertEqual(episode.size, 0)
    XCTAssertEqual(episode.artwork?.type, "podcast")
    XCTAssertEqual(episode.artwork?.id, "1")

    episode = podcast.episodes[3]
    XCTAssertEqual(episode.id, "47")
    XCTAssertEqual(
      episode.title,
      "Chimpanzees Show Altruism while Gathering around the Juice Fountain"
    )
    XCTAssertEqual(episode.rating, 1)
    XCTAssertEqual(
      episode.depiction,
      "New research tries to tease out whether our closest animal relatives can be selfless."
    )
    XCTAssertEqual(episode.publishDate.timeIntervalSince1970, 1615933800) // "3/16/21, 10:30 PM"
    XCTAssertNil(episode.streamId)
    XCTAssertEqual(episode.podcastStatus, .downloading)
    XCTAssertEqual(episode.podcast, podcast)
    XCTAssertNil(episode.disk)
    XCTAssertEqual(episode.track, 0)
    XCTAssertEqual(episode.duration, 296)
    XCTAssertEqual(episode.year, 0)
    XCTAssertEqual(episode.bitrate, 0)
    XCTAssertEqual(episode.contentType, "")
    XCTAssertEqual(
      episode.url,
      "https://music.com.au/play/index.php?ssid=cfj3f237d563f479f5223k23189dbb34&type=podcast_episode&oid=47&uid=4&format=raw&player=api&name=60-Second%20Science%20-%20Chimpanzees%20Show%20Altruism%20while%20Gathering%20around%20the%20Juice%20Fountain."
    )
    XCTAssertEqual(episode.size, 0)
    XCTAssertEqual(episode.artwork?.type, "podcast")
    XCTAssertEqual(episode.artwork?.id, "1")

    // denormalized value -> will be updated at save context
    library.saveContext()
    XCTAssertEqual(podcast.episodeCount, 4)
  }
}
