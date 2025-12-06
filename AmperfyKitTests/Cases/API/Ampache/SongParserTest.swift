//
//  SongParserTest.swift
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

class SongParserTest: AbstractAmpacheTest {
  override func setUp() async throws {
    try await super.setUp()
    xmlData = getTestFileData(name: "songs")
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
      artworkCount: 3,
      genreIdCount: 4,
      artistCount: 4,
      albumCount: 2,
      songCount: 4
    )

    let songs = library.getSongs(for: account)
    XCTAssertEqual(songs.count, 4)
    XCTAssertEqual(library.getGenreCount(for: account), 4)

    var song = songs[0]
    XCTAssertEqual(song.account?.serverHash, TestAccountInfo.test1ServerHash)
    XCTAssertEqual(song.account?.userHash, TestAccountInfo.test1UserHash)
    XCTAssertEqual(song.id, "115")
    XCTAssertEqual(song.title, "Are we going Crazy")
    XCTAssertEqual(song.artist?.account?.serverHash, TestAccountInfo.test1ServerHash)
    XCTAssertEqual(song.artist?.account?.userHash, TestAccountInfo.test1UserHash)
    XCTAssertEqual(song.artist?.id, "27")
    XCTAssertEqual(song.artist?.name, "Chi.Otic")
    XCTAssertEqual(song.album?.account?.serverHash, TestAccountInfo.test1ServerHash)
    XCTAssertEqual(song.album?.account?.userHash, TestAccountInfo.test1UserHash)
    XCTAssertEqual(song.album?.id, "12") // Album not pre created
    XCTAssertEqual(song.album?.name, "Buried in Nausea")
    XCTAssertEqual(song.disk, "1")
    XCTAssertEqual(song.track, 7)
    XCTAssertNil(song.genre)
    XCTAssertEqual(song.duration, 433)
    XCTAssertEqual(song.remoteDuration, 433)
    XCTAssertEqual(song.year, 2012)
    XCTAssertEqual(song.replayGainAlbumGain, 0.0)
    XCTAssertEqual(song.replayGainAlbumPeak, 0.0)
    XCTAssertEqual(song.replayGainTrackGain, 0.0)
    XCTAssertEqual(song.replayGainTrackPeak, 0.0)
    XCTAssertEqual(song.bitrate, 32582)
    XCTAssertEqual(song.contentType, "audio/x-ms-wma")
    XCTAssertEqual(
      song.url,
      "https://music.com.au/play/index.php?ssid=cfj3f237d563f479f5223k23189dbb34&type=song&oid=115&uid=4&player=api&name=Chi.Otic%20-%20Are%20we%20going%20Crazy.wma"
    )
    XCTAssertEqual(song.size, 1776580)
    XCTAssertEqual(song.artwork?.account?.serverHash, TestAccountInfo.test1ServerHash)
    XCTAssertEqual(song.artwork?.account?.userHash, TestAccountInfo.test1UserHash)
    XCTAssertEqual(song.artwork?.type, "album")
    XCTAssertEqual(song.artwork?.id, "12")
    let song1Artwork = song.artwork

    song = songs[1]
    XCTAssertEqual(song.account?.serverHash, TestAccountInfo.test1ServerHash)
    XCTAssertEqual(song.account?.userHash, TestAccountInfo.test1UserHash)
    XCTAssertEqual(song.id, "107")
    XCTAssertEqual(song.title, "Arrest Me")
    XCTAssertEqual(song.rating, 2)
    XCTAssertEqual(song.artist?.account?.serverHash, TestAccountInfo.test1ServerHash)
    XCTAssertEqual(song.artist?.account?.userHash, TestAccountInfo.test1UserHash)
    XCTAssertEqual(song.artist?.id, "20")
    XCTAssertEqual(song.artist?.name, "R/B")
    XCTAssertEqual(song.album?.account?.serverHash, TestAccountInfo.test1ServerHash)
    XCTAssertEqual(song.album?.account?.userHash, TestAccountInfo.test1UserHash)
    XCTAssertEqual(song.album?.id, "12")
    XCTAssertEqual(song.album?.name, "Buried in Nausea")
    XCTAssertNil(song.addedDate)
    XCTAssertEqual(song.disk, "1")
    XCTAssertEqual(song.track, 9)
    XCTAssertEqual(song.genre?.id, "7")
    XCTAssertEqual(song.genre?.name, "Punk")
    XCTAssertEqual(song.duration, 96)
    XCTAssertEqual(song.remoteDuration, 96)
    XCTAssertEqual(song.year, 2012)
    XCTAssertEqual(song.replayGainAlbumGain, 0.0)
    XCTAssertEqual(song.replayGainAlbumPeak, 0.0)
    XCTAssertEqual(song.replayGainTrackGain, -1.35)
    XCTAssertEqual(song.replayGainTrackPeak, 0.881)
    XCTAssertEqual(song.bitrate, 252864)
    XCTAssertEqual(song.contentType, "audio/mp4")
    XCTAssertEqual(
      song.url,
      "https://music.com.au/play/index.php?ssid=cfj3f237d563f479f5223k23189dbb34&type=song&oid=107&uid=4&player=api&name=R-B%20-%20Arrest%20Me.m4a"
    )
    XCTAssertEqual(song.size, 3091727)
    XCTAssertEqual(song.artwork?.account?.serverHash, TestAccountInfo.test1ServerHash)
    XCTAssertEqual(song.artwork?.account?.userHash, TestAccountInfo.test1UserHash)
    XCTAssertEqual(song.artwork?.type, "album")
    XCTAssertEqual(song.artwork?.id, "12")
    XCTAssertEqual(song.artwork, song1Artwork)

