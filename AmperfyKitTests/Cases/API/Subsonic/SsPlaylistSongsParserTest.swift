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
    playlist = library.createPlaylist()
    recreateParserDelegate()
    createTestArtists()
    createTestAlbums()
  }

  override func recreateParserDelegate() {
    ssParserDelegate = SsPlaylistSongsParserDelegate(
      performanceMonitor: MOCK_PerformanceMonitor(),
      playlist: playlist,
      library: library
    )
  }

  func createTestArtists() {
    var artist = library.createArtist()
    artist.id = "45"
    artist.name = "Brad Sucks"

    artist = library.createArtist()
    artist.id = "54"
    artist.name = "PeerGynt Lobogris"
  }

  func createTestAlbums() {
    var album = library.createAlbum()
    album.id = "58"
    album.name = "I Don't Know What I'm Doing"

    album = library.createAlbum()
    album.id = "68"
    album.name = "Between two worlds"
  }

  func testPlaylistContainsBeforeLessSongsThenAfter() {
    for i in 1 ... 3 {
      let song = library.createSong()
      song.id = i.description
      song.title = i.description
      playlist.append(playable: song)
    }
    createdSongCount = 3
    recreateParserDelegate()
    testParsing()
  }

  func testPlaylistContainsBeforeSameSongCountThenAfter() {
    for i in 1 ... 6 {
      let song = library.createSong()
      song.id = i.description
      song.title = i.description
      playlist.append(playable: song)
    }
    createdSongCount = 6
    recreateParserDelegate()
    testParsing()
  }

  func testPlaylistContainsBeforeMoreSongsThenAfter() {
    for i in 1 ... 20 {
      let song = library.createSong()
      song.id = i.description
      song.title = i.description
      playlist.append(playable: song)
    }
    createdSongCount = 20
    recreateParserDelegate()
    testParsing()
  }

  func testCacheParsing() {
    testParsing()
    XCTAssertFalse(playlist.isCached)

    // mark all songs cached
    for song in playlist.playables {
      song.relFilePath = URL(string: "jop")
    }
    recreateParserDelegate()
    testParsing()
    XCTAssertTrue(playlist.isCached)

    // mark all songs cached exect the last one
    for song in playlist.playables {
      song.relFilePath = URL(string: "jop")
    }
    playlist.playables.last?.relFilePath = nil
    recreateParserDelegate()
    testParsing()
    XCTAssertFalse(playlist.isCached)
  }

  override func checkCorrectParsing() {
    library.saveContext()
    XCTAssertEqual(playlist.playables.count, 6)
    XCTAssertEqual(playlist.playables[0].id, "657")
    XCTAssertEqual(playlist.playables[1].id, "823")
    XCTAssertEqual(playlist.playables[2].id, "748")
    XCTAssertEqual(playlist.playables[3].id, "848")
    XCTAssertEqual(playlist.playables[4].id, "884")
    XCTAssertEqual(playlist.playables[5].id, "805")
    XCTAssertEqual(playlist.duration, 1391)
    XCTAssertEqual(playlist.remoteDuration, 1391)

    XCTAssertEqual(library.songCount, 6 + createdSongCount)

    var song = playlist.playables[0].asSong!
    XCTAssertEqual(song.id, "657")
    XCTAssertEqual(song.title, "Making Me Nervous")
    XCTAssertEqual(song.rating, 2)
    XCTAssertEqual(song.artist?.id, "45")
    XCTAssertEqual(song.artist?.name, "Brad Sucks")
    XCTAssertEqual(song.album?.id, "58")
    XCTAssertEqual(song.album?.name, "I Don't Know What I'm Doing")
    XCTAssertNil(song.disk)
    XCTAssertEqual(song.track, 1)
    XCTAssertNil(song.genre)
    XCTAssertEqual(song.duration, 159)
    XCTAssertEqual(song.year, 2003)
    XCTAssertEqual(song.bitrate, 202000)
    XCTAssertEqual(song.contentType, "audio/mpeg")
    XCTAssertNil(song.url)
    XCTAssertEqual(song.size, 4060113)
    XCTAssertEqual(song.artwork?.url, "")
    XCTAssertEqual(song.artwork?.type, "")
    XCTAssertEqual(song.artwork?.id, "655")

    song = playlist.playables[2].asSong!
    XCTAssertEqual(song.id, "748")
    XCTAssertEqual(song.title, "Stories from Emona II")
    XCTAssertEqual(song.rating, 0)
    XCTAssertEqual(song.artist?.id, "51") // Artist not pre created
    XCTAssertEqual(song.artist?.name, "Maya Filipič")
    XCTAssertEqual(song.album?.id, "68")
    XCTAssertEqual(song.album?.name, "Between two worlds")
    XCTAssertEqual(song.track, 2)
    XCTAssertEqual(song.genre?.id, "")
    XCTAssertEqual(song.genre?.name, "Classical")
    XCTAssertEqual(song.duration, 335)
    XCTAssertEqual(song.year, 2008)
    XCTAssertEqual(song.bitrate, 176000)
    XCTAssertEqual(song.contentType, "audio/mpeg")
    XCTAssertNil(song.url)
    XCTAssertEqual(song.size, 7458214)
    XCTAssertEqual(song.artwork?.url, "")
    XCTAssertEqual(song.artwork?.type, "")
    XCTAssertEqual(song.artwork?.id, "746")

    song = playlist.playables[5].asSong!
    XCTAssertEqual(song.id, "805")
    XCTAssertEqual(song.title, "Bajo siete lunas (intro)")
    XCTAssertEqual(song.rating, 1)
    XCTAssertEqual(song.artist?.id, "54")
    XCTAssertEqual(song.artist?.name, "PeerGynt Lobogris")
    XCTAssertEqual(song.album?.id, "74") // Album not pre created
    XCTAssertEqual(song.album?.name, "Broken Dreams")
    XCTAssertEqual(song.track, 1)
    XCTAssertEqual(song.genre?.id, "")
    XCTAssertEqual(song.genre?.name, "Blues")
    XCTAssertEqual(song.duration, 117)
    XCTAssertEqual(song.year, 2008)
    XCTAssertEqual(song.bitrate, 225000)
    XCTAssertEqual(song.contentType, "audio/mpeg")
    XCTAssertNil(song.url)
    XCTAssertEqual(song.size, 3363271)
    XCTAssertEqual(song.artwork?.url, "")
    XCTAssertEqual(song.artwork?.type, "")
    XCTAssertEqual(song.artwork?.id, "783")
  }
}
