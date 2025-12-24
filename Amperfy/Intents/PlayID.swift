//
//  PlayID.swift
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

// MARK: - PlayID

@available(iOS 16.0, macOS 13.0, watchOS 9.0, tvOS 16.0, *)
struct PlayID: AppIntent, CustomIntentMigratedAppIntent, PredictableIntent {
  static let intentClassName = "PlayIDIntent"

  static let title: LocalizedStringResource = "Play ID"
  static let description =
    IntentDescription("Plays the library element with the given ID and player options")

  @Parameter(title: "ID")
  var id: String?

  @Parameter(title: "Library Element Type", default: .song)
  var libraryElementType: PlayableContainerTypeAppEnum?

  @Parameter(title: "Shuffle", default: .off)
  var shuffleOption: ShuffleTypeAppEnum?

  @Parameter(title: "Repeat", default: .off)
  var repeatOption: RepeatTypeAppEnum?

  static var parameterSummary: some ParameterSummary {
    Summary("Play ID \(\.$id)") {
      \.$libraryElementType
      \.$shuffleOption
      \.$repeatOption
    }
  }

  static var predictionConfiguration: some IntentPredictionConfiguration {
    IntentPrediction(parameters: (
      \.$id,
      \.$libraryElementType,
      \.$shuffleOption,
      \.$repeatOption
    )) { id, libraryElementType, shuffleOption, repeatOption in
      DisplayRepresentation(
        title: "Play ID \(id!)",
        subtitle: ""
      )
    }
  }

  @MainActor
  func perform() async throws -> some IntentResult {
    let userActivity = NSUserActivity(activityType: NSUserActivity.playIdActivityType)
    userActivity
      .addUserInfoEntries(from: [NSUserActivity.ActivityKeys.id.rawValue: id ?? ""])
    userActivity
      .addUserInfoEntries(from: [
        NSUserActivity.ActivityKeys.libraryElementType.rawValue: libraryElementType?
          .rawValue ?? PlayableContainerTypeAppEnum.song.rawValue,
      ])
    userActivity
      .addUserInfoEntries(from: [
        NSUserActivity.ActivityKeys.shuffleOption.rawValue: shuffleOption?
          .rawValue ?? ShuffleTypeAppEnum.off.rawValue,
      ])
    userActivity
      .addUserInfoEntries(from: [
        NSUserActivity.ActivityKeys.repeatOption.rawValue:
          repeatOption?.rawValue ?? RepeatTypeAppEnum.off.rawValue,
      ])

    let _ = await appDelegate.intentManager.handleIncomingIntent(userActivity: userActivity)
    return .result()
  }
}

@available(iOS 16.0, macOS 13.0, watchOS 9.0, tvOS 16.0, *)
extension IntentDialog {
  fileprivate static var idParameterPrompt: Self {
    "Which ID do you want to play?"
  }

  fileprivate static func libraryElementTypeParameterDisambiguationIntro(
    count: Int,
    libraryElementType: PlayableContainerTypeAppEnum
  )
    -> Self {
    "There are \(count) options matching ‘\(libraryElementType)’."
  }

  fileprivate static func libraryElementTypeParameterConfirmation(
    libraryElementType: PlayableContainerTypeAppEnum
  )
    -> Self {
    "Just to confirm, you wanted ‘\(libraryElementType)’?"
  }

  fileprivate static func shuffleOptionParameterDisambiguationIntro(
    count: Int,
    shuffleOption: ShuffleTypeAppEnum
  )
    -> Self {
    "There are \(count) options matching ‘\(shuffleOption)’."
  }

  fileprivate static func shuffleOptionParameterConfirmation(shuffleOption: ShuffleTypeAppEnum)
    -> Self {
    "Just to confirm, you wanted ‘\(shuffleOption)’?"
  }

  fileprivate static func repeatOptionParameterDisambiguationIntro(
    count: Int,
    repeatOption: RepeatTypeAppEnum
  )
    -> Self {
    "There are \(count) options matching ‘\(repeatOption)’."
  }

  fileprivate static func repeatOptionParameterConfirmation(repeatOption: RepeatTypeAppEnum)
    -> Self {
    "Just to confirm, you wanted ‘\(repeatOption)’?"
  }
}
