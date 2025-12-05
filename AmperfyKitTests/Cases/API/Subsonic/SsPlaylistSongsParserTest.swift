//
//  SsPlaylistSongsParserTest.swift
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

class SsPlaylistSongsParserTest: AbstractSsParserTest {
  var playlist: Playlist!
  var createdSongCount = 0

  override func setUp() async throws {
    try await super.setUp()
    xmlData = getTestFileData(name: "playlist_example_1")
    playlist = library.createPlaylist(account: account)
  }

  override func createParserDelegate() {
    let prefetch = library.getElements(
      account: account,
      prefetchIDs: ssIdParserDelegate.prefetchIDs
    )
    ssParserDelegate = SsPlaylistSongsParserDelegate(
      performanceMonitor: MOCK_PerformanceMonitor(),
      playlist: playlist, account: account,
      library: library, prefetch: prefetch
    )
  }

  func testPlaylistContainsBeforeLessSongsThenAfter() {
    for i in 1 ... 3 {
      let song = library.createSong(account: account)
      song.id = i.description
      song.title = i.description
      playlist.append(playable: song)
    }
    createdSongCount = 3
    testParsing()
  }

  func testPlaylistContainsBeforeSameSongCountThenAfter() {
    for i in 1 ... 6 {
      let song = library.createSong(account: account)
      song.id = i.description
      song.title = i.description
      playlist.append(playable: song)
    }
    createdSongCount = 6
    testParsing()
  }

  func testPlaylistContainsBeforeMoreSongsThenAfter() {
    for i in 1 ... 20 {
      let song = library.createSong(account: account)
      song.id = i.description
      song.title = i.description
      playlist.append(playable: song)
    }
    createdSongCount = 20
    testParsing()
  }

  func testCacheParsing() {
    testParsing()
    XCTAssertFalse(playlist.isCached)

    // mark all songs cached
    for song in playlist.playables {
      song.relFilePath = URL(string: "jop")
    }
    testParsing()
    XCTAssertTrue(playlist.isCached)

    // mark all songs cached exect the last one
    for song in playlist.playables {
      song.relFilePath = URL(string: "jop")
    }
    playlist.playables.last?.relFilePath = nil
    testParsing()
    XCTAssertFalse(playlist.isCached)
  }