    song = songs[2]
    XCTAssertEqual(song.account?.serverHash, TestAccountInfo.test1ServerHash)
    XCTAssertEqual(song.account?.userHash, TestAccountInfo.test1UserHash)
    XCTAssertEqual(song.id, "85")
    XCTAssertEqual(song.title, "Beq Ultra Fat")
    XCTAssertEqual(song.rating, 1)
    XCTAssertEqual(song.artist?.account?.serverHash, TestAccountInfo.test1ServerHash)
    XCTAssertEqual(song.artist?.account?.userHash, TestAccountInfo.test1UserHash)
    XCTAssertEqual(song.artist?.id, "14")
    XCTAssertEqual(song.artist?.name, "Nofi/found.")
    XCTAssertNil(song.album)
    XCTAssertNil(song.addedDate)
    XCTAssertEqual(song.disk, "1")
    XCTAssertEqual(song.track, 4)
    XCTAssertEqual(song.genre?.id, "6")
    XCTAssertEqual(song.genre?.name, "Dance")
    XCTAssertEqual(song.duration, 413)
    XCTAssertEqual(song.remoteDuration, 413)
    XCTAssertEqual(song.year, 0)
    XCTAssertEqual(song.replayGainAlbumGain, -1.334)
    XCTAssertEqual(song.replayGainAlbumPeak, 7.91)
    XCTAssertEqual(song.replayGainTrackGain, 0.94)
    XCTAssertEqual(song.replayGainTrackPeak, 0.989)
    XCTAssertEqual(song.bitrate, 192000)
    XCTAssertEqual(song.contentType, "audio/mpeg")
    XCTAssertEqual(
      song.url,
      "https://music.com.au/play/index.php?ssid=cfj3f237d563f479f5223k23189dbb34&type=song&oid=85&uid=4&player=api&name=Nofi-found.%20-%20Beq%20Ultra%20Fat.mp3"
    )
    XCTAssertEqual(song.size, 9935896)
    XCTAssertEqual(song.artwork?.account?.serverHash, TestAccountInfo.test1ServerHash)
    XCTAssertEqual(song.artwork?.account?.userHash, TestAccountInfo.test1UserHash)
    XCTAssertEqual(song.artwork?.type, "album")
    XCTAssertEqual(song.artwork?.id, "8")

    song = songs[3]
    XCTAssertEqual(song.account?.serverHash, TestAccountInfo.test1ServerHash)
    XCTAssertEqual(song.account?.userHash, TestAccountInfo.test1UserHash)
    XCTAssertEqual(song.id, "56")
    XCTAssertEqual(song.title, "Black&BlueSmoke")
    XCTAssertEqual(song.rating, 0)
    XCTAssertEqual(song.artist?.account?.serverHash, TestAccountInfo.test1ServerHash)
    XCTAssertEqual(song.artist?.account?.userHash, TestAccountInfo.test1UserHash)
    XCTAssertEqual(song.artist?.id, "2") // Artist not pre created
    XCTAssertEqual(song.artist?.name, "Synthetic")
    XCTAssertEqual(song.album?.account?.serverHash, TestAccountInfo.test1ServerHash)
    XCTAssertEqual(song.album?.account?.userHash, TestAccountInfo.test1UserHash)
    XCTAssertEqual(song.album?.id, "2")
    XCTAssertEqual(song.album?.name, "Colorsmoke EP")
    XCTAssertNil(song.addedDate)
    XCTAssertEqual(song.disk, "1")
    XCTAssertEqual(song.track, 1)
    XCTAssertEqual(song.genre?.account?.serverHash, TestAccountInfo.test1ServerHash)
    XCTAssertEqual(song.genre?.account?.userHash, TestAccountInfo.test1UserHash)
    XCTAssertEqual(song.genre?.id, "1")
    XCTAssertEqual(song.genre?.name, "Electronic")
    XCTAssertEqual(song.duration, 500)
    XCTAssertEqual(song.remoteDuration, 500)
    XCTAssertEqual(song.year, 2007)
    XCTAssertEqual(song.replayGainAlbumGain, 9.334)
    XCTAssertEqual(song.replayGainAlbumPeak, 0.0)
    XCTAssertEqual(song.replayGainTrackGain, -5.11)
    XCTAssertEqual(song.replayGainTrackPeak, 1.0)
    XCTAssertEqual(song.bitrate, 64000)
    XCTAssertEqual(song.contentType, "audio/mpeg")
    XCTAssertEqual(
      song.url,
      "https://music.com.au/play/index.php?ssid=cfj3f237d563f479f5223k23189dbb34&type=song&oid=56&uid=4&player=api&name=Synthetic%20-%20Black-BlueSmoke.mp3"
    )
    XCTAssertEqual(song.size, 4010069)
    XCTAssertEqual(song.artwork?.account?.serverHash, TestAccountInfo.test1ServerHash)
    XCTAssertEqual(song.artwork?.account?.userHash, TestAccountInfo.test1UserHash)
    XCTAssertEqual(song.artwork?.type, "album")
    XCTAssertEqual(song.artwork?.id, "2")
  }
}
