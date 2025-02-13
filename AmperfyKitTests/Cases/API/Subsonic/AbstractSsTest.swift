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
  var xmlData: Data?
  var xmlErrorData: Data!
  var ssParserDelegate: SsXmlParser?

  override func setUp() async throws {
    cdHelper = CoreDataHelper()
    context = cdHelper.createInMemoryManagedObjectContext()
    cdHelper.clearContext(context: context)
    library = LibraryStorage(context: context)
    xmlErrorData = getTestFileData(name: "error_example_1")
  }

  override func tearDown() {}

  func testErrorParsing() {
    guard let parserDelegate = ssParserDelegate else {
      if Self.typeName != "AbstractSsParserTest" { XCTFail() }
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
    guard let data = xmlData, let parserDelegate = ssParserDelegate else {
      if Self.typeName != "AbstractSsParserTest" { XCTFail() }
      return
    }
    let parser = XMLParser(data: data)
    parser.delegate = parserDelegate
    parser.parse()
    XCTAssertNil(parserDelegate.error)
    checkCorrectParsing()
  }

  func testParsingTwice() {
    guard let data = xmlData else {
      if Self.typeName != "AbstractSsParserTest" { XCTFail() }
      return
    }
    let parser1 = XMLParser(data: data)
    parser1.delegate = ssParserDelegate
    parser1.parse()
    checkCorrectParsing()

    recreateParserDelegate()
    let parser2 = XMLParser(data: data)
    parser2.delegate = ssParserDelegate
    parser2.parse()
    checkCorrectParsing()
  }

  // Override in concrete test class if needed
  func recreateParserDelegate() {}

  // Override in concrete test class
  func checkCorrectParsing() {
    XCTFail()
  }
}
