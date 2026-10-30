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

// MARK: - PlaylistsParserTest

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

  private static let customArtURL =
    "http://localhost:8090/image.php?object_id=2&object_type=playlist&id=6&name=art.jpg"
  private static let blankArtURL = "http://localhost:8090/images/blankalbum.png"

  /// Parses a playlists response (as sent by Ampache 7) with the given art info
  private func parsePlaylist(art: String?, hasArt: String?) -> Playlist? {
    let xml = """
    <?xml version="1.0" encoding="UTF-8"?>
    <root>
      <total_count>1</total_count>
      <playlist id="2">
        <name><![CDATA[WithCover]]></name>
        <items>2</items>
        <type>public</type>
        \(art.map { "<art><![CDATA[\($0)]]></art>" } ?? "")
        <has_access>1</has_access>
        \(hasArt.map { "<has_art>\($0)</has_art>" } ?? "")
        <last_update>1793354119</last_update>
      </playlist>
    </root>
    """
    createParserDelegate()
    let parser = XMLParser(data: xml.data(using: .utf8)!)
    parser.delegate = parserDelegate
    parser.parse()
    return library.getPlaylists(for: account).first { $0.id == "2" }
  }

  func testServerCover() {
    let playlist = parsePlaylist(art: Self.customArtURL, hasArt: "1")
    XCTAssertEqual(playlist?.artwork?.remoteInfo, ArtworkRemoteInfo(id: "2", type: "playlist"))
    XCTAssertEqual(playlist?.artwork?.status, .NotChecked)
  }

  func testNoServerCover() {
    XCTAssertNil(parsePlaylist(art: Self.blankArtURL, hasArt: "0")?.artwork)
  }

  func testRemovedServerCover() {
    XCTAssertNotNil(parsePlaylist(art: Self.customArtURL, hasArt: "1")?.artwork)
    XCTAssertNil(parsePlaylist(art: Self.blankArtURL, hasArt: "0")?.artwork)
  }

  func testArtURLWithoutHasArt() {
    // older servers send no has_art
    XCTAssertNotNil(parsePlaylist(art: Self.customArtURL, hasArt: nil)?.artwork)
    XCTAssertNil(parsePlaylist(art: Self.blankArtURL, hasArt: nil)?.artwork)
  }

  func testHasArtZeroWinsOverArtURL() {
    XCTAssertNil(parsePlaylist(art: Self.customArtURL, hasArt: "0")?.artwork)
  }

  func testResponseWithoutArtInfoKeepsServerCover() {
    XCTAssertNotNil(parsePlaylist(art: Self.customArtURL, hasArt: "1")?.artwork)
    XCTAssertNotNil(parsePlaylist(art: nil, hasArt: nil)?.artwork)
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

// MARK: - AmpacheLivePlaylistCoverTest
