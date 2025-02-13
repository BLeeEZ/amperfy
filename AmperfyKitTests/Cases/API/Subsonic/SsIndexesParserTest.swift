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
    musicFolder = library.createMusicFolder()
    recreateParserDelegate()
  }

  override func recreateParserDelegate() {
    ssParserDelegate = SsDirectoryParserDelegate(
      performanceMonitor: MOCK_PerformanceMonitor(),
      musicFolder: musicFolder,
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
    recreateParserDelegate()
    testParsing()
    XCTAssertTrue((ssParserDelegate as! SsPlayableParserDelegate).isCollectionCached)

    // mark all songs cached exect the last one
    for song in musicFolder.songs {
      song.relFilePath = URL(string: "jop")
    }
    musicFolder.songs.last?.relFilePath = nil
    recreateParserDelegate()
    testParsing()
    XCTAssertFalse((ssParserDelegate as! SsPlayableParserDelegate).isCollectionCached)
  }

  override func checkCorrectParsing() {
    let directories = musicFolder.directories.sorted(by: { Int($0.id)! < Int($1.id)! })
    XCTAssertEqual(directories.count, 4)

    XCTAssertEqual(directories[0].id, "1")
    XCTAssertEqual(directories[0].name, "ABBA")
    XCTAssertEqual(directories[1].id, "2")
    XCTAssertEqual(directories[1].name, "Alanis Morisette")
    XCTAssertEqual(directories[2].id, "3")
    XCTAssertEqual(directories[2].name, "Alphaville")
    XCTAssertEqual(directories[3].id, "4")
    XCTAssertEqual(directories[3].name, "Bob Dylan")

    let songs = musicFolder.songs.sorted(by: { Int($0.id)! < Int($1.id)! })
    XCTAssertEqual(songs.count, 2)

    var song = songs[0]
    XCTAssertEqual(song.id, "111")
    XCTAssertEqual(song.title, "Dancing Queen")
    XCTAssertEqual(song.artist?.name, "ABBA")
    XCTAssertNil(song.album)
    XCTAssertNil(song.disk)
    XCTAssertEqual(song.track, 7)
    XCTAssertEqual(song.genre?.id, "")
    XCTAssertEqual(song.genre?.name, "Pop")
    XCTAssertEqual(song.duration, 146)
    XCTAssertEqual(song.year, 1978)
    XCTAssertEqual(song.bitrate, 128000)
    XCTAssertEqual(song.contentType, "audio/mpeg")
    XCTAssertNil(song.url)
    XCTAssertEqual(song.size, 8421341)
    XCTAssertEqual(song.artwork?.url, "")
    XCTAssertEqual(song.artwork?.type, "")
    XCTAssertEqual(song.artwork?.id, "24")

    song = songs[1]
    XCTAssertEqual(song.id, "112")
    XCTAssertEqual(song.title, "Money, Money, Money")
    XCTAssertEqual(song.artist?.name, "ABBA")
    XCTAssertNil(song.album)
    XCTAssertNil(song.disk)
    XCTAssertEqual(song.track, 7)
    XCTAssertEqual(song.genre?.id, "")
    XCTAssertEqual(song.genre?.name, "Pop")
    XCTAssertEqual(song.duration, 208)
    XCTAssertEqual(song.year, 1978)
    XCTAssertEqual(song.bitrate, 128000)
    XCTAssertEqual(song.contentType, "audio/flac")
    XCTAssertNil(song.url)
    XCTAssertEqual(song.size, 4910028)
    XCTAssertEqual(song.artwork?.url, "")
    XCTAssertEqual(song.artwork?.type, "")
    XCTAssertEqual(song.artwork?.id, "25")
  }
}
