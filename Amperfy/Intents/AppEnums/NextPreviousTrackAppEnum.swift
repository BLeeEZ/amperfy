//
//  NextPreviousTrackAppEnum.swift
//  Amperfy
//
//  Created by Maximilian Bauer on 27.12.25.
//  Copyright (c) 2025 Maximilian Bauer. All rights reserved.
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

enum NextPreviousTrackAppEnum: Int, AppEnum {
  case next
  case previousOrReplay
  case previous

  static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Next/Previous Track")
  static let caseDisplayRepresentations: [Self: DisplayRepresentation] = [
    .next: DisplayRepresentation(title: "next", image: .init(systemName: "forward.fill")),
    .previousOrReplay: DisplayRepresentation(
      title: "previous or replay",
      image: .init(systemName: "backward.end.alt.fill")
    ),
    .previous: DisplayRepresentation(title: "previous", image: .init(systemName: "backward.fill")),
  ]
}
