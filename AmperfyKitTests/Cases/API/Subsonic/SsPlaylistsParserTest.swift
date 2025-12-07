//
//  SsPlaylistsParserTest.swift
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

class SsPlaylistsParserTest: AbstractSsParserTest {
  override func setUp() async throws {
    try await super.setUp()
    xmlData = getTestFileData(name: "playlists_example_1")
  }

  override func createParserDelegate() {
    ssParserDelegate = SsPlaylistParserDelegate(
      performanceMonitor: MOCK_PerformanceMonitor(), account: account,
      library: library
    )
  }

  func testLibraryContainsBeforeMorePlaylistsThenAfter() {
    for i in 20 ... 30 {
      let playlist = library.createPlaylist(account: account)
      playlist.id = i.description
      playlist.name = i.description
    }
    testParsing()
  }

  override func checkCorrectParsing() {
    let playlists = library.getPlaylists(for: account)
    XCTAssertEqual(playlists.count, 2)

    var playlist = playlists[1]
    XCTAssertEqual(playlist.account?.serverHash, TestAccountInfo.test1ServerHash)
    XCTAssertEqual(playlist.account?.userHash, TestAccountInfo.test1UserHash)
    XCTAssertEqual(playlist.id, "15")
    XCTAssertEqual(playlist.name, "Some random songs")
    XCTAssertEqual(playlist.songCount, 6)
    XCTAssertEqual(playlist.remoteSongCount, 6)
    XCTAssertEqual(playlist.duration, 1391)
    XCTAssertEqual(playlist.remoteDuration, 1391)
    XCTAssertFalse(playlist.isCached)

    playlist = playlists[0]
    XCTAssertEqual(playlist.account?.serverHash, TestAccountInfo.test1ServerHash)
    XCTAssertEqual(playlist.account?.userHash, TestAccountInfo.test1UserHash)
    XCTAssertEqual(playlist.id, "16")
    XCTAssertEqual(playlist.name, "More random songs")
    XCTAssertEqual(playlist.songCount, 5)
    XCTAssertEqual(playlist.remoteSongCount, 5)
    XCTAssertEqual(playlist.duration, 1018)
    XCTAssertEqual(playlist.remoteDuration, 1018)
    XCTAssertFalse(playlist.isCached)
  }
}
