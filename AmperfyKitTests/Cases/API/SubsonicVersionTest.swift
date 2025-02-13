//
//  SubsonicVersionTest.swift
//  AmperfyKitTests
//
//  Created by Maximilian Bauer on 25.02.21.
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

class SubsonicVersionTest: XCTestCase {
  override func setUp() {}

  override func tearDown() {}

  func testCreationGood() {
    let v1 = SubsonicVersion(major: 0, minor: 0, patch: 0)
    XCTAssertEqual(v1.major, 0)
    XCTAssertEqual(v1.minor, 0)
    XCTAssertEqual(v1.patch, 0)

    let v2 = SubsonicVersion(major: 150, minor: 30, patch: 3)
    XCTAssertEqual(v2.major, 150)
    XCTAssertEqual(v2.minor, 30)
    XCTAssertEqual(v2.patch, 3)
  }

  func testCreationGoodString() {
    guard let v1 = SubsonicVersion("0.0.0") else { XCTFail(); return }
    XCTAssertEqual(v1.major, 0)
    XCTAssertEqual(v1.minor, 0)
    XCTAssertEqual(v1.patch, 0)

    guard let v2 = SubsonicVersion("150.30.3") else { XCTFail(); return }
    XCTAssertEqual(v2.major, 150)
    XCTAssertEqual(v2.minor, 30)
    XCTAssertEqual(v2.patch, 3)
  }

  func testCreationBadString1() {
    let v1 = SubsonicVersion("asdf")
    XCTAssertNil(v1)
    let v2 = SubsonicVersion("0.0.-1")
    XCTAssertNil(v2)
    let v3 = SubsonicVersion("0.-1.0")
    XCTAssertNil(v3)
    let v4 = SubsonicVersion("-1.0.0")
    XCTAssertNil(v4)
    let v5 = SubsonicVersion("0.0.-121")
    XCTAssertNil(v5)
    let v6 = SubsonicVersion("aa.0.0")
    XCTAssertNil(v6)
    let v7 = SubsonicVersion("0.bf.5")
    XCTAssertNil(v7)
    let v8 = SubsonicVersion("0.0.-")
    XCTAssertNil(v8)
    let v9 = SubsonicVersion("a.a.123")
    XCTAssertNil(v9)
  }

  func testCreationBadString2() {
    let v1 = SubsonicVersion("0.0")
    XCTAssertNil(v1)
    let v2 = SubsonicVersion("1.14")
    XCTAssertNil(v2)
    let v3 = SubsonicVersion("0.0.0.0")
    XCTAssertNil(v3)
    let v4 = SubsonicVersion("0.0.0.5")
    XCTAssertNil(v4)
    let v5 = SubsonicVersion("1.2.35.99")
    XCTAssertNil(v5)
    let v6 = SubsonicVersion("0.0.0.0.0.0.0.0")
    XCTAssertNil(v6)
    let v7 = SubsonicVersion("0.0.5.asdf")
    XCTAssertNil(v7)
    let v8 = SubsonicVersion("0")
    XCTAssertNil(v8)
  }

  func testToStringFunctionality() {
    let v1 = SubsonicVersion(major: 0, minor: 0, patch: 0)
    XCTAssertEqual(v1.description, "0.0.0")
    let v2 = SubsonicVersion(major: 150, minor: 30, patch: 3)
    XCTAssertEqual(v2.description, "150.30.3")
  }

  func testCompareEqual() {
    let v1 = SubsonicVersion(major: 0, minor: 0, patch: 0)
    let v2 = SubsonicVersion(major: 0, minor: 0, patch: 0)
    XCTAssertTrue(v1 == v2)

    let v3 = SubsonicVersion(major: 0, minor: 0, patch: 1)
    let v4 = SubsonicVersion(major: 30, minor: 5, patch: 1)
    let v5 = SubsonicVersion(major: 30, minor: 5, patch: 1)

    XCTAssertFalse(v1 == v3)
    XCTAssertFalse(v1 == v4)
    XCTAssertFalse(v3 == v4)
    XCTAssertTrue(v4 == v5)
  }

  func testCompareGreater() {
    let v1 = SubsonicVersion(major: 0, minor: 0, patch: 0)
    let v2 = SubsonicVersion(major: 5, minor: 0, patch: 0)
    let v3 = SubsonicVersion(major: 0, minor: 0, patch: 1)
    let v4 = SubsonicVersion(major: 30, minor: 5, patch: 1)
    let v5 = SubsonicVersion(major: 0, minor: 0, patch: 0)

    XCTAssertFalse(v1 > v2)
    XCTAssertTrue(v4 > v3)
    XCTAssertFalse(v1 > v4)
    XCTAssertTrue(v3 > v1)
    XCTAssertFalse(v1 > v5)
  }

  func testCompareLower() {
    let v1 = SubsonicVersion(major: 0, minor: 0, patch: 0)
    let v2 = SubsonicVersion(major: 5, minor: 0, patch: 0)
    let v3 = SubsonicVersion(major: 0, minor: 0, patch: 1)
    let v4 = SubsonicVersion(major: 30, minor: 5, patch: 1)
    let v5 = SubsonicVersion(major: 0, minor: 0, patch: 0)

    XCTAssertTrue(v1 < v2)
    XCTAssertFalse(v4 < v3)
    XCTAssertTrue(v1 < v4)
    XCTAssertFalse(v3 < v1)
    XCTAssertFalse(v1 < v5)
  }

  func testCompareGreaterEqual() {
    let v1 = SubsonicVersion(major: 0, minor: 0, patch: 0)
    let v2 = SubsonicVersion(major: 5, minor: 0, patch: 0)
    let v3 = SubsonicVersion(major: 0, minor: 0, patch: 1)
    let v4 = SubsonicVersion(major: 30, minor: 5, patch: 1)
    let v5 = SubsonicVersion(major: 0, minor: 0, patch: 0)

    XCTAssertFalse(v1 >= v2)
    XCTAssertTrue(v4 >= v3)
    XCTAssertFalse(v1 >= v4)
    XCTAssertTrue(v3 >= v1)
    XCTAssertTrue(v1 >= v5)
  }

  func testCompareLowerEqual() {
    let v1 = SubsonicVersion(major: 0, minor: 0, patch: 0)
    let v2 = SubsonicVersion(major: 5, minor: 0, patch: 0)
    let v3 = SubsonicVersion(major: 0, minor: 0, patch: 1)
    let v4 = SubsonicVersion(major: 30, minor: 5, patch: 1)
    let v5 = SubsonicVersion(major: 0, minor: 0, patch: 0)

    XCTAssertTrue(v1 <= v2)
    XCTAssertFalse(v4 <= v3)
    XCTAssertTrue(v1 <= v4)
    XCTAssertFalse(v3 <= v1)
    XCTAssertTrue(v1 <= v5)
  }
}
