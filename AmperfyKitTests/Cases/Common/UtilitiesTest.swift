//
//  UtilitiesTest.swift
//  AmperfyKitTests
//
//  Created by Maximilian Bauer on 09.05.21.
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

class UtilitiesTest: XCTestCase {
  func testInt16Valid() {
    XCTAssertTrue(Int16.isValid(value: Int(Int16.max)))
    XCTAssertTrue(Int16.isValid(value: Int(Int16.min)))
    XCTAssertTrue(Int16.isValid(value: Int(0)))
    XCTAssertTrue(Int16.isValid(value: Int(Int16.min) + 1))
    XCTAssertTrue(Int16.isValid(value: Int(Int16.max) - 1))
  }

  func testInt16Invalid() {
    XCTAssertFalse(Int16.isValid(value: Int(Int16.max) + 1))
    XCTAssertFalse(Int16.isValid(value: Int(Int16.min) - 1))
    XCTAssertFalse(Int16.isValid(value: Int(Int32.min)))
    XCTAssertFalse(Int16.isValid(value: Int(Int32.max)))
  }

  func testInt32Valid() {
    XCTAssertTrue(Int32.isValid(value: Int(Int32.max)))
    XCTAssertTrue(Int32.isValid(value: Int(Int32.min)))
    XCTAssertTrue(Int32.isValid(value: Int(0)))
    XCTAssertTrue(Int32.isValid(value: Int(Int32.min + 1)))
    XCTAssertTrue(Int32.isValid(value: Int(Int32.max - 1)))
  }

  func testInt32Invalid() {
    XCTAssertFalse(Int32.isValid(value: Int(Int32.max) + 1))
    XCTAssertFalse(Int32.isValid(value: Int(Int32.min) - 1))
    XCTAssertFalse(Int32.isValid(value: Int(Int64.min)))
    XCTAssertFalse(Int32.isValid(value: Int(Int64.max)))
  }
}
