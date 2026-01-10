//
//  RatingAppEnum.swift
//  Amperfy
//
//  Created by Maximilian Bauer on 08.01.26.
//  Copyright (c) 2026 Maximilian Bauer. All rights reserved.
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

import AppIntents
import Foundation

enum RatingAppEnum: Int, AppEnum {
  case five
  case four
  case three
  case two
  case one
  case zero

  static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Rating")
  static let caseDisplayRepresentations: [Self: DisplayRepresentation] = [
    .zero: DisplayRepresentation(title: "0", image: .init(systemName: "star.slash")),
    .one: DisplayRepresentation(title: "1", image: .init(systemName: "star.fill")),
    .two: DisplayRepresentation(title: "2", image: .init(systemName: "star.fill")),
    .three: DisplayRepresentation(title: "3", image: .init(systemName: "star.fill")),
    .four: DisplayRepresentation(title: "4", image: .init(systemName: "star.fill")),
    .five: DisplayRepresentation(title: "5", image: .init(systemName: "star.fill")),
  ]
}
