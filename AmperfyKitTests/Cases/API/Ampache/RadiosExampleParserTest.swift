//
//  RadiosExampleParserTest.swift
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

class RadiosExampleParserTest: AbstractAmpacheTest {
  override func setUp() async throws {
    try await super.setUp()
    xmlData = getTestFileData(name: "live_streams")
  }

  override func createParserDelegate() {
    let prefetch = library.getElements(account: account, prefetchIDs: idParserDelegate.prefetchIDs)
    parserDelegate = RadioParserDelegate(
      performanceMonitor: MOCK_PerformanceMonitor(), prefetch: prefetch, account: account,
      library: library
    )
  }

  override func checkCorrectParsing() {
    prefetchIdTester.checkPrefetchIdCounts(
      radioCount: 3
    )

    let radios = library.getRadios(for: account).sorted(by: { $0.id < $1.id })
    XCTAssertEqual(radios.count, 3)

    var radio = radios[0]
    XCTAssertEqual(radio.account?.serverHash, TestAccountInfo.test1ServerHash)
    XCTAssertEqual(radio.account?.userHash, TestAccountInfo.test1UserHash)
    XCTAssertEqual(radio.id, "1")
    XCTAssertEqual(radio.title, "HBR1.com - Dream Factory")
    XCTAssertEqual(radio.rating, 0)
    XCTAssertEqual(radio.url, "http://ubuntu.hbr1.com:19800/ambient.aac")
    XCTAssertEqual(radio.siteURL?.absoluteString, "http://www.hbr1.com/")
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
    XCTAssertEqual(radio.id, "2")
    XCTAssertEqual(radio.title, "HBR1.com - I.D.M. Tranceponder")
    XCTAssertEqual(radio.rating, 0)
    XCTAssertEqual(radio.url, "http://ubuntu.hbr1.com:19800/trance.ogg")
    XCTAssertEqual(radio.siteURL?.absoluteString, "http://www.hbr1.com/")
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

    radio = radios[2]
    XCTAssertEqual(radio.account?.serverHash, TestAccountInfo.test1ServerHash)
    XCTAssertEqual(radio.account?.userHash, TestAccountInfo.test1UserHash)
    XCTAssertEqual(radio.id, "3")
    XCTAssertEqual(radio.title, "4ZZZ Community Radio")
    XCTAssertEqual(radio.rating, 0)
    XCTAssertEqual(radio.url, "https://stream.4zzz.org.au:9200/4zzz")
    XCTAssertEqual(radio.siteURL?.absoluteString, "https://4zzzfm.org.au")
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
