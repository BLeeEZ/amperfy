//
//  SsRadioExampleParserTest.swift
//  AmperfyKitTests
//
//  Created by Maximilian Bauer on 27.12.24.
//  Copyright (c) 2024 Maximilian Bauer. All rights reserved.
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

class SsRadioExampleParserTest: AbstractSsParserTest {
  override func setUp() async throws {
    try await super.setUp()
    xmlData = getTestFileData(name: "internetRadioStations_example_1")
  }

  override func createParserDelegate() {
    let prefetch = library.getElements(
      account: account,
      prefetchIDs: ssIdParserDelegate.prefetchIDs
    )
    ssParserDelegate = SsRadioParserDelegate(
      performanceMonitor: MOCK_PerformanceMonitor(), prefetch: prefetch, account: account,
      library: library,
      parseNotifier: nil
    )
  }

  override func checkCorrectParsing() {
    prefetchIdTester.checkPrefetchIdCounts(
      radioCount: 2
    )

    let radios = library.getRadios(for: account).sorted(by: { $0.id < $1.id })
    XCTAssertEqual(radios.count, 2)

    var radio = radios[0]
    XCTAssertEqual(radio.account?.serverHash, TestAccountInfo.test1ServerHash)
    XCTAssertEqual(radio.account?.userHash, TestAccountInfo.test1UserHash)
    XCTAssertEqual(radio.id, "0")
    XCTAssertEqual(radio.title, "NRK P1")
    XCTAssertEqual(radio.rating, 0)
    XCTAssertEqual(radio.url, "http://lyd.nrk.no/nrk_radio_p1_ostlandssendingen_mp3_m")
    XCTAssertEqual(radio.siteURL?.absoluteString, "http://www.nrk.no/p1")
    XCTAssertNil(radio.disk)
    XCTAssertEqual(radio.duration, 0)
    XCTAssertEqual(radio.remoteStatus, .available)
    XCTAssertEqual(radio.remoteDuration, 0)
    XCTAssertEqual(radio.year, 0)
    XCTAssertEqual(radio.bitrate, 0)
    XCTAssertEqual(radio.isFavorite, false)
    XCTAssertNil(radio.starredDate)
    XCTAssertNil(radio.contentType)
    XCTAssertEqual(radio.size, 0)
    XCTAssertNil(radio.artwork)

    radio = radios[1]
    XCTAssertEqual(radio.account?.serverHash, TestAccountInfo.test1ServerHash)
    XCTAssertEqual(radio.account?.userHash, TestAccountInfo.test1UserHash)
    XCTAssertEqual(radio.id, "1")
    XCTAssertEqual(radio.title, "NRK P2")
    XCTAssertEqual(radio.rating, 0)
    XCTAssertEqual(radio.url, "http://lyd.nrk.no/nrk_radio_p2_mp3_m")
    XCTAssertEqual(radio.siteURL?.absoluteString, "http://p3.no")
    XCTAssertNil(radio.disk)
    XCTAssertEqual(radio.duration, 0)
    XCTAssertEqual(radio.remoteStatus, .available)
    XCTAssertEqual(radio.remoteDuration, 0)
    XCTAssertEqual(radio.year, 0)
    XCTAssertEqual(radio.bitrate, 0)
    XCTAssertEqual(radio.isFavorite, false)
    XCTAssertNil(radio.starredDate)
    XCTAssertNil(radio.contentType)
    XCTAssertEqual(radio.size, 0)
    XCTAssertNil(radio.artwork)
  }
}
