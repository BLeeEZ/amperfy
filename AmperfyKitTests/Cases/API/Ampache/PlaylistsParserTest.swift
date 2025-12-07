//
//  PlaylistsParserTest.swift
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

class PlaylistsParserTest: AbstractAmpacheTest {
  override func setUp() async throws {
    try await super.setUp()
    xmlData = getTestFileData(name: "playlists")
  }

  override func createParserDelegate() {
    parserDelegate = PlaylistParserDelegate(
      performanceMonitor: MOCK_PerformanceMonitor(), account: account,
      library: library,
      parseNotifier: nil
    )
  }

  func testLibraryContainsBeforeMorePlaylistsThenAfter() {
    for i in 10 ... 20 {
      let playlist = library.createPlaylist(account: account)
      playlist.id = i.description
      playlist.name = i.description
    }
    testParsing()
  }

  override func checkCorrectParsing() {
    let playlists = library.getPlaylists(for: account)
    XCTAssertEqual(playlists.count, 4)

    var playlist = playlists[0]
    XCTAssertEqual(playlist.account?.serverHash, TestAccountInfo.test1ServerHash)
    XCTAssertEqual(playlist.account?.userHash, TestAccountInfo.test1UserHash)
    XCTAssertEqual(playlist.id, "smart_21")
    XCTAssertEqual(playlist.name, "admin - 02/23/2021 14:36:44")
    XCTAssertEqual(playlist.songCount, 5000)
    XCTAssertEqual(playlist.remoteSongCount, 5000)
    XCTAssertFalse(playlist.isCached)
    XCTAssertEqual(playlist.duration, 0)
    XCTAssertEqual(playlist.remoteDuration, 0)

    playlist = playlists[1]
    XCTAssertEqual(playlist.account?.serverHash, TestAccountInfo.test1ServerHash)
    XCTAssertEqual(playlist.account?.userHash, TestAccountInfo.test1UserHash)
    XCTAssertEqual(playlist.id, "smart_14")
    XCTAssertEqual(playlist.name, "Album 1*")
    XCTAssertEqual(playlist.songCount, 2)
    XCTAssertEqual(playlist.remoteSongCount, 2)
    XCTAssertFalse(playlist.isCached)
    XCTAssertEqual(playlist.duration, 0)
    XCTAssertEqual(playlist.remoteDuration, 0)

    playlist = playlists[2]
    XCTAssertEqual(playlist.account?.serverHash, TestAccountInfo.test1ServerHash)
    XCTAssertEqual(playlist.account?.userHash, TestAccountInfo.test1UserHash)
    XCTAssertEqual(playlist.id, "3")
    XCTAssertEqual(playlist.name, "random - admin - private")
    XCTAssertEqual(playlist.songCount, 43)
    XCTAssertEqual(playlist.remoteSongCount, 43)
    XCTAssertFalse(playlist.isCached)
    XCTAssertEqual(playlist.duration, 0)
    XCTAssertEqual(playlist.remoteDuration, 0)

    playlist = playlists[3]
    XCTAssertEqual(playlist.account?.serverHash, TestAccountInfo.test1ServerHash)
    XCTAssertEqual(playlist.account?.userHash, TestAccountInfo.test1UserHash)
    XCTAssertEqual(playlist.id, "2")
    XCTAssertEqual(playlist.name, "random - admin - public")
    XCTAssertEqual(playlist.songCount, 43)
    XCTAssertEqual(playlist.remoteSongCount, 43)
    XCTAssertFalse(playlist.isCached)
    XCTAssertEqual(playlist.duration, 0)
    XCTAssertEqual(playlist.remoteDuration, 0)
  }
}
