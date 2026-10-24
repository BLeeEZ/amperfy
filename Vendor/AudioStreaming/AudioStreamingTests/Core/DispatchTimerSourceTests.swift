//
//  DispatchTimerSourceTests.swift
//  AudioStreamingTests
//
//  Created by Dimitrios Chatzieleftheriou on 25/10/2020.
//  Copyright © 2020 Decimal. All rights reserved.
//

@testable import AudioStreaming
import XCTest

class DispatchTimerSourceTests: XCTestCase {
  let dispatchKey = DispatchSpecificKey<Int>()

  let dispatchQueue = DispatchQueue(label: "some.queue")
  var timerSource: DispatchTimerSource?

  override func setUp() {
    dispatchQueue.setSpecific(key: dispatchKey, value: 1)
    timerSource = DispatchTimerSource(interval: .milliseconds(100), queue: dispatchQueue)
  }

  override func tearDown() {
    timerSource = nil
  }

  func test_DispatchTimerSource_Can_Be_Activated_and_Suspended() {
    // starts deactivated
    XCTAssertFalse(timerSource!.isRunning)

    // when actiavated
    timerSource!.activate()
    // it should run
    XCTAssertTrue(timerSource!.isRunning)

    // when suspended
    timerSource!.suspend()
    // it should not run
    XCTAssertFalse(timerSource!.isRunning)
  }

  func test_DispatchTimerSource_Can_Add_A_Handler_ToBe_Called() {
    let expectaction = expectation(description: "fired")

    timerSource?.add {
      expectaction.fulfill()
    }
    timerSource?.activate()

    wait(for: [expectaction], timeout: 1)
    // kill the timer
    timerSource?.suspend()
  }

  func test_DispatchTimerSource_Can_Remove_Handler() {
    let expectaction = expectation(description: "fired")

    timerSource?.add {
      expectaction.fulfill()
    }
    timerSource?.activate()

    wait(for: [expectaction], timeout: 1)
    // kill the timer
    timerSource?.suspend()
    timerSource?.removeHandler()
  }

  func test_HandlerIsExecuted_On_The_Specified_Queue() {
    let expectaction = expectation(description: "fired")

    timerSource?.add {
      XCTAssertEqual(DispatchQueue.getSpecific(key: self.dispatchKey), 1)
      expectaction.fulfill()
    }
    timerSource?.activate()

    wait(for: [expectaction], timeout: 1)
    // kill the timer
    timerSource?.suspend()
  }
}
