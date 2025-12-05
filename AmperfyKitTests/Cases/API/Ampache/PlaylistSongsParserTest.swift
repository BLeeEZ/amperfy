//
//  PlaylistSongsParserTest.swift
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

class PlaylistSongsParserTest: AbstractAmpacheTest {
  var playlist: Playlist!
  var createdSongCount = 0

  override func createParserDelegate() {
    let prefetch = library.getElements(account: account, prefetchIDs: idParserDelegate.prefetchIDs)
    parserDelegate = PlaylistSongsParserDelegate(
      performanceMonitor: MOCK_PerformanceMonitor(), playlist: playlist, prefetch: prefetch,
      account: account,
      library: library
    )
  }

  override func setUp() async throws {
    try await super.setUp()
    playlist = library.createPlaylist(account: account)
    xmlData = getTestFileData(name: "playlist_songs")
    createTestArtists()
    createTestAlbums()
  }

  func createTestArtists() {
    var artist = library.createArtist(account: account)
    artist.id = "27"
    artist.name = "Chi.Otic"

    artist = library.createArtist(account: account)
    artist.id = "20"
    artist.name = "R/B"

    artist = library.createArtist(account: account)
    artist.id = "14"
    artist.name = "Nofi/found."

    artist = library.createArtist(account: account)
    artist.id = "2"
    artist.name = "Synthetic"
  }

  func createTestAlbums() {
    var album = library.createAlbum(account: account)
    album.id = "12"
    album.name = "Buried in Nausea"

    album = library.createAlbum(account: account)
    album.id = "2"
    album.name = "Colorsmoke EP"
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
      artworkCount: 3,
      genreIdCount: 4,
      artistCount: 4,
      albumCount: 2,
      songCount: 4,
      songLibraryCount: 4 + createdSongCount
    )
    XCTAssertEqual(library.getSongCount(for: account), 4 + createdSongCount)

    XCTAssertEqual(playlist.playables.count, 4)
    XCTAssertEqual(playlist.duration, 1442)
    XCTAssertEqual(playlist.remoteDuration, 1442)

    var song = playlist.playables[0].asSong!
    XCTAssertEqual(song.account?.serverHash, TestAccountInfo.test1ServerHash)
    XCTAssertEqual(song.account?.userHash, TestAccountInfo.test1UserHash)
    XCTAssertEqual(song.id, "56")
    XCTAssertEqual(song.title, "Black&BlueSmoke")
    XCTAssertEqual(song.rating, 4)
    XCTAssertEqual(song.artist?.account?.serverHash, TestAccountInfo.test1ServerHash)
    XCTAssertEqual(song.artist?.account?.userHash, TestAccountInfo.test1UserHash)
    XCTAssertEqual(song.artist?.id, "2")
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
    XCTAssertEqual(song.year, 2007)
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

    song = playlist.playables[1].asSong!
    XCTAssertEqual(song.account?.serverHash, TestAccountInfo.test1ServerHash)
    XCTAssertEqual(song.account?.userHash, TestAccountInfo.test1UserHash)
    XCTAssertEqual(song.id, "107")
    XCTAssertEqual(song.title, "Arrest Me")
    XCTAssertEqual(song.rating, 1)
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
    XCTAssertEqual(song.genre?.account?.serverHash, TestAccountInfo.test1ServerHash)
    XCTAssertEqual(song.genre?.account?.userHash, TestAccountInfo.test1UserHash)
    XCTAssertEqual(song.genre?.id, "7")
    XCTAssertEqual(song.genre?.name, "Punk")
    XCTAssertEqual(song.duration, 96)
    XCTAssertEqual(song.year, 2012)
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

    song = playlist.playables[2].asSong!
    XCTAssertEqual(song.account?.serverHash, TestAccountInfo.test1ServerHash)
    XCTAssertEqual(song.account?.userHash, TestAccountInfo.test1UserHash)
    XCTAssertEqual(song.id, "115")
    XCTAssertEqual(song.title, "Are we going Crazy")
    XCTAssertEqual(song.rating, 0)
    XCTAssertEqual(song.artist?.account?.serverHash, TestAccountInfo.test1ServerHash)
    XCTAssertEqual(song.artist?.account?.userHash, TestAccountInfo.test1UserHash)
    XCTAssertEqual(song.artist?.id, "27")
    XCTAssertEqual(song.artist?.name, "Chi.Otic")
    XCTAssertEqual(song.album?.account?.serverHash, TestAccountInfo.test1ServerHash)
    XCTAssertEqual(song.album?.account?.userHash, TestAccountInfo.test1UserHash)
    XCTAssertEqual(song.album?.id, "12")
    XCTAssertEqual(song.album?.name, "Buried in Nausea")
    XCTAssertEqual(song.disk, "1")
    XCTAssertEqual(song.track, 7)
    XCTAssertNil(song.addedDate)
    XCTAssertNil(song.genre)
    XCTAssertEqual(song.duration, 433)
    XCTAssertEqual(song.year, 2012)
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

    song = playlist.playables[3].asSong!
    XCTAssertEqual(song.account?.serverHash, TestAccountInfo.test1ServerHash)
    XCTAssertEqual(song.account?.userHash, TestAccountInfo.test1UserHash)
    XCTAssertEqual(song.id, "85")
    XCTAssertEqual(song.title, "Beq Ultra Fat")
    XCTAssertEqual(song.artist?.account?.serverHash, TestAccountInfo.test1ServerHash)
    XCTAssertEqual(song.artist?.account?.userHash, TestAccountInfo.test1UserHash)
    XCTAssertEqual(song.artist?.id, "14")
    XCTAssertEqual(song.artist?.name, "Nofi/found.")
    XCTAssertNil(song.album)
    XCTAssertNil(song.addedDate)
    XCTAssertEqual(song.disk, "1")
    XCTAssertEqual(song.track, 4)
    XCTAssertEqual(song.genre?.account?.serverHash, TestAccountInfo.test1ServerHash)
    XCTAssertEqual(song.genre?.account?.userHash, TestAccountInfo.test1UserHash)
    XCTAssertEqual(song.genre?.id, "6")
    XCTAssertEqual(song.genre?.name, "Dance")
    XCTAssertEqual(song.duration, 413)
    XCTAssertEqual(song.year, 0)
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
  }
}
