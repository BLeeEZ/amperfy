//
//  PodcastEpisodeTest.swift
//  AmperfyKitTests
//
//  Created by Maximilian Bauer on 31.01.25.
//  Copyright (c) 2019 Maximilian Bauer. All rights reserved.
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

@MainActor
class PodcastEpisodeTest: XCTestCase {
  var cdHelper: CoreDataHelper!
  var library: LibraryStorage!
  var testEpisode: PodcastEpisode!
  let testId = "2345"

  override func setUp() async throws {
    cdHelper = CoreDataHelper()
    library = cdHelper.createSeededStorage()
    testEpisode = library.createPodcastEpisode()
    testEpisode.id = testId
  }

  override func tearDown() {}

  func testCreation() {
    let episode = library.createPodcastEpisode()
    XCTAssertEqual(episode.id, "")
    XCTAssertNil(episode.artwork)
    XCTAssertEqual(episode.title, "Unknown Title")
    XCTAssertEqual(episode.track, 0)
    XCTAssertEqual(episode.url, nil)
    XCTAssertEqual(episode.podcast, nil)
    XCTAssertEqual(episode.displayString, "Unknown Podcast - Unknown Title")
    XCTAssertEqual(
      episode.image(theme: .blue, setting: .serverArtworkOnly),
      UIImage.getGeneratedArtwork(theme: .blue, artworkType: .podcastEpisode)
    )
    XCTAssertFalse(episode.isCached)
  }

  func testPodcast() {
    let podcast = library.createPodcast()
    podcast.id = "1234"
    testEpisode.podcast = podcast
    XCTAssertEqual(podcast.id, "1234")
    XCTAssertEqual(testEpisode.podcast!.id, podcast.id)
    library.saveContext()
    guard let episodeFetched = library.getPodcastEpisode(id: testId) else { XCTFail(); return }
    XCTAssertEqual(episodeFetched.podcast!.id, podcast.id)
  }

  func testTitle() {
    let testTitle = "Alright"
    testEpisode.title = testTitle
    XCTAssertEqual(testEpisode.title, testTitle)
    XCTAssertEqual(testEpisode.displayString, "Unknown Podcast - " + testTitle)
    library.saveContext()
    guard let episodeFetched = library.getPodcastEpisode(id: testId) else { XCTFail(); return }
    XCTAssertEqual(episodeFetched.title, testTitle)
    XCTAssertEqual(episodeFetched.displayString, "Unknown Podcast - " + testTitle)
  }

  func testUrl() {
    let testUrl = "www.blub.de"
    testEpisode.url = testUrl
    XCTAssertEqual(testEpisode.url, testUrl)
    library.saveContext()
    guard let episodeFetched = library.getPodcastEpisode(id: testId) else { XCTFail(); return }
    XCTAssertEqual(episodeFetched.url, testUrl)
  }

  func testArtworkAndImage() {
    let testData = UIImage.getGeneratedArtwork(theme: .blue, artworkType: .podcastEpisode)
      .pngData()!
    let testImg = UIImage.getGeneratedArtwork(theme: .blue, artworkType: .podcastEpisode)
    let relFilePath = URL(string: "testArtwork")!
    let absFilePath = CacheFileManager.shared.getAbsoluteAmperfyPath(relFilePath: relFilePath)!
    try! CacheFileManager.shared.writeDataExcludedFromBackup(data: testData, to: absFilePath)
    testEpisode.artwork = library.createArtwork()
    testEpisode.artwork?.relFilePath = relFilePath
    XCTAssertNil(testEpisode.artwork?.image)
    XCTAssertEqual(testEpisode.image(theme: .blue, setting: .serverArtworkOnly), testImg)
    library.saveContext()
    guard let episodeFetched = library.getPodcastEpisode(id: testId) else { XCTFail(); return }
    XCTAssertNil(episodeFetched.artwork?.image)
    XCTAssertEqual(episodeFetched.image(theme: .blue, setting: .serverArtworkOnly), testImg)
    try! CacheFileManager.shared.removeItem(at: absFilePath)
  }

  func testEpisodeDeleteCache() {
    let podcast = library.createPodcast()
    podcast.id = "1234"
    testEpisode.podcast = podcast

    guard let playlist1 = library.getPlaylist(id: cdHelper.seeder.playlists[0].id)
    else { XCTFail(); return }
    playlist1.append(playable: testEpisode)
    guard let playlist2 = library.getPlaylist(id: cdHelper.seeder.playlists[1].id)
    else { XCTFail(); return }
    playlist2.append(playable: testEpisode)

    testEpisode.relFilePath = URL(string: "blub")
    podcast.isCached = true
    playlist1.isCached = true
    playlist2.isCached = true
    library.saveContext()

    XCTAssertTrue(testEpisode.isCached)
    XCTAssertTrue(podcast.isCached)
    XCTAssertTrue(playlist1.isCached)
    XCTAssertTrue(playlist2.isCached)
    library.deleteCache(ofPlayable: testEpisode)
    XCTAssertFalse(testEpisode.isCached)
    XCTAssertFalse(podcast.isCached)
    XCTAssertFalse(playlist1.isCached)
    XCTAssertFalse(playlist2.isCached)
  }
}
