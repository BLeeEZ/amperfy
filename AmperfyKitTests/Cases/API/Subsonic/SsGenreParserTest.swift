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
    ssParserDelegate = SsGenreParserDelegate(
      performanceMonitor: MOCK_PerformanceMonitor(),
      library: library,
      parseNotifier: nil
    )
  }

  override func checkCorrectParsing() {
    XCTAssertEqual(library.genreCount, 7)

    guard let genre = library.getGenre(name: "Electronic") else { XCTFail(); return }
    XCTAssertEqual(genre.name, "Electronic")
    guard let genre = library.getGenre(name: "Hard Rock") else { XCTFail(); return }
    XCTAssertEqual(genre.name, "Hard Rock")
    guard let genre = library.getGenre(name: "R&B") else { XCTFail(); return }
    XCTAssertEqual(genre.name, "R&B")
    guard let genre = library.getGenre(name: "Blues") else { XCTFail(); return }
    XCTAssertEqual(genre.name, "Blues")
    guard let genre = library.getGenre(name: "Podcast") else { XCTFail(); return }
    XCTAssertEqual(genre.name, "Podcast")
    guard let genre = library.getGenre(name: "Brit Pop") else { XCTFail(); return }
    XCTAssertEqual(genre.name, "Brit Pop")
    guard let genre = library.getGenre(name: "Live") else { XCTFail(); return }
    XCTAssertEqual(genre.name, "Live")
  }
}
