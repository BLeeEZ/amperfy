//
//  AbstractSsTest.swift
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
import CoreData
import XCTest

@MainActor
class AbstractSsParserTest: XCTestCase {
  var context: NSManagedObjectContext!
  var cdHelper: CoreDataHelper!
  var library: LibraryStorage!
  var account: Account!
  var xmlData: Data?
  var xmlErrorData: Data!
  var ssIdParserDelegate: SsIDsParserDelegate!
  var ssParserDelegate: SsXmlParser?

  override func setUp() async throws {
    cdHelper = CoreDataHelper()
    context = cdHelper.createInMemoryManagedObjectContext()
    cdHelper.clearContext(context: context)
    library = LibraryStorage(context: context)
    account = library.getAccount(info: TestAccountInfo.create1())
    _ = library.getAccount(info: TestAccountInfo.create2())
    xmlErrorData = getTestFileData(name: "error_example_1")
    ssIdParserDelegate = SsIDsParserDelegate(performanceMonitor: MOCK_PerformanceMonitor())
  }

  override func tearDown() {}

  var prefetchIdTester: PrefetchIdTester {
    PrefetchIdTester(library: library, prefetchIDs: ssIdParserDelegate.prefetchIDs)
  }

  func testErrorParsing() {
    if Self.typeName == "AbstractSsParserTest" { return }

    createParserDelegate()
    guard let parserDelegate = ssParserDelegate else {
      return
    }
    let parser = XMLParser(data: xmlErrorData)
    parser.delegate = ssParserDelegate
    parser.parse()

    guard let error = parserDelegate.error else { XCTFail(); return }
    XCTAssertEqual(error.statusCode, 40)
    XCTAssertEqual(error.message, "Wrong username or password")
  }

  func testParsing() {
    reTestParsing()
  }

  func testParsingTwice() {
    reTestParsing()
    ssIdParserDelegate = SsIDsParserDelegate(performanceMonitor: MOCK_PerformanceMonitor())
    adjustmentsForSecondParsingDelegate()
    reTestParsing()
  }

  func reTestParsing() {
    if Self.typeName == "AbstractSsParserTest" { return }

    guard let data = xmlData, let ssIdParserDelegate else {
      XCTFail()
      return
    }
    let idParser = XMLParser(data: data)
    idParser.delegate = ssIdParserDelegate
    idParser.parse()
    XCTAssertNil(ssIdParserDelegate.error)

    createParserDelegate()
    guard let ssParserDelegate else { return }

    let parser = XMLParser(data: data)
    parser.delegate = ssParserDelegate
    parser.parse()
    XCTAssertNil(ssParserDelegate.error)
    checkCorrectParsing()
  }

  // Override in concrete test class if needed
  func createParserDelegate() {
    XCTFail()
  }

  // Override in concrete test class if needed
  func adjustmentsForSecondParsingDelegate() {}

  // Override in concrete test class
  func checkCorrectParsing() {
    XCTFail()
  }
}
