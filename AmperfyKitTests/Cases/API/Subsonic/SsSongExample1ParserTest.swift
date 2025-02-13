//
//  SsSongExample1ParserTest.swift
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

class SsSongExample1ParserTest: AbstractSsParserTest {
  override func setUp() async throws {
    try await super.setUp()
    xmlData = getTestFileData(name: "album_example_1")
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
    let songs = library.getSongs().sorted(by: { $0.id < $1.id })
    XCTAssertEqual(songs.count, 8)

    let dateFormatter = ISO8601DateFormatter()
    dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

    var song = songs[6]
    XCTAssertEqual(song.id, "71463")
    XCTAssertEqual(song.title, "The Jack")
    XCTAssertEqual(song.rating, 0)
    XCTAssertEqual(song.artist?.id, "5432")
    XCTAssertEqual(song.artist?.name, "AC/DC")
    XCTAssertEqual(song.album?.id, "11053")
    XCTAssertEqual(song.album?.name, "High Voltage")
    XCTAssertNil(song.disk)
    XCTAssertEqual(song.track, 0)
    XCTAssertNil(song.genre)
    XCTAssertEqual(song.duration, 352)
    XCTAssertEqual(song.remoteDuration, 352)
    XCTAssertEqual(song.year, 0)
    XCTAssertEqual(song.bitrate, 128000)
    XCTAssertEqual(song.isFavorite, true)
    XCTAssertEqual(song.starredDate, dateFormatter.date(from: "2024-07-21T20:02:24.995815902Z"))
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
    XCTAssertEqual(song.rating, 1)
    XCTAssertEqual(song.artist?.id, "5432")
    XCTAssertEqual(song.artist?.name, "AC/DC")
    XCTAssertEqual(song.album?.id, "11053")
    XCTAssertEqual(song.album?.name, "High Voltage")
    XCTAssertNil(song.disk)
    XCTAssertEqual(song.track, 0)
    XCTAssertEqual(song.genre?.id, "")
    XCTAssertEqual(song.genre?.name, "Rock")
    XCTAssertEqual(song.duration, 315)
    XCTAssertEqual(song.remoteDuration, 315)
    XCTAssertEqual(song.year, 1976)
    XCTAssertEqual(song.bitrate, 128000)
    XCTAssertEqual(song.isFavorite, true)
    XCTAssertEqual(song.starredDate, dateFormatter.date(from: "2022-09-12T13:08:58Z"))
    XCTAssertEqual(song.contentType, "audio/mpeg")
    XCTAssertNil(song.url)
    XCTAssertEqual(song.size, 5037357)
    XCTAssertEqual(song.artwork?.url, "")
    XCTAssertEqual(song.artwork?.type, "")
    XCTAssertEqual(song.artwork?.id, "71381")
    XCTAssertEqual(song.artwork, song1Artwork)

    song = songs[5]
    XCTAssertEqual(song.id, "71462")
    XCTAssertEqual(song.rating, 5)
    XCTAssertEqual(song.title, "She's Got Balls")
    XCTAssertEqual(song.artist?.id, "5432")
    XCTAssertEqual(song.artist?.name, "AC/DC")
    XCTAssertEqual(song.album?.id, "11053")
    XCTAssertEqual(song.album?.name, "High Voltage")
    XCTAssertNil(song.disk)
    XCTAssertEqual(song.track, 8)
    XCTAssertEqual(song.genre?.id, "")
    XCTAssertEqual(song.genre?.name, "Rock")
    XCTAssertEqual(song.duration, 290)
    XCTAssertEqual(song.remoteDuration, 290)
    XCTAssertEqual(song.year, 1976)
    XCTAssertEqual(song.bitrate, 128000)
    XCTAssertEqual(song.isFavorite, false)
    XCTAssertEqual(song.starredDate, nil)
    XCTAssertEqual(song.contentType, "audio/mpeg")
    XCTAssertNil(song.url)
    XCTAssertEqual(song.size, 4651866)
    XCTAssertEqual(song.artwork?.url, "")
    XCTAssertEqual(song.artwork?.type, "")
    XCTAssertEqual(song.artwork?.id, "71381")
    XCTAssertEqual(song.artwork, song1Artwork)
  }
}