  override func checkCorrectParsing() {
    library.saveContext()

    prefetchIdTester.checkPrefetchIdCounts(
      artworkCount: 7,
      genreNameCount: 4,
      artistCount: 5,
      albumCount: 6,
      songCount: 6,
      artworkFetchCount: 6, // the playlist cover itself is not created
      songLibraryCount: 6 + createdSongCount
    )

    XCTAssertEqual(playlist.playables.count, 6)
    XCTAssertEqual(playlist.playables[0].id, "657")
    XCTAssertEqual(playlist.playables[1].id, "823")
    XCTAssertEqual(playlist.playables[2].id, "748")
    XCTAssertEqual(playlist.playables[3].id, "848")
    XCTAssertEqual(playlist.playables[4].id, "884")
    XCTAssertEqual(playlist.playables[5].id, "805")
    XCTAssertEqual(playlist.duration, 1391)
    XCTAssertEqual(playlist.remoteDuration, 1391)

    XCTAssertEqual(library.getSongCount(for: account), 6 + createdSongCount)

    let dateFormatter = ISO8601DateFormatter()
    dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

    var song = playlist.playables[0].asSong!
    XCTAssertEqual(song.account?.serverHash, TestAccountInfo.test1ServerHash)
    XCTAssertEqual(song.account?.userHash, TestAccountInfo.test1UserHash)
    XCTAssertEqual(song.id, "657")
    XCTAssertEqual(song.title, "Making Me Nervous")
    XCTAssertEqual(song.rating, 2)
    XCTAssertEqual(song.artist?.account?.serverHash, TestAccountInfo.test1ServerHash)
    XCTAssertEqual(song.artist?.account?.userHash, TestAccountInfo.test1UserHash)
    XCTAssertEqual(song.artist?.id, "45")
    XCTAssertEqual(song.artist?.name, "Brad Sucks")
    XCTAssertEqual(song.album?.account?.serverHash, TestAccountInfo.test1ServerHash)
    XCTAssertEqual(song.album?.account?.userHash, TestAccountInfo.test1UserHash)
    XCTAssertEqual(song.album?.id, "58")
    XCTAssertEqual(song.album?.name, "I Don't Know What I'm Doing")
    XCTAssertEqual(song.addedDate, dateFormatter.date(from: "2008-04-10T07:10:32"))
    XCTAssertNil(song.disk)
    XCTAssertEqual(song.track, 1)
    XCTAssertNil(song.genre)
    XCTAssertEqual(song.duration, 159)
    XCTAssertEqual(song.year, 2003)
    XCTAssertEqual(song.bitrate, 202000)
    XCTAssertEqual(song.contentType, "audio/mpeg")
    XCTAssertNil(song.url)
    XCTAssertEqual(song.size, 4060113)
    XCTAssertEqual(song.artwork?.account?.serverHash, TestAccountInfo.test1ServerHash)
    XCTAssertEqual(song.artwork?.account?.userHash, TestAccountInfo.test1UserHash)
    XCTAssertEqual(song.artwork?.type, "")
    XCTAssertEqual(song.artwork?.id, "655")

    song = playlist.playables[2].asSong!
    XCTAssertEqual(song.account?.serverHash, TestAccountInfo.test1ServerHash)
    XCTAssertEqual(song.account?.userHash, TestAccountInfo.test1UserHash)
    XCTAssertEqual(song.id, "748")
    XCTAssertEqual(song.title, "Stories from Emona II")
    XCTAssertEqual(song.rating, 0)
    XCTAssertEqual(song.artist?.account?.serverHash, TestAccountInfo.test1ServerHash)
    XCTAssertEqual(song.artist?.account?.userHash, TestAccountInfo.test1UserHash)
    XCTAssertEqual(song.artist?.id, "51") // Artist not pre created
    XCTAssertEqual(song.artist?.name, "Maya Filipič")
    XCTAssertEqual(song.album?.account?.serverHash, TestAccountInfo.test1ServerHash)
    XCTAssertEqual(song.album?.account?.userHash, TestAccountInfo.test1UserHash)
    XCTAssertEqual(song.album?.id, "68")
    XCTAssertEqual(song.album?.name, "Between two worlds")
    XCTAssertEqual(song.addedDate, dateFormatter.date(from: "2008-07-30T22:05:40"))
    XCTAssertEqual(song.track, 2)
    XCTAssertEqual(song.genre?.id, "")
    XCTAssertEqual(song.genre?.name, "Classical")
    XCTAssertEqual(song.duration, 335)
    XCTAssertEqual(song.year, 2008)
    XCTAssertEqual(song.bitrate, 176000)
    XCTAssertEqual(song.contentType, "audio/mpeg")
    XCTAssertNil(song.url)
    XCTAssertEqual(song.size, 7458214)
    XCTAssertEqual(song.artwork?.account?.serverHash, TestAccountInfo.test1ServerHash)
    XCTAssertEqual(song.artwork?.account?.userHash, TestAccountInfo.test1UserHash)
    XCTAssertEqual(song.artwork?.type, "")
    XCTAssertEqual(song.artwork?.id, "746")

    song = playlist.playables[5].asSong!
    XCTAssertEqual(song.account?.serverHash, TestAccountInfo.test1ServerHash)
    XCTAssertEqual(song.account?.userHash, TestAccountInfo.test1UserHash)
    XCTAssertEqual(song.id, "805")
    XCTAssertEqual(song.title, "Bajo siete lunas (intro)")
    XCTAssertEqual(song.rating, 1)
    XCTAssertEqual(song.artist?.account?.serverHash, TestAccountInfo.test1ServerHash)
    XCTAssertEqual(song.artist?.account?.userHash, TestAccountInfo.test1UserHash)
    XCTAssertEqual(song.artist?.id, "54")
    XCTAssertEqual(song.artist?.name, "PeerGynt Lobogris")
    XCTAssertEqual(song.album?.account?.serverHash, TestAccountInfo.test1ServerHash)
    XCTAssertEqual(song.album?.account?.userHash, TestAccountInfo.test1UserHash)
    XCTAssertEqual(song.album?.id, "74") // Album not pre created
    XCTAssertEqual(song.album?.name, "Broken Dreams")
    XCTAssertEqual(song.addedDate, dateFormatter.date(from: "2008-12-19T14:13:58"))
    XCTAssertEqual(song.track, 1)
    XCTAssertEqual(song.genre?.account?.serverHash, TestAccountInfo.test1ServerHash)
    XCTAssertEqual(song.genre?.account?.userHash, TestAccountInfo.test1UserHash)
    XCTAssertEqual(song.genre?.id, "")
    XCTAssertEqual(song.genre?.name, "Blues")
    XCTAssertEqual(song.duration, 117)
    XCTAssertEqual(song.year, 2008)
    XCTAssertEqual(song.bitrate, 225000)
    XCTAssertEqual(song.contentType, "audio/mpeg")
    XCTAssertNil(song.url)
    XCTAssertEqual(song.size, 3363271)
    XCTAssertEqual(song.artwork?.account?.serverHash, TestAccountInfo.test1ServerHash)
    XCTAssertEqual(song.artwork?.account?.userHash, TestAccountInfo.test1UserHash)
    XCTAssertEqual(song.artwork?.type, "")
    XCTAssertEqual(song.artwork?.id, "783")
  }
}
