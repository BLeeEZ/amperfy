//
//  SsIndexesParserTest.swift
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

class SsIndexesParserTest: AbstractSsParserTest {
  var musicFolder: MusicFolder!

  override func setUp() async throws {
    try await super.setUp()
    xmlData = getTestFileData(name: "indexes_example_1")
    musicFolder = library.createMusicFolder(account: account)
  }

  override func createParserDelegate() {
    let prefetch = library.getElements(
      account: account,
      prefetchIDs: ssIdParserDelegate.prefetchIDs
    )
    ssParserDelegate = SsDirectoryParserDelegate(
      performanceMonitor: MOCK_PerformanceMonitor(),
      musicFolder: musicFolder, prefetch: prefetch, account: account,
      library: library
    )
  }

  func testCacheParsing() {
    testParsing()
    XCTAssertFalse((ssParserDelegate as! SsPlayableParserDelegate).isCollectionCached)

    // mark all songs cached
    for song in musicFolder.songs {
      song.relFilePath = URL(string: "jop")
    }
    testParsing()
    XCTAssertTrue((ssParserDelegate as! SsPlayableParserDelegate).isCollectionCached)

    // mark all songs cached exect the last one
    for song in musicFolder.songs {
      song.relFilePath = URL(string: "jop")
    }
    musicFolder.songs.last?.relFilePath = nil
    testParsing()
    XCTAssertFalse((ssParserDelegate as! SsPlayableParserDelegate).isCollectionCached)
  }

  override func checkCorrectParsing() {
    prefetchIdTester.checkPrefetchIdCounts(
      artworkCount: 2,
      genreNameCount: 1,
      localArtistCount: 1,
      songCount: 2,
      directoryCount: 4,
      musicFolderLibraryCount: 1 // it's the one to sync to and created in setup
    )

    let directories = musicFolder.directories.sorted(by: { Int($0.id)! < Int($1.id)! })
    XCTAssertEqual(directories.count, 4)

    XCTAssertEqual(directories[0].account?.serverHash, TestAccountInfo.test1ServerHash)
    XCTAssertEqual(directories[0].account?.userHash, TestAccountInfo.test1UserHash)
    XCTAssertEqual(directories[0].id, "1")
    XCTAssertEqual(directories[0].name, "ABBA")
    XCTAssertEqual(directories[1].account?.serverHash, TestAccountInfo.test1ServerHash)
    XCTAssertEqual(directories[1].account?.userHash, TestAccountInfo.test1UserHash)
    XCTAssertEqual(directories[1].id, "2")
    XCTAssertEqual(directories[1].name, "Alanis Morisette")
    XCTAssertEqual(directories[2].account?.serverHash, TestAccountInfo.test1ServerHash)
    XCTAssertEqual(directories[2].account?.userHash, TestAccountInfo.test1UserHash)
    XCTAssertEqual(directories[2].id, "3")
    XCTAssertEqual(directories[2].name, "Alphaville")
    XCTAssertEqual(directories[3].account?.serverHash, TestAccountInfo.test1ServerHash)
    XCTAssertEqual(directories[3].account?.userHash, TestAccountInfo.test1UserHash)
    XCTAssertEqual(directories[3].id, "4")
    XCTAssertEqual(directories[3].name, "Bob Dylan")

    let songs = musicFolder.songs.sorted(by: { Int($0.id)! < Int($1.id)! })
    XCTAssertEqual(songs.count, 2)

    var song = songs[0]
    XCTAssertEqual(song.account?.serverHash, TestAccountInfo.test1ServerHash)
    XCTAssertEqual(song.account?.userHash, TestAccountInfo.test1UserHash)
    XCTAssertEqual(song.id, "111")
    XCTAssertEqual(song.title, "Dancing Queen")
    XCTAssertEqual(song.artist?.account?.serverHash, TestAccountInfo.test1ServerHash)
    XCTAssertEqual(song.artist?.account?.userHash, TestAccountInfo.test1UserHash)
    XCTAssertEqual(song.artist?.name, "ABBA")
    XCTAssertNil(song.album)
    XCTAssertNil(song.disk)
    XCTAssertEqual(song.track, 7)
    XCTAssertEqual(song.genre?.account?.serverHash, TestAccountInfo.test1ServerHash)
    XCTAssertEqual(song.genre?.account?.userHash, TestAccountInfo.test1UserHash)
    XCTAssertEqual(song.genre?.id, "")
    XCTAssertEqual(song.genre?.name, "Pop")
    XCTAssertEqual(song.duration, 146)
    XCTAssertEqual(song.year, 1978)
    XCTAssertEqual(song.bitrate, 128000)
    XCTAssertEqual(song.contentType, "audio/mpeg")
    XCTAssertNil(song.url)
    XCTAssertEqual(song.size, 8421341)
    XCTAssertEqual(song.artwork?.account?.serverHash, TestAccountInfo.test1ServerHash)
    XCTAssertEqual(song.artwork?.account?.userHash, TestAccountInfo.test1UserHash)
    XCTAssertEqual(song.artwork?.type, "")
    XCTAssertEqual(song.artwork?.id, "24")

    song = songs[1]
    XCTAssertEqual(song.account?.serverHash, TestAccountInfo.test1ServerHash)
    XCTAssertEqual(song.account?.userHash, TestAccountInfo.test1UserHash)
    XCTAssertEqual(song.id, "112")
    XCTAssertEqual(song.title, "Money, Money, Money")
    XCTAssertEqual(song.artist?.account?.serverHash, TestAccountInfo.test1ServerHash)
    XCTAssertEqual(song.artist?.account?.userHash, TestAccountInfo.test1UserHash)
    XCTAssertEqual(song.artist?.name, "ABBA")
    XCTAssertNil(song.album)
    XCTAssertNil(song.disk)
    XCTAssertEqual(song.track, 7)
    XCTAssertEqual(song.genre?.account?.serverHash, TestAccountInfo.test1ServerHash)
    XCTAssertEqual(song.genre?.account?.userHash, TestAccountInfo.test1UserHash)
    XCTAssertEqual(song.genre?.id, "")
    XCTAssertEqual(song.genre?.name, "Pop")
    XCTAssertEqual(song.duration, 208)
    XCTAssertEqual(song.year, 1978)
    XCTAssertEqual(song.bitrate, 128000)
    XCTAssertEqual(song.contentType, "audio/flac")
    XCTAssertNil(song.url)
    XCTAssertEqual(song.size, 4910028)
    XCTAssertEqual(song.artwork?.account?.serverHash, TestAccountInfo.test1ServerHash)
    XCTAssertEqual(song.artwork?.account?.userHash, TestAccountInfo.test1UserHash)
    XCTAssertEqual(song.artwork?.type, "")
    XCTAssertEqual(song.artwork?.id, "25")
  }
}
