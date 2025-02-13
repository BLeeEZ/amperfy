//
//  ClockTime.swift
//  AmperfyKit
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

import Foundation

public struct ClockTime {
  public var seconds: Int = 0
  public var minutes: Int = 0
  public var hours: Int = 0
  private var sign: Int = 1

  public init(timeInSeconds: Int) {
    if timeInSeconds < 0 {
      self.sign = -1
    }
    let signFreeSeconds = timeInSeconds * sign
    self.seconds = (signFreeSeconds % 3600) % 60
    self.minutes = (signFreeSeconds % 3600) / 60
    self.hours = signFreeSeconds / 3600
  }

  public func asShortString() -> String {
    var shortString = ""
    if sign < 0 {
      shortString = "-"
    }

    if hours > 0 {
      shortString.append(String(format: "%d:%02d:%02d", hours, minutes, seconds))
    } else {
      shortString.append(String(format: "%d:%02d", minutes, seconds))
    }
    return shortString
  }
}
