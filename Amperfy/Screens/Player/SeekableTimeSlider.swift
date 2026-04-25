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
  static let verticalHitAreaExpansion: CGFloat = 20
  static let horizontalHitAreaExpansion: CGFloat = 8

  override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
    let expandedBounds = bounds.inset(
      by: UIEdgeInsets(
        top: -Self.verticalHitAreaExpansion,
        left: -Self.horizontalHitAreaExpansion,
        bottom: -Self.verticalHitAreaExpansion,
        right: -Self.horizontalHitAreaExpansion
      )
    )
    return expandedBounds.contains(point)
  }

  override func beginTracking(_ touch: UITouch, with event: UIEvent?) -> Bool {
    guard isPointerSeekAllowed(touch) else {
      return super.beginTracking(touch, with: event)
    }
    updateValue(for: touch.location(in: self))
    return false
  }

  override func continueTracking(_ touch: UITouch, with event: UIEvent?) -> Bool {
    guard isPointerSeekAllowed(touch) else {
      return super.continueTracking(touch, with: event)
    }
    // For pointer/mouse: suppress drag seeking and UISlider's continuous drag behavior.
    return false
  }

  private func updateValue(for location: CGPoint) {
    guard let value = valueFromLocation(location) else { return }
    self.value = value
    sendActions(for: .valueChanged)
  }

  private func valueFromLocation(_ location: CGPoint) -> Float? {
    let trackRect = trackRect(forBounds: bounds)
    guard trackRect.width > 0 else { return nil }
    let clampedX = min(max(location.x, trackRect.minX), trackRect.maxX)
    let fraction = (clampedX - trackRect.minX) / trackRect.width
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
