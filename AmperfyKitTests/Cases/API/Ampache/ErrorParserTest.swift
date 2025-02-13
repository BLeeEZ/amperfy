//
//  ErrorParserTest.swift
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

class ErrorParserTest: XCTestCase {
  var xmlData: Data!

  override func setUp() {
    xmlData = getTestFileData(name: "error-4700")
  }

  func testParsing() {
    let parserDelegate = AmpacheXmlParser(performanceMonitor: MOCK_PerformanceMonitor())
    let parser = XMLParser(data: xmlData)
    parser.delegate = parserDelegate
    parser.parse()

    guard let error = parserDelegate.error else { XCTFail(); return }
    XCTAssertEqual(error.statusCode, 4700)
    XCTAssertEqual(error.message, "Access Denied")
  }
}
