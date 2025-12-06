//
//  SsArtistParserTest.swift
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

class SsArtistParserTest: AbstractSsParserTest {
  override func setUp() async throws {
    try await super.setUp()
    xmlData = getTestFileData(name: "artists_example_1")
  }

  override func createParserDelegate() {
    let prefetch = library.getElements(
      account: account,
      prefetchIDs: ssIdParserDelegate.prefetchIDs
    )
    ssParserDelegate = SsArtistParserDelegate(
      performanceMonitor: MOCK_PerformanceMonitor(), prefetch: prefetch, account: account,
      library: library,
      parseNotifier: nil
    )
  }

  override func checkCorrectParsing() {
    prefetchIdTester.checkPrefetchIdCounts(
      artworkCount: 6,
      artistCount: 6
    )

    let artists = library.getArtists(for: account).sorted(by: { Int($0.id)! < Int($1.id)! })
    XCTAssertEqual(artists.count, 6)

    var artist = artists[0]
    XCTAssertEqual(artist.account?.serverHash, TestAccountInfo.test1ServerHash)
    XCTAssertEqual(artist.account?.userHash, TestAccountInfo.test1UserHash)
    XCTAssertEqual(artist.id, "5421")
    XCTAssertEqual(artist.name, "ABBA")
    XCTAssertEqual(artist.rating, 3)
    XCTAssertEqual(artist.duration, 0)
    XCTAssertEqual(artist.remoteDuration, 0)
    XCTAssertEqual(artist.remoteAlbumCount, 6)
    XCTAssertEqual(artist.artwork?.account?.serverHash, TestAccountInfo.test1ServerHash)
    XCTAssertEqual(artist.artwork?.account?.userHash, TestAccountInfo.test1UserHash)
    XCTAssertEqual(artist.artwork?.type, "")
    XCTAssertEqual(artist.artwork?.id, "ar-5421")

    artist = artists[1]
    XCTAssertEqual(artist.account?.serverHash, TestAccountInfo.test1ServerHash)
    XCTAssertEqual(artist.account?.userHash, TestAccountInfo.test1UserHash)
    XCTAssertEqual(artist.id, "5432")
    XCTAssertEqual(artist.name, "AC/DC")
    XCTAssertEqual(artist.rating, 0)
    XCTAssertEqual(artist.duration, 0)
    XCTAssertEqual(artist.remoteDuration, 0)
    XCTAssertEqual(artist.remoteAlbumCount, 15)
    XCTAssertEqual(artist.artwork?.account?.serverHash, TestAccountInfo.test1ServerHash)
    XCTAssertEqual(artist.artwork?.account?.userHash, TestAccountInfo.test1UserHash)
    XCTAssertEqual(artist.artwork?.type, "")
    XCTAssertEqual(artist.artwork?.id, "ar-5432")

    artist = artists[2]
    XCTAssertEqual(artist.account?.serverHash, TestAccountInfo.test1ServerHash)
    XCTAssertEqual(artist.account?.userHash, TestAccountInfo.test1UserHash)
    XCTAssertEqual(artist.id, "5449")
    XCTAssertEqual(artist.name, "A-Ha")
    XCTAssertEqual(artist.rating, 0)
    XCTAssertEqual(artist.duration, 0)
    XCTAssertEqual(artist.remoteDuration, 0)
    XCTAssertEqual(artist.remoteAlbumCount, 4)
    XCTAssertEqual(artist.artwork?.account?.serverHash, TestAccountInfo.test1ServerHash)
    XCTAssertEqual(artist.artwork?.account?.userHash, TestAccountInfo.test1UserHash)
    XCTAssertEqual(artist.artwork?.type, "")
    XCTAssertEqual(artist.artwork?.id, "ar-5449")

    artist = artists[3]
    XCTAssertEqual(artist.account?.serverHash, TestAccountInfo.test1ServerHash)
    XCTAssertEqual(artist.account?.userHash, TestAccountInfo.test1UserHash)
    XCTAssertEqual(artist.id, "5950")
    XCTAssertEqual(artist.name, "Bob Marley")
    XCTAssertEqual(artist.rating, 0)
    XCTAssertEqual(artist.duration, 0)
    XCTAssertEqual(artist.remoteDuration, 0)
    XCTAssertEqual(artist.remoteAlbumCount, 8)
    XCTAssertEqual(artist.artwork?.account?.serverHash, TestAccountInfo.test1ServerHash)
    XCTAssertEqual(artist.artwork?.account?.userHash, TestAccountInfo.test1UserHash)
    XCTAssertEqual(artist.artwork?.type, "")
    XCTAssertEqual(artist.artwork?.id, "ar-5950")

    artist = artists[4]
    XCTAssertEqual(artist.account?.serverHash, TestAccountInfo.test1ServerHash)
    XCTAssertEqual(artist.account?.userHash, TestAccountInfo.test1UserHash)
    XCTAssertEqual(artist.id, "5957")
    XCTAssertEqual(artist.name, "Bruce Dickinson")
    XCTAssertEqual(artist.rating, 0)
    XCTAssertEqual(artist.duration, 0)
    XCTAssertEqual(artist.remoteDuration, 0)
    XCTAssertEqual(artist.remoteAlbumCount, 2)
    XCTAssertEqual(artist.artwork?.account?.serverHash, TestAccountInfo.test1ServerHash)
    XCTAssertEqual(artist.artwork?.account?.userHash, TestAccountInfo.test1UserHash)
    XCTAssertEqual(artist.artwork?.type, "")
    XCTAssertEqual(artist.artwork?.id, "ar-5957")

    artist = artists[5]
    XCTAssertEqual(artist.account?.serverHash, TestAccountInfo.test1ServerHash)
    XCTAssertEqual(artist.account?.userHash, TestAccountInfo.test1UserHash)
    XCTAssertEqual(artist.id, "6633")
    XCTAssertEqual(artist.name, "Aaron Neville")
    XCTAssertEqual(artist.rating, 5)
    XCTAssertEqual(artist.duration, 0)
    XCTAssertEqual(artist.remoteDuration, 0)
    XCTAssertEqual(artist.remoteAlbumCount, 1)
    XCTAssertEqual(artist.artwork?.account?.serverHash, TestAccountInfo.test1ServerHash)
    XCTAssertEqual(artist.artwork?.account?.userHash, TestAccountInfo.test1UserHash)
    XCTAssertEqual(artist.artwork?.type, "")
    XCTAssertEqual(artist.artwork?.id, "ar-6633")
  }
}
