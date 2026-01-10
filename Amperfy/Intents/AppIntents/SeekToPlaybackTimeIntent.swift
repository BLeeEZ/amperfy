//
//  SeekToPlaybackTimeIntent.swift
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

import AmperfyKit
import AppIntents
import Foundation
import UIKit

// MARK: - SeekToPlaybackTimeIntent

struct SeekToPlaybackTimeIntent: AppIntent {
  static let intentClassName = "SeekToPlaybackTimeIntent"
  static let title: LocalizedStringResource = "Seek"
  static let description = IntentDescription("Seek to playback time.")

  @Parameter(
    title: "Direction",
  )
  var direction: SeekToPlaybackTimeAppEnum

  @Parameter(
    title: "30",
    default: 30.0
  )
  var interval: Double

  @Parameter(
    title: "Units",
    default: .seconds
  )
  var timeUnit: SeekTimeUnitAppEnum

  static var parameterSummary: some ParameterSummary {
    Summary("Seek \(\.$direction) \(\.$interval) \(\.$timeUnit)") {}
  }

  @MainActor
  func perform() async throws -> some IntentResult {
    var timeInSeconds = 0.0
    switch timeUnit {
    case .seconds:
      timeInSeconds = interval
    case .minutes:
      timeInSeconds = interval * 60.0
    case .hours:
      timeInSeconds = interval * 60.0 * 60.0
    }

    switch direction {
    case .toTime:
      appDelegate.player.seek(toSecond: timeInSeconds)
    case .forward:
      appDelegate.player.skipForward(interval: timeInSeconds)
    case .backward:
      appDelegate.player.skipBackward(interval: timeInSeconds)
    }
    return .result()
  }
}
