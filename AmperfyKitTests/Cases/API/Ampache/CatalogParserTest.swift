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
  }

  override func createParserDelegate() {
    let prefetch = library.getElements(account: account, prefetchIDs: idParserDelegate.prefetchIDs)
    parserDelegate = CatalogParserDelegate(
      performanceMonitor: MOCK_PerformanceMonitor(), prefetch: prefetch, account: account,
      library: library
    )
  }

  override func checkCorrectParsing() {
    prefetchIdTester.checkPrefetchIdCounts(
      musicFolderCount: 4
    )

    XCTAssertEqual(library.getMusicFolderCount(for: account), 4)

    let musicFolders = library.getMusicFolders(for: account)
      .sorted(by: { Int($0.id)! < Int($1.id)! })
    XCTAssertEqual(musicFolders[0].account?.serverHash, TestAccountInfo.test1ServerHash)
    XCTAssertEqual(musicFolders[0].account?.userHash, TestAccountInfo.test1UserHash)
    XCTAssertEqual(musicFolders[0].id, "1")
    XCTAssertEqual(musicFolders[0].name, "music")
    XCTAssertFalse(musicFolders[0].isCached)
    XCTAssertEqual(musicFolders[1].account?.serverHash, TestAccountInfo.test1ServerHash)
    XCTAssertEqual(musicFolders[1].account?.userHash, TestAccountInfo.test1UserHash)
    XCTAssertEqual(musicFolders[1].id, "2")
    XCTAssertEqual(musicFolders[1].name, "video")
    XCTAssertFalse(musicFolders[1].isCached)
    XCTAssertEqual(musicFolders[2].account?.serverHash, TestAccountInfo.test1ServerHash)
    XCTAssertEqual(musicFolders[2].account?.userHash, TestAccountInfo.test1UserHash)
    XCTAssertEqual(musicFolders[2].id, "3")
    XCTAssertEqual(musicFolders[2].name, "podcast")
    XCTAssertFalse(musicFolders[2].isCached)
    XCTAssertEqual(musicFolders[3].account?.serverHash, TestAccountInfo.test1ServerHash)
    XCTAssertEqual(musicFolders[3].account?.userHash, TestAccountInfo.test1UserHash)
    XCTAssertEqual(musicFolders[3].id, "4")
    XCTAssertEqual(musicFolders[3].name, "upload")
    XCTAssertFalse(musicFolders[3].isCached)
  }
}
