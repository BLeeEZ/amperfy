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
  }

  override func createParserDelegate() {
    let prefetch = library.getElements(
      account: account,
      prefetchIDs: ssIdParserDelegate.prefetchIDs
    )
    ssParserDelegate = SsSongParserDelegate(
      performanceMonitor: MOCK_PerformanceMonitor(), prefetch: prefetch, account: account,
      library: library,
      parseNotifier: nil
    )
  }

  override func checkCorrectParsing() {
    prefetchIdTester.checkPrefetchIdCounts(
      artworkCount: 2,
      genreNameCount: 1,
      artistCount: 1,
      albumCount: 1,
      songCount: 8,
      artworkFetchCount: 1 // the album cover itself is not created and all songs have the same cover
    )

    let songs = library.getSongs(for: account).sorted(by: { $0.id < $1.id })
    XCTAssertEqual(songs.count, 8)

    let dateFormatter = ISO8601DateFormatter()
    dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

    var song = songs[6]
    XCTAssertEqual(song.account?.serverHash, TestAccountInfo.test1ServerHash)
    XCTAssertEqual(song.account?.userHash, TestAccountInfo.test1UserHash)
    XCTAssertEqual(song.id, "71463")
    XCTAssertEqual(song.title, "The Jack")
    XCTAssertEqual(song.rating, 0)
    XCTAssertEqual(song.artist?.account?.serverHash, TestAccountInfo.test1ServerHash)
    XCTAssertEqual(song.artist?.account?.userHash, TestAccountInfo.test1UserHash)
    XCTAssertEqual(song.artist?.id, "5432")
    XCTAssertEqual(song.artist?.name, "AC/DC")
    XCTAssertEqual(song.album?.account?.serverHash, TestAccountInfo.test1ServerHash)
    XCTAssertEqual(song.album?.account?.userHash, TestAccountInfo.test1UserHash)
    XCTAssertEqual(song.album?.id, "11053")
    XCTAssertEqual(song.album?.name, "High Voltage")
    XCTAssertEqual(song.addedDate, dateFormatter.date(from: "2004-11-08T23:36:11"))
    XCTAssertNil(song.disk)
    XCTAssertEqual(song.track, 0)
    XCTAssertNil(song.genre)
    XCTAssertEqual(song.duration, 352)
    XCTAssertEqual(song.remoteDuration, 352)
    XCTAssertEqual(song.year, 0)
    XCTAssertEqual(song.replayGainAlbumGain, 0.0)
    XCTAssertEqual(song.replayGainAlbumPeak, 0.0)
    XCTAssertEqual(song.replayGainTrackGain, 0.0)
    XCTAssertEqual(song.replayGainTrackPeak, 0.0)
    XCTAssertEqual(song.bitrate, 128000)
    XCTAssertEqual(song.isFavorite, true)
    XCTAssertEqual(song.starredDate, dateFormatter.date(from: "2024-07-21T20:02:24.995815902Z"))
    XCTAssertEqual(song.contentType, "audio/mpeg")
    XCTAssertNil(song.url)
    XCTAssertEqual(song.size, 5624132)
    XCTAssertEqual(song.artwork?.account?.serverHash, TestAccountInfo.test1ServerHash)
    XCTAssertEqual(song.artwork?.account?.userHash, TestAccountInfo.test1UserHash)
    XCTAssertEqual(song.artwork?.type, "")
    XCTAssertEqual(song.artwork?.id, "71381")
    let song1Artwork = song.artwork

    song = songs[1]
    XCTAssertEqual(song.account?.serverHash, TestAccountInfo.test1ServerHash)
    XCTAssertEqual(song.account?.userHash, TestAccountInfo.test1UserHash)
    XCTAssertEqual(song.id, "71458")
    XCTAssertEqual(song.title, "It's A Long Way To The Top")
    XCTAssertEqual(song.rating, 1)
    XCTAssertEqual(song.artist?.account?.serverHash, TestAccountInfo.test1ServerHash)
    XCTAssertEqual(song.artist?.account?.userHash, TestAccountInfo.test1UserHash)
    XCTAssertEqual(song.artist?.id, "5432")
    XCTAssertEqual(song.artist?.name, "AC/DC")
    XCTAssertEqual(song.album?.account?.serverHash, TestAccountInfo.test1ServerHash)
    XCTAssertEqual(song.album?.account?.userHash, TestAccountInfo.test1UserHash)
    XCTAssertEqual(song.album?.id, "11053")
    XCTAssertEqual(song.album?.name, "High Voltage")
    XCTAssertEqual(song.addedDate, dateFormatter.date(from: "2004-11-27T20:23:32"))
    XCTAssertNil(song.disk)
    XCTAssertEqual(song.track, 0)
    XCTAssertEqual(song.genre?.account?.serverHash, TestAccountInfo.test1ServerHash)
    XCTAssertEqual(song.genre?.account?.userHash, TestAccountInfo.test1UserHash)
    XCTAssertEqual(song.genre?.id, "")
    XCTAssertEqual(song.genre?.name, "Rock")
    XCTAssertEqual(song.duration, 315)
    XCTAssertEqual(song.remoteDuration, 315)
    XCTAssertEqual(song.year, 1976)
    //  <replayGain trackGain="0.1" albumGain="2.3" trackPeak="9.1" albumPeak="9" baseGain="4.1">
    XCTAssertEqual(song.replayGainAlbumGain, 2.3)
    XCTAssertEqual(song.replayGainAlbumPeak, 0.0)
    XCTAssertEqual(song.replayGainTrackGain, 0.1)
    XCTAssertEqual(song.replayGainTrackPeak, 9.1)
    XCTAssertEqual(song.bitrate, 128000)
    XCTAssertEqual(song.isFavorite, true)
    XCTAssertEqual(song.starredDate, dateFormatter.date(from: "2022-09-12T13:08:58Z"))
    XCTAssertEqual(song.contentType, "audio/mpeg")
    XCTAssertNil(song.url)
    XCTAssertEqual(song.size, 5037357)
    XCTAssertEqual(song.artwork?.account?.serverHash, TestAccountInfo.test1ServerHash)
    XCTAssertEqual(song.artwork?.account?.userHash, TestAccountInfo.test1UserHash)
    XCTAssertEqual(song.artwork?.type, "")
    XCTAssertEqual(song.artwork?.id, "71381")
    XCTAssertEqual(song.artwork, song1Artwork)

    song = songs[5]
    XCTAssertEqual(song.account?.serverHash, TestAccountInfo.test1ServerHash)
    XCTAssertEqual(song.account?.userHash, TestAccountInfo.test1UserHash)
    XCTAssertEqual(song.id, "71462")
    XCTAssertEqual(song.rating, 5)
    XCTAssertEqual(song.title, "She's Got Balls")
    XCTAssertEqual(song.artist?.account?.serverHash, TestAccountInfo.test1ServerHash)
    XCTAssertEqual(song.artist?.account?.userHash, TestAccountInfo.test1UserHash)
    XCTAssertEqual(song.artist?.id, "5432")
    XCTAssertEqual(song.artist?.name, "AC/DC")
    XCTAssertEqual(song.album?.account?.serverHash, TestAccountInfo.test1ServerHash)
    XCTAssertEqual(song.album?.account?.userHash, TestAccountInfo.test1UserHash)
    XCTAssertEqual(song.album?.id, "11053")
    XCTAssertEqual(song.album?.name, "High Voltage")
    XCTAssertEqual(song.addedDate, dateFormatter.date(from: "2004-11-27T20:23:34"))
    XCTAssertNil(song.disk)
    XCTAssertEqual(song.track, 8)
    XCTAssertEqual(song.genre?.account?.serverHash, TestAccountInfo.test1ServerHash)
    XCTAssertEqual(song.genre?.account?.userHash, TestAccountInfo.test1UserHash)
    XCTAssertEqual(song.genre?.id, "")
    XCTAssertEqual(song.genre?.name, "Rock")
    XCTAssertEqual(song.duration, 290)
    XCTAssertEqual(song.remoteDuration, 290)
    XCTAssertEqual(song.year, 1976)
    XCTAssertEqual(song.replayGainAlbumGain, -5)
    XCTAssertEqual(song.replayGainAlbumPeak, 7.4)
    XCTAssertEqual(song.replayGainTrackGain, -7.1)
    XCTAssertEqual(song.replayGainTrackPeak, 9.1)
    XCTAssertEqual(song.bitrate, 128000)
    XCTAssertEqual(song.isFavorite, false)
    XCTAssertEqual(song.starredDate, nil)
    XCTAssertEqual(song.contentType, "audio/mpeg")
    XCTAssertNil(song.url)
    XCTAssertEqual(song.size, 4651866)
    XCTAssertEqual(song.artwork?.account?.serverHash, TestAccountInfo.test1ServerHash)
    XCTAssertEqual(song.artwork?.account?.userHash, TestAccountInfo.test1UserHash)
    XCTAssertEqual(song.artwork?.type, "")
    XCTAssertEqual(song.artwork?.id, "71381")
    XCTAssertEqual(song.artwork, song1Artwork)
  }
}
