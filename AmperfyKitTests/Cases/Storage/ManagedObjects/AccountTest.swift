//
//  AccountTest.swift
//  AmperfyKitTests
//
//  Created by Maximilian Bauer on 03.12.25.
//  Copyright (c) 2025 Maximilian Bauer. All rights reserved.
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

@MainActor
class AccountTest: XCTestCase {
  var cdHelper: CoreDataHelper!
  var library: LibraryStorage!
  var testAccount: Account!

  override func setUp() async throws {
    cdHelper = CoreDataHelper()
    let context = cdHelper.createInMemoryManagedObjectContext()
    cdHelper.clearContext(context: context)
    library = LibraryStorage(context: context)
  }

  override func tearDown() {}

  func testCreation() {
    XCTAssertEqual(library.getAllAccounts().count, 0)
    testAccount = library.getAccount(info: TestAccountInfo.create1())
    XCTAssertEqual(testAccount.serverHash, TestAccountInfo.test1ServerHash)
    XCTAssertEqual(testAccount.userHash, TestAccountInfo.test1UserHash)
    XCTAssertEqual(testAccount.apiType, TestAccountInfo.test1ApiType)
    XCTAssertEqual(library.getAllAccounts().count, 1)

    var secondAccount = library.getAccount(info: TestAccountInfo.create2())
    XCTAssertEqual(secondAccount.serverHash, TestAccountInfo.test2ServerHash)
    XCTAssertEqual(secondAccount.userHash, TestAccountInfo.test2UserHash)
    XCTAssertEqual(secondAccount.apiType, TestAccountInfo.test2ApiType)
    XCTAssertEqual(library.getAllAccounts().count, 2)

    testAccount = library.getAccount(info: TestAccountInfo.create1())
    XCTAssertEqual(testAccount.serverHash, TestAccountInfo.test1ServerHash)
    XCTAssertEqual(testAccount.userHash, TestAccountInfo.test1UserHash)
    XCTAssertEqual(testAccount.apiType, TestAccountInfo.test1ApiType)
    XCTAssertEqual(library.getAllAccounts().count, 2)

    secondAccount = library.getAccount(info: TestAccountInfo.create2())
    XCTAssertEqual(secondAccount.serverHash, TestAccountInfo.test2ServerHash)
    XCTAssertEqual(secondAccount.userHash, TestAccountInfo.test2UserHash)
    XCTAssertEqual(secondAccount.apiType, TestAccountInfo.test2ApiType)
    XCTAssertEqual(library.getAllAccounts().count, 2)
  }

  func testDefaultCreation() {
    XCTAssertEqual(library.getAllAccounts().count, 0)
    let defaultAccount = library.getAccount(info: AccountInfo(
      serverHash: "",
      userHash: "",
      apiType: .notDetected
    ))
    XCTAssertEqual(defaultAccount.serverHash, "")
    XCTAssertEqual(defaultAccount.userHash, "")
    XCTAssertEqual(defaultAccount.apiType, .notDetected)
    XCTAssertEqual(library.getAllAccounts().count, 1)

    testAccount = library.getAccount(info: TestAccountInfo.create1())
    XCTAssertEqual(testAccount.serverHash, TestAccountInfo.test1ServerHash)
    XCTAssertEqual(testAccount.userHash, TestAccountInfo.test1UserHash)
    XCTAssertEqual(testAccount.apiType, TestAccountInfo.test1ApiType)
    XCTAssertEqual(library.getAllAccounts().count, 2)

    XCTAssertEqual(defaultAccount.serverHash, "")
    XCTAssertEqual(defaultAccount.userHash, "")
    XCTAssertEqual(defaultAccount.apiType, .notDetected)
    XCTAssertNotEqual(defaultAccount.managedObject, testAccount.managedObject)

    let secondAccount = library.getAccount(info: TestAccountInfo.create2())
    XCTAssertEqual(secondAccount.serverHash, TestAccountInfo.test2ServerHash)
    XCTAssertEqual(secondAccount.userHash, TestAccountInfo.test2UserHash)
    XCTAssertEqual(secondAccount.apiType, TestAccountInfo.test2ApiType)
    XCTAssertEqual(library.getAllAccounts().count, 3)
  }
}
