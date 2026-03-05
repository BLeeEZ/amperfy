//
//  SeekableTimeSlider.swift
//  Amperfy
//
//  Created by Jerome Gangneux for Amperfy on 2026-03-02.
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

import UIKit

class SeekableTimeSlider: UISlider {
  static let hitAreaExpansion: CGFloat = 12

  override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
    let expandedBounds = bounds.insetBy(dx: 0, dy: -Self.hitAreaExpansion)
    return expandedBounds.contains(point)
  }

  override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
    guard let touch = touches.first, isPointerSeekAllowed(touch) else {
      super.touchesBegan(touches, with: event)
      return
    }
    let location = touch.location(in: self)
    if let value = valueFromLocation(location) {
      self.value = value
      sendActions(for: .valueChanged)
    }
    super.touchesBegan(touches, with: event)
  }

  override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
    guard let touch = touches.first, isPointerSeekAllowed(touch) else {
      super.touchesMoved(touches, with: event)
      return
    }
    // For pointer/mouse: suppress drag seeking and UISlider's continuous drag behavior.
    _ = touch
  }

  override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
    guard let touch = touches.first, isPointerSeekAllowed(touch) else {
      super.touchesEnded(touches, with: event)
      return
    }
    _ = touch
    super.touchesEnded(touches, with: event)
  }

  private func valueFromLocation(_ location: CGPoint) -> Float? {
    guard bounds.width > 0 else { return nil }
    let fraction = max(0, min(1, location.x / bounds.width))
    return minimumValue + Float(fraction) * (maximumValue - minimumValue)
  }

  private func isPointerSeekAllowed(_ touch: UITouch) -> Bool {
    #if targetEnvironment(macCatalyst)
      return true
    #else
      return touch.type == .indirectPointer
    #endif
  }
}
