//
//  QueueTests.swift
//  AudioStreamingTests
//
//  Created by Dimitrios Chatzieleftheriou on 04/06/2020.
//  Copyright © 2020 Decimal. All rights reserved.
//

import XCTest

@testable import AudioStreaming

class QueueTests: XCTestCase {
  func testQueue() {
    let queue = Queue<Int>()

    XCTAssertEqual(queue.count, 0)
    XCTAssertTrue(queue.isEmpty)

    for i in 10 ..< 30 {
      queue.enqueue(item: i)

      let all = Array(queue)
      let correct = Array((10 ... i).reversed())

      XCTAssertEqual(all, correct)
      XCTAssertEqual(queue.peek()!, 10)
      XCTAssertEqual(queue.count, i - 10 + 1)
    }

    for i in 10 ..< 30 {
      let all = Array(queue)
      let correct = Array((i ... 29).reversed())

      XCTAssertEqual(all, correct)
      XCTAssertEqual(queue.dequeue()!, i)
      XCTAssertEqual(queue.count, 30 - i - 1)
    }
  }

  func testAnElementCanSkipQueue() {
    let queue = Queue<Int>()

    queue.enqueue(item: 1)
    queue.enqueue(item: 2)
    queue.enqueue(item: 3)
    queue.enqueue(item: 4)

    XCTAssertEqual(queue.peek()!, 1)

    queue.skip(item: 5)

    XCTAssertEqual(queue.peek()!, 5)
  }

  func testManyElementsCanSkipQueue() {
    let queue = Queue<Int>()

    queue.enqueue(item: 1)
    queue.enqueue(item: 2)
    queue.enqueue(item: 3)

    XCTAssertEqual(queue.peek()!, 1)

    queue.skip(items: [4, 5, 6])

    XCTAssertEqual(queue.peek()!, 6)
  }

  func testDequeueingOrPeakItemOnAnEmptyQueueReturnsNil() {
    let queue = Queue<Int>()

    XCTAssertNil(queue.dequeue())
    XCTAssertNil(queue.peek())
  }

  func testRemovesAllElements() {
    let queue = Queue<Int>()
    for i in 0 ..< 10 {
      queue.enqueue(item: i)
    }

    queue.removeAll()
    XCTAssertTrue(queue.isEmpty)
  }

  func testInsertingAtSpecificIndex() {
    let queue = Queue<Int>()
    queue.enqueue(item: 1)
    queue.enqueue(item: 2)
    queue.enqueue(item: 3)

    queue.insert(item: 6, at: 1)

    XCTAssertEqual(queue.count, 4)
    XCTAssertEqual(queue.remove(at: 1), 6)
  }

  func testRemovingAtSpecificIndex() {
    let queue = Queue<Int>()
    queue.enqueue(item: 1)
    queue.enqueue(item: 2)
    queue.enqueue(item: 3)

    XCTAssertEqual(queue.remove(at: 1), 2)

    XCTAssertEqual(queue.count, 2)
  }
}
