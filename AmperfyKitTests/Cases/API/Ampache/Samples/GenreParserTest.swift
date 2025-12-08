//
//  GenreParserTest.swift
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

class GenreParserTest: AbstractAmpacheTest {
  override func setUp() async throws {
    try await super.setUp()
    xmlData = getTestFileData(name: "genres")
  }

  override func createParserDelegate() {
    let prefetch = library.getElements(account: account, prefetchIDs: idParserDelegate.prefetchIDs)
    parserDelegate = GenreParserDelegate(
      performanceMonitor: MOCK_PerformanceMonitor(), prefetch: prefetch, account: account,
      library: library,
      parseNotifier: nil
    )
  }

  override func checkCorrectParsing() {
    prefetchIdTester.checkPrefetchIdCounts(
      genreIdCount: 2
    )

    XCTAssertEqual(library.getGenreCount(for: account), 2)

    guard let genre = library.getGenre(for: account, id: "6") else { XCTFail(); return }
    XCTAssertEqual(genre.account?.serverHash, TestAccountInfo.test1ServerHash)
    XCTAssertEqual(genre.account?.userHash, TestAccountInfo.test1UserHash)
    XCTAssertEqual(genre.id, "6")
    XCTAssertEqual(genre.name, "Dance")

    guard let genre = library.getGenre(for: account, id: "4") else { XCTFail(); return }
    XCTAssertEqual(genre.account?.serverHash, TestAccountInfo.test1ServerHash)
    XCTAssertEqual(genre.account?.userHash, TestAccountInfo.test1UserHash)
    XCTAssertEqual(genre.id, "4")
    XCTAssertEqual(genre.name, "Dark Ambient")
  }
}
