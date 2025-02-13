//
//  Corners.swift
//  Amperfy
//
//  Created by Maximilian Bauer on 09.03.21.
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

import UIKit

enum Corners: Int {
  case topRight
  case bottomRight
  case bottomLeft
  case topLeft

  func asPoint() -> CGPoint {
    convertToPoint(corner: self)
  }

  private func convertToPoint(corner: Corners) -> CGPoint {
    switch self {
    case .topRight:
      return CGPoint(x: 1.0, y: 0.0)
    case .bottomRight:
      return CGPoint(x: 1.0, y: 1.0)
    case .bottomLeft:
      return CGPoint(x: 0.0, y: 1.0)
    case .topLeft:
      return CGPoint(x: 0.0, y: 0.0)
    }
  }

  func opposed() -> Corners {
    switch self {
    case .topRight:
      return .bottomLeft
    case .bottomRight:
      return .topLeft
    case .bottomLeft:
      return .topRight
    case .topLeft:
      return .bottomRight
    }
  }

  func rotateRandomly() -> Corners {
    if Bool.random() {
      return rotateClockwise()
    } else {
      return rotateCounterclockwise()
    }
  }

  func rotateClockwise() -> Corners {
    let raw = rawValue
    let rotatedRaw = (raw + 1) % (Corners.topLeft.rawValue + 1)
    return Corners(rawValue: rotatedRaw)!
  }

  func rotateCounterclockwise() -> Corners {
    let raw = rawValue
    if raw == 0 {
      return .topLeft
    }
    return Corners(rawValue: raw - 1)!
  }

  static func randomElement() -> Corners {
    let randomRawValue = Int.random(in: Corners.topRight.rawValue ... Corners.topLeft.rawValue)
    return Corners(rawValue: randomRawValue)!
  }
}
