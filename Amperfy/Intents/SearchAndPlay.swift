//
//  SearchAndPlay.swift
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

// MARK: - SearchAndPlay

@available(iOS 16.0, macOS 13.0, watchOS 9.0, tvOS 16.0, *)
struct SearchAndPlay: AppIntent, CustomIntentMigratedAppIntent, PredictableIntent {
  static let intentClassName = "SearchAndPlayIntent"

  static let title: LocalizedStringResource = "Search And Play"
  static let description =
    IntentDescription("Searches and plays the first result with the given player options")

  @Parameter(title: "Search Term")
  var searchTerm: String?

  @Parameter(title: "Search Category", default: .song)
  var searchCategory: PlayableContainerTypeAppEnum?

  @Parameter(title: "Shuffle", default: .off)
  var shuffleOption: ShuffleTypeAppEnum?

  @Parameter(title: "Repeat", default: .off)
  var repeatOption: RepeatTypeAppEnum?

  static var parameterSummary: some ParameterSummary {
    Summary("Search And Play \(\.$searchTerm)") {
      \.$searchCategory
      \.$shuffleOption
      \.$repeatOption
    }
  }

  static var predictionConfiguration: some IntentPredictionConfiguration {
    IntentPrediction(parameters: (
      \.$searchTerm,
      \.$searchCategory,
      \.$shuffleOption,
      \.$repeatOption
    )) { searchTerm, searchCategory, shuffleOption, repeatOption in
      DisplayRepresentation(
        title: "Search and play \(searchTerm!)",
        subtitle: ""
      )
    }
  }

  @MainActor
  func perform() async throws -> some IntentResult {
    let userActivity = NSUserActivity(activityType: NSUserActivity.searchAndPlayActivityType)
    userActivity
      .addUserInfoEntries(from: [
        NSUserActivity.ActivityKeys.searchTerm.rawValue: searchTerm ?? "",
      ])
    userActivity
      .addUserInfoEntries(from: [
        NSUserActivity.ActivityKeys.searchCategory.rawValue: searchCategory?
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
  fileprivate static var searchTermParameterPrompt: Self {
    "What  do you want to search and play?"
  }

  fileprivate static func searchCategoryParameterDisambiguationIntro(
    count: Int,
    searchCategory: PlayableContainerTypeAppEnum
  )
    -> Self {
    "There are \(count) options matching ‘\(searchCategory)’."
  }

  fileprivate static func searchCategoryParameterConfirmation(
    searchCategory: PlayableContainerTypeAppEnum
  )
    -> Self {
    "Just to confirm, you wanted ‘\(searchCategory)’?"
  }

  fileprivate static func shuffleOptionParameterDisambiguationIntro(
    count: Int,
    shuffleOption: ShuffleTypeAppEnum
  )
    -> Self {
    "There are \(count) options matching ‘\(shuffleOption)’."
  }

  fileprivate static var shuffleOptionParameterDisambiguationSelection: Self {
    "Shuffled?"
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

  fileprivate static var repeatOptionParameterDisambiguationSelection: Self {
    "Repeat?"
  }

  fileprivate static func repeatOptionParameterConfirmation(repeatOption: RepeatTypeAppEnum)
    -> Self {
    "Just to confirm, you wanted ‘\(repeatOption)’?"
  }
}
