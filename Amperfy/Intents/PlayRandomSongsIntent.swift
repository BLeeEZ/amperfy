//
//  PlayRandomSongsIntent.swift
//  Amperfy
//
//  Created by Maximilian Bauer on 24.12.25.
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
import UIKit

// MARK: - PlayRandomSongsIntent

struct PlayRandomSongsIntent: AppIntent, CustomIntentMigratedAppIntent, PredictableIntent {
  static let intentClassName = "PlayRandomSongsIntent"
  static let title: LocalizedStringResource = "Play Random Songs"
  static let description = IntentDescription("Plays random songs from the user library.")

  @Parameter(title: "Filter", default: .all)
  var filterOption: PlayRandomSongsFilterTypeAppEnum

  static var parameterSummary: some ParameterSummary {
    Summary("Plays random songs") {
      \.$filterOption
    }
  }

  static var predictionConfiguration: some IntentPredictionConfiguration {
    IntentPrediction(parameters: \.$filterOption) { filterOption in
      DisplayRepresentation(
        title: "Plays random songs",
        subtitle: ""
      )
    }
  }

  @MainActor
  func perform() async throws -> some IntentResult {
    let userActivity = NSUserActivity(activityType: NSUserActivity.playRandomSongsActivityType)
    userActivity
      .addUserInfoEntries(from: [
        NSUserActivity.ActivityKeys.libraryElementType
          .rawValue: PlayableContainerTypeAppEnum.song.rawValue,
      ])
    userActivity
      .addUserInfoEntries(from: [NSUserActivity.ActivityKeys.shuffleOption.rawValue: true])
    userActivity
      .addUserInfoEntries(from: [
        NSUserActivity.ActivityKeys.onlyCached.rawValue:
          filterOption.rawValue,
      ])

    let _ = await appDelegate.intentManager.handleIncomingIntent(userActivity: userActivity)
    return .result()
  }
}

extension IntentDialog {
  fileprivate static func filterOptionParameterDisambiguationIntro(
    count: Int,
    filterOption: PlayRandomSongsFilterTypeAppEnum
  )
    -> Self {
    "There are \(count) options matching ‘\(filterOption)’."
  }

  fileprivate static func filterOptionParameterConfirmation(
    filterOption: PlayRandomSongsFilterTypeAppEnum
  )
    -> Self {
    "Just to confirm, you wanted ‘\(filterOption)’?"
  }
}
