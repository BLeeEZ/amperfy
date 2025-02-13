//
//  SsSongExample2ParserTest.swift
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

class SsSongExample2ParserTest: AbstractSsParserTest {
  override func setUp() async throws {
    try await super.setUp()
    xmlData = getTestFileData(name: "album_example_2")
    ssParserDelegate = SsSongParserDelegate(
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

    let album = library.createAlbum()
    album.id = "11053"
    album.name = "High Voltage"
    album.artwork?.url = "al-11053"
  }

  override func checkCorrectParsing() {
    let songs = library.getSongs().sorted(by: { $0.id > $1.id })
    XCTAssertEqual(songs.count, 2)

    var song = songs[0]
    XCTAssertEqual(song.id, "71463")
    XCTAssertEqual(song.title, "The Jack")
    XCTAssertEqual(song.artist?.id, "5432")
    XCTAssertEqual(song.artist?.name, "AC/DC")
    XCTAssertNil(song.album)
    XCTAssertNil(song.disk)
    XCTAssertEqual(song.track, 0)
    XCTAssertNil(song.genre)
    XCTAssertEqual(song.duration, 352)
    XCTAssertEqual(song.remoteDuration, 352)
    XCTAssertEqual(song.year, 0)
    XCTAssertEqual(song.bitrate, 128000)
    XCTAssertEqual(song.contentType, "audio/mpeg")
    XCTAssertNil(song.url)
    XCTAssertEqual(song.size, 5624132)
    XCTAssertEqual(song.artwork?.url, "")
    XCTAssertEqual(song.artwork?.type, "")
    XCTAssertEqual(song.artwork?.id, "71381")
    let song1Artwork = song.artwork

    song = songs[1]
    XCTAssertEqual(song.id, "71458")
    XCTAssertEqual(song.title, "It's A Long Way To The Top")
    XCTAssertEqual(song.artist?.id, "5432")
    XCTAssertEqual(song.artist?.name, "AC/DC")
    XCTAssertNil(song.album)
    XCTAssertNil(song.disk)
    XCTAssertEqual(song.track, 0)
    XCTAssertEqual(song.genre?.id, "")
    XCTAssertEqual(song.genre?.name, "Rock")
    XCTAssertEqual(song.duration, 315)
    XCTAssertEqual(song.remoteDuration, 315)
    XCTAssertEqual(song.year, 1976)
    XCTAssertEqual(song.bitrate, 128000)
    XCTAssertEqual(song.contentType, "audio/mpeg")
    XCTAssertNil(song.url)
    XCTAssertEqual(song.size, 5037357)
    XCTAssertEqual(song.artwork?.url, "")
    XCTAssertEqual(song.artwork?.type, "")
    XCTAssertEqual(song.artwork?.id, "71381")
    XCTAssertEqual(song.artwork, song1Artwork)
  }
}
