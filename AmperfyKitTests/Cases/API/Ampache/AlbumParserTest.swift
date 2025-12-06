//
//  AlbumParserTest.swift
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

class AlbumParserTest: AbstractAmpacheTest {
  override func setUp() async throws {
    try await super.setUp()
    xmlData = getTestFileData(name: "albums")
  }

  override func createParserDelegate() {
    let prefetch = library.getElements(account: account, prefetchIDs: idParserDelegate.prefetchIDs)
    parserDelegate = AlbumParserDelegate(
      performanceMonitor: MOCK_PerformanceMonitor(), prefetch: prefetch, account: account,
      library: library,
      parseNotifier: nil
    )
  }

  override func checkCorrectParsing() {
    prefetchIdTester.checkPrefetchIdCounts(
      artworkCount: 3,
      genreIdCount: 2,
      artistCount: 3,
      albumCount: 3
    )

    let albums = library.getAlbums(for: account).sorted(by: { $0.id < $1.id })
    XCTAssertEqual(albums.count, 3)
    XCTAssertEqual(library.getGenreCount(for: account), 2)

    var album = albums[0]
    XCTAssertEqual(album.account?.serverHash, TestAccountInfo.test1ServerHash)
    XCTAssertEqual(album.account?.userHash, TestAccountInfo.test1UserHash)
    XCTAssertEqual(album.id, "12")
    XCTAssertEqual(album.name, "Buried in Nausea")
    XCTAssertEqual(album.rating, 2)
    XCTAssertEqual(album.artist?.account?.serverHash, TestAccountInfo.test1ServerHash)
    XCTAssertEqual(album.artist?.account?.userHash, TestAccountInfo.test1UserHash)
    XCTAssertEqual(album.artist?.id, "19")
    XCTAssertEqual(album.artist?.name, "Various Artists")
    XCTAssertEqual(album.year, 2012)
    XCTAssertFalse(album.isCached)
    XCTAssertEqual(album.duration, 1879)
    XCTAssertEqual(album.remoteDuration, 1879)
    XCTAssertEqual(album.remoteSongCount, 9)
    XCTAssertEqual(album.genre?.account?.serverHash, TestAccountInfo.test1ServerHash)
    XCTAssertEqual(album.genre?.account?.userHash, TestAccountInfo.test1UserHash)
    XCTAssertEqual(album.genre?.id, "7")
    XCTAssertEqual(album.genre?.name, "Punk")
    XCTAssertEqual(album.artwork?.account?.serverHash, TestAccountInfo.test1ServerHash)
    XCTAssertEqual(album.artwork?.account?.userHash, TestAccountInfo.test1UserHash)
    XCTAssertEqual(album.artwork?.id, "12")
    XCTAssertEqual(album.artwork?.type, "album")

    album = albums[1]
    XCTAssertEqual(album.account?.serverHash, TestAccountInfo.test1ServerHash)
    XCTAssertEqual(album.account?.userHash, TestAccountInfo.test1UserHash)
    XCTAssertEqual(album.id, "98")
    XCTAssertEqual(album.name, "Blibb uu")
    XCTAssertEqual(album.rating, 0)
    XCTAssertEqual(album.artist?.account?.serverHash, TestAccountInfo.test1ServerHash)
    XCTAssertEqual(album.artist?.account?.userHash, TestAccountInfo.test1UserHash)
    XCTAssertEqual(album.artist?.id, "12") // Artist not pre created
    XCTAssertEqual(album.artist?.name, "9958A")
    XCTAssertEqual(album.year, 1974)
    XCTAssertFalse(album.isCached)
    XCTAssertEqual(album.duration, 4621)
    XCTAssertEqual(album.remoteDuration, 4621)
    XCTAssertEqual(album.remoteSongCount, 1)
    XCTAssertNil(album.genre)
    XCTAssertEqual(album.artwork?.account?.serverHash, TestAccountInfo.test1ServerHash)
    XCTAssertEqual(album.artwork?.account?.userHash, TestAccountInfo.test1UserHash)
    XCTAssertEqual(album.artwork?.id, "98")
    XCTAssertEqual(album.artwork?.type, "album")

    album = albums[2]
    XCTAssertEqual(album.account?.serverHash, TestAccountInfo.test1ServerHash)
    XCTAssertEqual(album.account?.userHash, TestAccountInfo.test1UserHash)
    XCTAssertEqual(album.id, "99")
    XCTAssertEqual(album.name, "123 GOo")
    XCTAssertEqual(album.rating, 0)
    XCTAssertEqual(album.artist?.account?.serverHash, TestAccountInfo.test1ServerHash)
    XCTAssertEqual(album.artist?.account?.userHash, TestAccountInfo.test1UserHash)
    XCTAssertEqual(album.artist?.id, "91")
    XCTAssertEqual(album.artist?.name, "ZZZasdf")
    XCTAssertEqual(album.year, 2002)
    XCTAssertFalse(album.isCached)
    XCTAssertEqual(album.duration, 2)
    XCTAssertEqual(album.remoteDuration, 2)
    XCTAssertEqual(album.remoteSongCount, 105)
    XCTAssertEqual(album.genre?.account?.serverHash, TestAccountInfo.test1ServerHash)
    XCTAssertEqual(album.genre?.account?.userHash, TestAccountInfo.test1UserHash)
    XCTAssertEqual(album.genre?.id, "1")
    XCTAssertEqual(album.genre?.name, "Blub")
    XCTAssertEqual(album.artwork?.account?.serverHash, TestAccountInfo.test1ServerHash)
    XCTAssertEqual(album.artwork?.account?.userHash, TestAccountInfo.test1UserHash)
    XCTAssertEqual(album.artwork?.id, "99")
    XCTAssertEqual(album.artwork?.type, "album")
  }
}
