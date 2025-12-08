//
//  SsGenreParserTest.swift
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

class SsGenreParserTest: AbstractSsParserTest {
  override func setUp() async throws {
    try await super.setUp()
    xmlData = getTestFileData(name: "genres_example_1")
  }

  override func createParserDelegate() {
    let prefetch = library.getElements(
      account: account,
      prefetchIDs: ssIdParserDelegate.prefetchIDs
    )
    ssParserDelegate = SsGenreParserDelegate(
      performanceMonitor: MOCK_PerformanceMonitor(), prefetch: prefetch, account: account,
      library: library,
      parseNotifier: nil
    )
  }

  override func checkCorrectParsing() {
    prefetchIdTester.checkPrefetchIdCounts(
      genreNameCount: 7
    )
    XCTAssertEqual(library.getGenreCount(for: account), 7)

    guard let genre = library.getGenre(for: account, name: "Electronic") else { XCTFail(); return }
    XCTAssertEqual(genre.name, "Electronic")
    XCTAssertEqual(genre.account?.serverHash, TestAccountInfo.test1ServerHash)
    XCTAssertEqual(genre.account?.userHash, TestAccountInfo.test1UserHash)
    guard let genre = library.getGenre(for: account, name: "Hard Rock") else { XCTFail(); return }
    XCTAssertEqual(genre.name, "Hard Rock")
    XCTAssertEqual(genre.account?.serverHash, TestAccountInfo.test1ServerHash)
    XCTAssertEqual(genre.account?.userHash, TestAccountInfo.test1UserHash)
    guard let genre = library.getGenre(for: account, name: "R&B") else { XCTFail(); return }
    XCTAssertEqual(genre.name, "R&B")
    XCTAssertEqual(genre.account?.serverHash, TestAccountInfo.test1ServerHash)
    XCTAssertEqual(genre.account?.userHash, TestAccountInfo.test1UserHash)
    guard let genre = library.getGenre(for: account, name: "Blues") else { XCTFail(); return }
    XCTAssertEqual(genre.name, "Blues")
    XCTAssertEqual(genre.account?.serverHash, TestAccountInfo.test1ServerHash)
    XCTAssertEqual(genre.account?.userHash, TestAccountInfo.test1UserHash)
    guard let genre = library.getGenre(for: account, name: "Podcast") else { XCTFail(); return }
    XCTAssertEqual(genre.name, "Podcast")
    XCTAssertEqual(genre.account?.serverHash, TestAccountInfo.test1ServerHash)
    XCTAssertEqual(genre.account?.userHash, TestAccountInfo.test1UserHash)
    guard let genre = library.getGenre(for: account, name: "Brit Pop") else { XCTFail(); return }
    XCTAssertEqual(genre.name, "Brit Pop")
    XCTAssertEqual(genre.account?.serverHash, TestAccountInfo.test1ServerHash)
    XCTAssertEqual(genre.account?.userHash, TestAccountInfo.test1UserHash)
    guard let genre = library.getGenre(for: account, name: "Live") else { XCTFail(); return }
    XCTAssertEqual(genre.name, "Live")
    XCTAssertEqual(genre.account?.serverHash, TestAccountInfo.test1ServerHash)
    XCTAssertEqual(genre.account?.userHash, TestAccountInfo.test1UserHash)
  }
}
