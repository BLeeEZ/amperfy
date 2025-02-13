//
//  CatalogParserTest.swift
//  AmperfyKitTests
//
//  Created by Maximilian Bauer on 21.10.21.
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

class CatalogParserTest: AbstractAmpacheTest {
  override func setUp() async throws {
    try await super.setUp()
    xmlData = getTestFileData(name: "catalogs")
    recreateParserDelegate()
  }

  override func recreateParserDelegate() {
    parserDelegate = CatalogParserDelegate(
      performanceMonitor: MOCK_PerformanceMonitor(),
      library: library
    )
  }

  override func checkCorrectParsing() {
    XCTAssertEqual(library.musicFolderCount, 4)

    let musicFolders = library.getMusicFolders().sorted(by: { Int($0.id)! < Int($1.id)! })
    XCTAssertEqual(musicFolders[0].id, "1")
    XCTAssertEqual(musicFolders[0].name, "music")
    XCTAssertFalse(musicFolders[0].isCached)
    XCTAssertEqual(musicFolders[1].id, "2")
    XCTAssertEqual(musicFolders[1].name, "video")
    XCTAssertFalse(musicFolders[1].isCached)
    XCTAssertEqual(musicFolders[2].id, "3")
    XCTAssertEqual(musicFolders[2].name, "podcast")
    XCTAssertFalse(musicFolders[2].isCached)
    XCTAssertEqual(musicFolders[3].id, "4")
    XCTAssertEqual(musicFolders[3].name, "upload")
    XCTAssertFalse(musicFolders[3].isCached)
  }
}
