//
//  SetRepeatIntent.swift
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

// MARK: - SetRepeatIntent

struct SetRepeatIntent: AppIntent {
  static let intentClassName = "SetRepeatIntent"
  static let title: LocalizedStringResource = "Set Repeat"
  static let description = IntentDescription("Set the repeat mode to all, one or off.")

  @Parameter(
    title: "Repeat",
    default: .all
  )
  var mode: RepeatTypeAppEnum

  static var parameterSummary: some ParameterSummary {
    Summary("Set repeat to \(\.$mode)") {}
  }

  @MainActor
  func perform() async throws -> some IntentResult {
    guard appDelegate.player.playerMode == .music
    else { return .result() }

    let repeatMode = RepeatMode.fromIntent(type: mode)
    appDelegate.player.setRepeatMode(repeatMode)
    return .result()
  }
}
