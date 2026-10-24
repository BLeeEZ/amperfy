//
//  BiMapTests.swift
//  AudioStreamingTests
//
//  Created by Dimitrios Chatzieleftheriou on 26/05/2020.
//  Copyright © 2020 Decimal. All rights reserved.
//

import XCTest

@testable import AudioStreaming

// MARK: - BiMapTests

class BiMapTests: XCTestCase {
  func test_BiMap_Can_Store_And_Retrieve_Values() {
    var map = BiMap<SomeClass, SomeOtherClass>()
    let someClass = SomeClass(item: 0)
    let someOtherClass = SomeOtherClass(item: 0)
    map[someClass] = someOtherClass

    XCTAssertEqual(map[someClass], someOtherClass)
    XCTAssertEqual(map[someOtherClass], someClass)
  }

  func test_BiMap_Can_Retrieve_LeftAndRight_Values() {
    var map = BiMap<SomeClass, SomeOtherClass>()
    let someClass = SomeClass(item: 0)
    let someOtherClass = SomeOtherClass(item: 0)
    map[someClass] = someOtherClass

    XCTAssertEqual(map.leftValues, [someClass])
    XCTAssertEqual(map.rightValues, [someOtherClass])
  }

  func test_BiMap_Can_Store_Using_Either_Value_As_Key() {
    var map = BiMap<SomeClass, SomeOtherClass>()
    let someClass = SomeClass(item: 0)
    let someOtherClass = SomeOtherClass(item: 0)

    // Storing using the right value as key
    map[someOtherClass] = someClass

    // Storing using the left value as key
    map[someClass] = someOtherClass

    XCTAssertEqual(map[someOtherClass], someClass)
    XCTAssertEqual(map[someClass], someOtherClass)
  }

  func test_BiMap_Can_Remove_Value_When_Passing_Nil() {
    var map = BiMap<SomeClass, SomeOtherClass>()
    let someClass = SomeClass(item: 0)
    let someOtherClass = SomeOtherClass(item: 0)

    // Storing using the right value as key
    map[someOtherClass] = someClass

    // Storing using the left value as key
    map[someClass] = someOtherClass

    // Setting to nil
    map[someClass] = nil

    XCTAssert(map.leftValues.isEmpty)
    XCTAssert(map.rightValues.isEmpty)
  }
}

// MARK: - SomeClass

// For Convenience

class SomeClass: Hashable {
  static func == (lhs: SomeClass, rhs: SomeClass) -> Bool {
    lhs.item == rhs.item
  }

  func hash(into hasher: inout Hasher) {
    hasher.combine(item)
  }

  var item: Int

  init(item: Int) {
    self.item = item
  }
}

// MARK: - SomeOtherClass

class SomeOtherClass: Hashable {
  static func == (lhs: SomeOtherClass, rhs: SomeOtherClass) -> Bool {
    lhs.item == rhs.item
  }

  func hash(into hasher: inout Hasher) {
    hasher.combine(item)
  }

  var item: Int

  init(item: Int) {
    self.item = item
  }
}
