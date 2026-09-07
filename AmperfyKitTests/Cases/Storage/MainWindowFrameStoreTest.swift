//
//  MainWindowFrameStoreTest.swift
//  AmperfyKit
//
//  Copyright (c) 2026 Amperfy contributors. All rights reserved.
//
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//

import XCTest

final class MainWindowFrameStoreTest: XCTestCase {
  func testRestoresNormalFrameAndIgnoresFullscreenAndIntermediateResizes() {
    let name = "MainWindowFrameStoreTest-\(UUID())"
    let defaults = UserDefaults(suiteName: name)!
    defer { defaults.removePersistentDomain(forName: name) }
    let store = MainWindowFrameStore(defaults: defaults)
    let frame = CGRect(x: 200, y: 120, width: 1200, height: 800)
    let display = CGRect(x: 0, y: 0, width: 3840, height: 2160)
    store.save(frame, isFullScreen: false, isResizing: false)
    store.save(display, isFullScreen: true, isResizing: false)
    store.save(.zero, isFullScreen: false, isResizing: true)
    XCTAssertEqual(store.restoredFrame(defaultFrame: .zero, displays: [display]), frame)
  }

  func testNegativeDisplayOriginsAndRemovedDisplay() {
    let name = "MainWindowFrameStoreTest-\(UUID())"
    let defaults = UserDefaults(suiteName: name)!
    defer { defaults.removePersistentDomain(forName: name) }
    let store = MainWindowFrameStore(defaults: defaults)
    let primary = CGRect(x: 0, y: 0, width: 1920, height: 1080)
    let secondary = CGRect(x: -2560, y: -400, width: 2560, height: 1440)
    let saved = CGRect(x: -2200, y: -100, width: 1500, height: 900)
    store.save(saved, isFullScreen: false, isResizing: false)
    XCTAssertEqual(store.restoredFrame(defaultFrame: .zero, displays: [primary, secondary]), saved)
    let restored = store.restoredFrame(defaultFrame: .zero, displays: [primary])!
    XCTAssertTrue(primary.contains(restored))
    XCTAssertEqual(restored.size, saved.size)
  }

  func testSmallerDisplayAndLegacyPreference() {
    let name = "MainWindowFrameStoreTest-\(UUID())"
    let defaults = UserDefaults(suiteName: name)!
    defer { defaults.removePersistentDomain(forName: name) }
    let store = MainWindowFrameStore(defaults: defaults)
    let display = CGRect(x: 0, y: 0, width: 1440, height: 900)
    defaults.set([2363.0, 1488.0], forKey: MainWindowFrameStore.sizeKey)
    XCTAssertEqual(store.restoredFrame(defaultFrame: .zero, displays: [display]), display)
    defaults.set([0.0, 0.0, -1.0, 200.0], forKey: MainWindowFrameStore.frameKey)
    XCTAssertEqual(store.restoredFrame(defaultFrame: .zero, displays: [display]), display)
    defaults.removeObject(forKey: MainWindowFrameStore.sizeKey)
    XCTAssertNil(store.restoredFrame(defaultFrame: .zero, displays: [display]))
  }
}
