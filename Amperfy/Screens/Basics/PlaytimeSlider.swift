//
//  PlaytimeSlider.swift
//  Amperfy
//
//  Created by Maximilian Bauer on 09.03.19.
//  Copyright (c) 2019 Maximilian Bauer. All rights reserved.
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

class PlaytimeSlider: UISlider {
  private var thumbTouchSize = CGSize(width: 50, height: 30)

  required init?(coder aDecoder: NSCoder) {
    super.init(coder: aDecoder)
    self.preferredBehavioralStyle = .pad
  }

  override func trackRect(forBounds bounds: CGRect) -> CGRect {
    let customBounds = CGRect(
      origin: bounds.origin,
      size: CGSize(width: bounds.size.width, height: 4.0)
    )
    super.trackRect(forBounds: customBounds)
    return customBounds
  }

  // MARK: - Increase touch area for thumb

  override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
    let increasedBounds = bounds.insetBy(dx: -thumbTouchSize.width, dy: -thumbTouchSize.height)
    let containsPoint = increasedBounds.contains(point)
    return containsPoint
  }

  override func beginTracking(_ touch: UITouch, with event: UIEvent?) -> Bool {
    let percentage = CGFloat((value - minimumValue) / (maximumValue - minimumValue))
    let thumbSizeHeight = thumbRect(
      forBounds: bounds,
      trackRect: trackRect(forBounds: bounds),
      value: 0
    ).size.height
    let thumbPosition = thumbSizeHeight + (percentage * (bounds.size.width - (2 * thumbSizeHeight)))
    let touchLocation = touch.location(in: self)
    return touchLocation.x <= (thumbPosition + thumbTouchSize.width) && touchLocation
      .x >= (thumbPosition - thumbTouchSize.width)
  }
}
