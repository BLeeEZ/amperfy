//
//  PlayerDisplayStyleType.swift
//  AmperfyKit
//
//  Created by Maximilian Bauer on 06.06.22.
//  Copyright (c) 2022 Maximilian Bauer. All rights reserved.
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

public enum PlayerDisplayStyle: Int, Sendable, Codable {
  case compact = 0
  case large = 1

  static let defaultValue: PlayerDisplayStyle = .large

  public mutating func switchToNextStyle() {
    switch self {
    case .compact:
      self = .large
    case .large:
      self = .compact
    }
  }

  public var description: String {
    switch self {
    case .compact: return "Compact"
    case .large: return "Large"
    }
  }
}
