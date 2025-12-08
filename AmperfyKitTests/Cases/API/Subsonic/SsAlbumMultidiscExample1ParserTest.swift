//
//  SsAlbumMultidiscExample1ParserTest.swift
//  AmperfyKitTests
//
//  Created by Maximilian Bauer on 09.01.22.
//  Copyright (c) 2022 Maximilian Bauer. All rights reserved.
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

class SsAlbumMultidiscExample1ParserTest: AbstractSsParserTest {
  let albumId = "e209ff7a279e487ea2f37a4a3e7ed563"

  override func setUp() async throws {
    try await super.setUp()
    xmlData = getTestFileData(name: "album_multidisc_example_1")
    createTestAlbum()
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

  func createTestAlbum() {
    let album = library.createAlbum(account: account)
    album.id = albumId
    album.name = "The Analog Botany Collection"
  }

  override func checkCorrectParsing() {
    prefetchIdTester.checkPrefetchIdCounts(
      artworkCount: 27,
      artistCount: 1,
      albumCount: 1,
      songCount: 27
    )

    let fetchRequest = SongMO.trackNumberSortedFetchRequest
    let album = library.getAlbum(for: account, id: albumId, isDetailFaultResolution: true)!
    fetchRequest.predicate = library.getFetchPredicate(forAlbum: album)

    let songsMO = try? context.fetch(fetchRequest)
    guard let songsMO = songsMO else { XCTFail(); return }
    XCTAssertEqual(songsMO.count, 27)

    let foundSongs = try? context.fetch(fetchRequest)
    let songs = foundSongs?.compactMap { Song(managedObject: $0) }
    guard let songs = songs else { XCTFail(); return }

    var song = songs[0]
    XCTAssertEqual(2, song.track)
    XCTAssertEqual("1", song.disk)
    song = songs[1]
    XCTAssertEqual(3, song.track)
    XCTAssertEqual("1", song.disk)
    song = songs[2]
    XCTAssertEqual(4, song.track)
    XCTAssertEqual("1", song.disk)
    song = songs[3]
    XCTAssertEqual(1, song.track)
    XCTAssertEqual("2", song.disk)
    song = songs[4]
    XCTAssertEqual(3, song.track)
    XCTAssertEqual("2", song.disk)
    song = songs[5]
    XCTAssertEqual(5, song.track)
    XCTAssertEqual("2", song.disk)
    song = songs[6]
    XCTAssertEqual(2, song.track)
    XCTAssertEqual("3", song.disk)
  }
}
