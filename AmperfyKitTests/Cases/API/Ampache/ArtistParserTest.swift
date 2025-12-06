//
//  ArtistParserTest.swift
//  AmperfyKitTests
//
//  Created by Maximilian Bauer on 01.06.21.
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

class ArtistParserTest: AbstractAmpacheTest {
  override func setUp() async throws {
    try await super.setUp()
    xmlData = getTestFileData(name: "artists")
  }

  override func createParserDelegate() {
    let prefetch = library.getElements(account: account, prefetchIDs: idParserDelegate.prefetchIDs)
    parserDelegate = ArtistParserDelegate(
      performanceMonitor: MOCK_PerformanceMonitor(), prefetch: prefetch, account: account,
      library: library,
      parseNotifier: nil
    )
  }

  override func checkCorrectParsing() {
    prefetchIdTester.checkPrefetchIdCounts(
      artworkCount: 4,
      genreIdCount: 1,
      artistCount: 4
    )

    let artists = library.getArtists(for: account)
    XCTAssertEqual(artists.count, 4)
    XCTAssertEqual(library.getGenreCount(for: account), 1)

    var artist = artists[0]
    XCTAssertEqual(artist.account?.serverHash, TestAccountInfo.test1ServerHash)
    XCTAssertEqual(artist.account?.userHash, TestAccountInfo.test1UserHash)
    XCTAssertEqual(artist.id, "16")
    XCTAssertEqual(artist.name, "CARNÚN")
    XCTAssertEqual(artist.rating, 3)
    XCTAssertEqual(artist.duration, 4282)
    XCTAssertEqual(artist.remoteDuration, 4282)
    XCTAssertEqual(artist.remoteAlbumCount, 1)
    XCTAssertEqual(artist.artwork?.account?.serverHash, TestAccountInfo.test1ServerHash)
    XCTAssertEqual(artist.artwork?.account?.userHash, TestAccountInfo.test1UserHash)
    XCTAssertEqual(artist.artwork?.type, "artist")
    XCTAssertEqual(artist.artwork?.id, "16")

    artist = artists[1]
    XCTAssertEqual(artist.account?.serverHash, TestAccountInfo.test1ServerHash)
    XCTAssertEqual(artist.account?.userHash, TestAccountInfo.test1UserHash)
    XCTAssertEqual(artist.id, "27")
    XCTAssertEqual(artist.name, "Chi.Otic")
    XCTAssertEqual(artist.rating, 0)
    XCTAssertEqual(artist.duration, 433)
    XCTAssertEqual(artist.remoteDuration, 433)
    XCTAssertEqual(artist.remoteAlbumCount, 0)
    XCTAssertEqual(artist.artwork?.account?.serverHash, TestAccountInfo.test1ServerHash)
    XCTAssertEqual(artist.artwork?.account?.userHash, TestAccountInfo.test1UserHash)
    XCTAssertEqual(artist.artwork?.type, "artist")
    XCTAssertEqual(artist.artwork?.id, "27")

    artist = artists[3]
    XCTAssertEqual(artist.account?.serverHash, TestAccountInfo.test1ServerHash)
    XCTAssertEqual(artist.account?.userHash, TestAccountInfo.test1UserHash)
    XCTAssertEqual(artist.id, "13")
    XCTAssertEqual(artist.name, "IOK-1")
    XCTAssertEqual(artist.rating, 5)
    XCTAssertEqual(artist.duration, 3428)
    XCTAssertEqual(artist.remoteDuration, 3428)
    XCTAssertEqual(artist.remoteAlbumCount, 1)
    XCTAssertEqual(artist.artwork?.account?.serverHash, TestAccountInfo.test1ServerHash)
    XCTAssertEqual(artist.artwork?.account?.userHash, TestAccountInfo.test1UserHash)
    XCTAssertEqual(artist.artwork?.type, "artist")
    XCTAssertEqual(artist.artwork?.id, "13")
    XCTAssertEqual(artist.genre?.account?.serverHash, TestAccountInfo.test1ServerHash)
    XCTAssertEqual(artist.genre?.account?.userHash, TestAccountInfo.test1UserHash)
    XCTAssertEqual(artist.genre?.id, "4")
    XCTAssertEqual(artist.genre?.name, "Dark Ambient")
  }
}
