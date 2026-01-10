//
//  NextPreviousTrackIntent.swift
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

// MARK: - NextPreviousTrackIntent

struct NextPreviousTrackIntent: AppIntent {
  static let intentClassName = "NextPreviousTrackIntent"
  static let title: LocalizedStringResource = "Play Next/Previous Track"
  static let description = IntentDescription("Play next/previous track in the player queue.")

  @Parameter(
    title: "Mode",
    default: .next
  )
  var nextPreviousMode: NextPreviousTrackAppEnum

  static var parameterSummary: some ParameterSummary {
    Summary("Play \(\.$nextPreviousMode) track") {}
  }

  @MainActor
  func perform() async throws -> some IntentResult {
    switch nextPreviousMode {
    case .next:
      appDelegate.player.playNext()
    case .previousOrReplay:
      appDelegate.player.playPreviousOrReplay()
    case .previous:
      appDelegate.player.playPrevious()
    }
    return .result()
  }
}
