//
//  MainWindowFrameStore.swift
//  Amperfy
//
//  Copyright (c) 2026 Amperfy contributors. All rights reserved.
//
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//

// Window geometry is stored in macOS screen points, not UIKit content coordinates.
import Foundation
#if targetEnvironment(macCatalyst)
  import CoreGraphics
#endif

// MARK: - MainWindowFrameStore

struct MainWindowFrameStore {
  let defaults: UserDefaults
  static let frameKey = "window.main.frame.v1"
  static let sizeKey = "window.main.size.v1"

  init(defaults: UserDefaults = .standard) {
    self.defaults = defaults
  }

  func restoredFrame(defaultFrame: CGRect, displays: [CGRect]) -> CGRect? {
    var frame: CGRect
    if let values = defaults.array(forKey: Self.frameKey) as? [Double],
       values.count == 4,
       Self.isValid(CGRect(x: values[0], y: values[1], width: values[2], height: values[3])) {
      frame = CGRect(x: values[0], y: values[1], width: values[2], height: values[3])
    } else if let values = defaults.array(forKey: Self.sizeKey) as? [Double],
              values.count == 2,
              Self.isValid(CGRect(x: 0, y: 0, width: values[0], height: values[1])) {
      frame = CGRect(origin: defaultFrame.origin, size: CGSize(width: values[0], height: values[1]))
    } else {
      return nil
    }
    let screens = displays.filter(Self.isValid)
    guard let primary = screens.first else { return frame }
    // Keep the original display when possible. If it was removed, use the display
    // selected by the system for the new window, then the primary display.
    let screen = screens.max(by: { intersectionArea(frame, $0) < intersectionArea(frame, $1) })
    let destination: CGRect
    if let screen, intersectionArea(frame, screen) > 0 {
      destination = screen
    } else {
      destination = screens.first(where: { $0.contains(defaultFrame.origin) }) ?? primary
      frame.origin = CGPoint(
        x: destination.midX - frame.width / 2,
        y: destination.midY - frame.height / 2
      )
    }
    frame.size.width = min(frame.width, destination.width)
    frame.size.height = min(frame.height, destination.height)
    frame.origin.x = max(destination.minX, min(frame.minX, destination.maxX - frame.width))
    frame.origin.y = max(destination.minY, min(frame.minY, destination.maxY - frame.height))
    // UIKit applies the final menu bar, Dock, and minimum-size constraints.
    return frame
  }

  func save(_ frame: CGRect, isFullScreen: Bool, isResizing: Bool) {
    guard !isFullScreen, !isResizing, Self.isValid(frame) else { return }
    defaults.set(
      [Double(frame.minX), Double(frame.minY), Double(frame.width), Double(frame.height)],
      forKey: Self.frameKey
    )
    defaults.set([Double(frame.width), Double(frame.height)], forKey: Self.sizeKey)
  }

  private static func isValid(_ frame: CGRect) -> Bool {
    [frame.origin.x, frame.origin.y, frame.size.width, frame.size.height]
      .allSatisfy { $0.isFinite && abs($0) < 100_000 } && frame.size.width > 0 && frame.size
      .height > 0
  }

  private func intersectionArea(_ lhs: CGRect, _ rhs: CGRect) -> CGFloat {
    let intersection = lhs.intersection(rhs)
    return intersection.isNull ? 0 : intersection.width * intersection.height
  }

  #if targetEnvironment(macCatalyst)
    static func connectedDisplayFrames() -> [CGRect] {
      var count: UInt32 = 0
      guard CGGetActiveDisplayList(0, nil, &count) == .success, count > 0 else { return [] }
      var displays = [CGDirectDisplayID](repeating: 0, count: Int(count))
      guard CGGetActiveDisplayList(count, &displays, &count) == .success else { return [] }
      return displays.prefix(Int(count)).map { CGDisplayBounds($0) }
    }
  #endif
}
