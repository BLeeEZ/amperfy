//
//  SsDirectoriesExample2ParserTest.swift
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

class SsDirectoriesExample2ParserTest: AbstractSsParserTest {
  var directory: Directory!

  override func setUp() async throws {
    try await super.setUp()
    xmlData = getTestFileData(name: "directory_example_2")
    directory = library.createDirectory()
  }

  override func createParserDelegate() {
    let prefetch = library.getElements(prefetchIDs: ssIdParserDelegate.prefetchIDs)
    ssParserDelegate = SsDirectoryParserDelegate(
      performanceMonitor: MOCK_PerformanceMonitor(),
      directory: directory, prefetch: prefetch,
      library: library
    )
  }

  func testCacheParsing() {
    testParsing()
    XCTAssertFalse((ssParserDelegate as! SsPlayableParserDelegate).isCollectionCached)

    // mark all songs cached
    let songs = directory.songs
    for song in songs {
      song.relFilePath = URL(string: "jop")
    }
    testParsing()
    XCTAssertTrue((ssParserDelegate as! SsPlayableParserDelegate).isCollectionCached)

    // mark all songs cached exect the last one
    for song in directory.songs {
      song.relFilePath = URL(string: "jop")
    }
    directory.songs.last?.relFilePath = nil
    testParsing()
    XCTAssertFalse((ssParserDelegate as! SsPlayableParserDelegate).isCollectionCached)
  }

  override func checkCorrectParsing() {
    prefetchIdTester.checkPrefetchIdCounts(
      artworkCount: 2,
      genreNameCount: 1,
      artistCount: 1,
      localArtistCount: 1,
      albumCount: 1,
      songCount: 2,
      directoryLibraryCount: 1 // it's the directory to sync to and created in setup
    )

    XCTAssertEqual(directory.subdirectories.count, 0)
    let songs = directory.songs.sorted(by: { Int($0.id)! < Int($1.id)! })
    XCTAssertEqual(songs.count, 2)

    var song = songs[0]
    XCTAssertEqual(song.id, "111")
    XCTAssertEqual(song.title, "Dancing Queen")
    XCTAssertEqual(song.artist?.id, "5432")
    XCTAssertEqual(song.artist?.name, "ABBA")
    XCTAssertEqual(song.album?.id, "11053")
    XCTAssertEqual(song.album?.name, "Arrival")
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
    XCTAssertEqual(song.artwork?.type, "")
    XCTAssertEqual(song.artwork?.id, "25")

    // denormalized value -> will be updated at save context
    library.saveContext()
    XCTAssertEqual(directory.subdirectoryCount, 0)
    XCTAssertEqual(directory.songCount, 2)
  }
}
