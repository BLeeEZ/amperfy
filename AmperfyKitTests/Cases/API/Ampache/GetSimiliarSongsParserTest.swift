//
//  GetSimiliarSongsParserTest.swift
//  AmperfyKitTests
//
//  Created by Maximilian Bauer on 14.03.26.
//  Copyright (c) 2026 Maximilian Bauer. All rights reserved.
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

class GetSimiliarSongsParserTest: AbstractAmpacheTest {
  override func setUp() async throws {
    try await super.setUp()
    xmlData = getTestFileData(name: "get_similar")
  }

  override func createParserDelegate() {
    let prefetch = library.getElements(account: account, prefetchIDs: idParserDelegate.prefetchIDs)
    parserDelegate = SongParserDelegate(
      performanceMonitor: MOCK_PerformanceMonitor(), prefetch: prefetch, account: account,
      library: library,
      parseNotifier: nil
    )
  }

  override func checkCorrectParsing() {
    prefetchIdTester.checkPrefetchIdCounts(
      artworkCount: 0,
      genreIdCount: 0,
      artistCount: 3,
      albumCount: 3,
      songCount: 5
    )

    let songs = library.getSongs(for: account).sorted(by: { Int($0.id)! < Int($1.id)! })
    XCTAssertEqual(songs.count, 5)

    var song = songs[1]
    XCTAssertEqual(song.account?.serverHash, TestAccountInfo.test1ServerHash)
    XCTAssertEqual(song.account?.userHash, TestAccountInfo.test1UserHash)
    XCTAssertEqual(song.id, "41039")
    XCTAssertEqual(song.title, "Somebody Told Me")
    XCTAssertEqual(song.artist?.account?.serverHash, TestAccountInfo.test1ServerHash)
    XCTAssertEqual(song.artist?.account?.userHash, TestAccountInfo.test1UserHash)
    XCTAssertEqual(song.artist?.id, "2277")
    XCTAssertEqual(song.artist?.name, "The Killers")
    XCTAssertEqual(song.album?.account?.serverHash, TestAccountInfo.test1ServerHash)
    XCTAssertEqual(song.album?.account?.userHash, TestAccountInfo.test1UserHash)
    XCTAssertEqual(song.album?.id, "50260") // Album not pre created
    XCTAssertEqual(song.album?.name, "Hot Fuss")
    XCTAssertNil(song.genre)

    song = songs[4]
    XCTAssertEqual(song.account?.serverHash, TestAccountInfo.test1ServerHash)
    XCTAssertEqual(song.account?.userHash, TestAccountInfo.test1UserHash)
    XCTAssertEqual(song.id, "777754")
    XCTAssertEqual(song.title, "Fluorescent Adolescent")
    XCTAssertEqual(song.artist?.account?.serverHash, TestAccountInfo.test1ServerHash)
    XCTAssertEqual(song.artist?.account?.userHash, TestAccountInfo.test1UserHash)
    XCTAssertEqual(song.artist?.id, "10468")
    XCTAssertEqual(song.artist?.name, "Arctic Monkeys")
    XCTAssertEqual(song.album?.account?.serverHash, TestAccountInfo.test1ServerHash)
    XCTAssertEqual(song.album?.account?.userHash, TestAccountInfo.test1UserHash)
    XCTAssertEqual(song.album?.id, "84543")
    XCTAssertEqual(song.album?.name, "Favourite Worst Nightmare")
  }
}
