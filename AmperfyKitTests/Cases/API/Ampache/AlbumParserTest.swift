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
    recreateParserDelegate()
    createTestArtists()
  }

  override func recreateParserDelegate() {
    parserDelegate = AlbumParserDelegate(
      performanceMonitor: MOCK_PerformanceMonitor(),
      library: library,
      parseNotifier: nil
    )
  }

  func createTestArtists() {
    var artist = library.createArtist()
    artist.id = "19"
    artist.name = "Various Artists"

    artist = library.createArtist()
    artist.id = "91"
    artist.name = "ZZZasdf"
  }

  override func checkCorrectParsing() {
    let albums = library.getAlbums().sorted(by: { $0.id < $1.id })
    XCTAssertEqual(albums.count, 3)
    XCTAssertEqual(library.genreCount, 2)

    var album = albums[0]
    XCTAssertEqual(album.id, "12")
    XCTAssertEqual(album.name, "Buried in Nausea")
    XCTAssertEqual(album.rating, 2)
    XCTAssertEqual(album.artist?.id, "19")
    XCTAssertEqual(album.artist?.name, "Various Artists")
    XCTAssertEqual(album.year, 2012)
    XCTAssertFalse(album.isCached)
    XCTAssertEqual(album.duration, 1879)
    XCTAssertEqual(album.remoteDuration, 1879)
    XCTAssertEqual(album.remoteSongCount, 9)
    XCTAssertEqual(album.genre?.id, "7")
    XCTAssertEqual(album.genre?.name, "Punk")
    XCTAssertEqual(
      album.artwork?.url,
      "https://music.com.au/image.php?object_id=12&object_type=album&auth=eeb9f1b6056246a7d563f479f518bb34"
    )

    album = albums[1]
    XCTAssertEqual(album.id, "98")
    XCTAssertEqual(album.name, "Blibb uu")
    XCTAssertEqual(album.rating, 0)
    XCTAssertEqual(album.artist?.id, "12") // Artist not pre created
    XCTAssertEqual(album.artist?.name, "9958A")
    XCTAssertEqual(album.year, 1974)
    XCTAssertFalse(album.isCached)
    XCTAssertEqual(album.duration, 4621)
    XCTAssertEqual(album.remoteDuration, 4621)
    XCTAssertEqual(album.remoteSongCount, 1)
    XCTAssertNil(album.genre)
    XCTAssertEqual(
      album.artwork?.url,
      "https://music.com.au/image.php?object_id=98&object_type=album&auth=eeb9f1b6056246a7d563f479f518bb34"
    )

    album = albums[2]
    XCTAssertEqual(album.id, "99")
    XCTAssertEqual(album.name, "123 GOo")
    XCTAssertEqual(album.rating, 0)
    XCTAssertEqual(album.artist?.id, "91")
    XCTAssertEqual(album.artist?.name, "ZZZasdf")
    XCTAssertEqual(album.year, 2002)
    XCTAssertFalse(album.isCached)
    XCTAssertEqual(album.duration, 2)
    XCTAssertEqual(album.remoteDuration, 2)
    XCTAssertEqual(album.remoteSongCount, 105)
    XCTAssertEqual(album.genre?.id, "1")
    XCTAssertEqual(album.genre?.name, "Blub")
    XCTAssertEqual(
      album.artwork?.url,
      "https://music.com.au/image.php?object_id=99&object_type=album&auth=eeb9f1b6056246a7d563f479f518bb34"
    )
  }
}
