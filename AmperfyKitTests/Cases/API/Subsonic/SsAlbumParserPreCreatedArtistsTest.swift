//
//  SsAlbumParserPreCreatedArtistsTest.swift
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

class SsAlbumParserPreCreatedArtistsTest: AbstractSsParserTest {
  override func setUp() async throws {
    try await super.setUp()
    xmlData = getTestFileData(name: "artist_example_1")
    ssParserDelegate = SsAlbumParserDelegate(
      performanceMonitor: MOCK_PerformanceMonitor(),
      library: library,
      parseNotifier: nil
    )
    createTestPartner()
  }

  func createTestPartner() {
    let artist = library.createArtist()
    artist.id = "5432"
    artist.name = "AC/DC"
  }

  override func checkCorrectParsing() {
    let albums = library.getAlbums().sorted(by: { Int($0.id)! < Int($1.id)! })
    XCTAssertEqual(albums.count, 15)

    var album = albums[1]
    XCTAssertEqual(album.id, "11047")
    XCTAssertEqual(album.name, "Back In Black")
    XCTAssertEqual(album.artist?.id, "5432")
    XCTAssertEqual(album.artist?.name, "AC/DC")
    XCTAssertEqual(album.year, 0)
    XCTAssertFalse(album.isCached)
    XCTAssertEqual(album.duration, 2534)
    XCTAssertEqual(album.remoteDuration, 2534)
    XCTAssertEqual(album.remoteSongCount, 10)
    XCTAssertNil(album.genre)
    XCTAssertEqual(album.artwork?.url, "")
    XCTAssertEqual(album.artwork?.type, "")
    XCTAssertEqual(album.artwork?.id, "al-11047")

    album = albums[6]
    XCTAssertEqual(album.id, "11052")
    XCTAssertEqual(album.name, "For Those About To Rock")
    XCTAssertEqual(album.artist?.id, "5432")
    XCTAssertEqual(album.artist?.name, "AC/DC")
    XCTAssertEqual(album.year, 0)
    XCTAssertFalse(album.isCached)
    XCTAssertEqual(album.duration, 2403)
    XCTAssertEqual(album.remoteDuration, 2403)
    XCTAssertEqual(album.remoteSongCount, 10)
    XCTAssertNil(album.genre)
    XCTAssertEqual(album.artwork?.url, "")
    XCTAssertEqual(album.artwork?.type, "")
    XCTAssertEqual(album.artwork?.id, "al-11052")

    album = albums[7]
    XCTAssertEqual(album.id, "11053")
    XCTAssertEqual(album.name, "High Voltage")
    XCTAssertEqual(album.artist?.id, "5432")
    XCTAssertEqual(album.artist?.name, "AC/DC")
    XCTAssertEqual(album.year, 0)
    XCTAssertFalse(album.isCached)
    XCTAssertEqual(album.duration, 2414)
    XCTAssertEqual(album.remoteDuration, 2414)
    XCTAssertEqual(album.remoteSongCount, 8)
    XCTAssertNil(album.genre)
    XCTAssertEqual(album.artwork?.url, "")
    XCTAssertEqual(album.artwork?.type, "")
    XCTAssertEqual(album.artwork?.id, "al-11053")

    album = albums[14]
    XCTAssertEqual(album.id, "11061")
    XCTAssertEqual(album.name, "Who Made Who")
    XCTAssertEqual(album.artist?.id, "5432")
    XCTAssertEqual(album.artist?.name, "AC/DC")
    XCTAssertEqual(album.year, 0)
    XCTAssertFalse(album.isCached)
    XCTAssertEqual(album.duration, 2291)
    XCTAssertEqual(album.remoteDuration, 2291)
    XCTAssertEqual(album.remoteSongCount, 9)
    XCTAssertNil(album.genre)
    XCTAssertEqual(album.artwork?.url, "")
    XCTAssertEqual(album.artwork?.type, "")
    XCTAssertEqual(album.artwork?.id, "al-11061")
  }
}
