//
//  SsDirectoriesExample1ParserTest.swift
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

class SsDirectoriesExample1ParserTest: AbstractSsParserTest {
  var directory: Directory!

  override func setUp() async throws {
    try await super.setUp()
    xmlData = getTestFileData(name: "directory_example_1")
    directory = library.createDirectory()
    ssParserDelegate = SsDirectoryParserDelegate(
      performanceMonitor: MOCK_PerformanceMonitor(),
      directory: directory,
      library: library
    )
    createTestPartner()
  }

  func createTestPartner() {
    let artist = library.createArtist()
    artist.id = "5432"
    artist.name = "ABBA"

    let album = library.createAlbum()
    album.id = "11053"
    album.name = "Arrival"
    album.artwork?.url = "al-11053"
  }

  override func checkCorrectParsing() {
    XCTAssertEqual(directory.songs.count, 0)
    let directories = directory.subdirectories.sorted(by: { Int($0.id)! < Int($1.id)! })
    XCTAssertEqual(directories.count, 2)

    XCTAssertEqual(directories[0].id, "11")
    XCTAssertEqual(directories[0].name, "Arrival")
    XCTAssertEqual(directories[0].artwork?.url, "")
    XCTAssertEqual(directories[0].artwork?.type, "")
    XCTAssertEqual(directories[0].artwork?.id, "22")
    XCTAssertFalse(directories[0].isCached)
    XCTAssertEqual(directories[1].id, "12")
    XCTAssertEqual(directories[1].name, "Super Trouper")
    XCTAssertEqual(directories[1].artwork?.url, "")
    XCTAssertEqual(directories[1].artwork?.type, "")
    XCTAssertEqual(directories[1].artwork?.id, "23")
    XCTAssertFalse(directories[1].isCached)

    // denormalized value -> will be updated at save context
    library.saveContext()
    XCTAssertEqual(directory.subdirectoryCount, 2)
    XCTAssertEqual(directory.songCount, 0)
  }
}
