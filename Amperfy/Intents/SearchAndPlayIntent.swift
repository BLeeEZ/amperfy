//
//  SearchAndPlayIntent.swift
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

import AmperfyKit
import AppIntents
import Foundation

// MARK: - SearchAndPlayIntent

struct SearchAndPlayIntent: AppIntent, CustomIntentMigratedAppIntent, PredictableIntent {
  static let intentClassName = "SearchAndPlayIntent"
  static let title: LocalizedStringResource = "Search And Play"
  static let description =
    IntentDescription("Searches and plays the first result with the given player options.")

  @Parameter(
    title: "Search Term",
    default: "",
    requestValueDialog: "What do you want to search for?"
  )
  var searchTerm: String

  @Parameter(title: "Search Category", default: .song, requestValueDialog: "In which category?")
  var searchCategory: PlayableContainerTypeAppEnum

  @Parameter(
    title: "Account",
    description: "Account used for search. If not provided the active account will be used."
  )
  var account: AccountAppEntity?

  @Parameter(title: "Shuffle", default: .off)
  var shuffleOption: ShuffleTypeAppEnum

  @Parameter(title: "Repeat", default: .off)
  var repeatOption: RepeatTypeAppEnum

  static var parameterSummary: some ParameterSummary {
    Summary("Search and play \(\.$searchTerm) of type \(\.$searchCategory)") {
      \.$searchCategory
      \.$account
      \.$shuffleOption
      \.$repeatOption
    }
  }

  static var predictionConfiguration: some IntentPredictionConfiguration {
    IntentPrediction(parameters: (
      \.$searchTerm,
      \.$searchCategory,
      \.$account,
      \.$shuffleOption,
      \.$repeatOption
    )) { searchTerm, searchCategory, account, shuffleOption, repeatOption in
      DisplayRepresentation(
        title: "Search and play \(searchTerm) of type \(searchCategory)",
        subtitle: ""
      )
    }
  }

  @MainActor
  func perform() async throws -> some IntentResult & ProvidesDialog & ShowsSnippetView {
    guard let accountCoreData = appDelegate.intentManager.getAccount(fromIntent: account)
    else { throw AmperfyAppIntentError.accountNotValid }
    let isShuffle = shuffleOption == .on
    let repeatUser = RepeatMode.fromIntent(type: repeatOption)

    let playableContainer = appDelegate.intentManager.getPlayableContainer(
      searchTerm: searchTerm,
      searchCategory: searchCategory,
      account: accountCoreData
    )
    let _ = await appDelegate.intentManager.play(
      container: playableContainer,
      shuffleOption: isShuffle,
      repeatOption: repeatUser
    )
    guard let playableContainer else { throw AmperfyAppIntentError.notFound }
    return .result(
      dialog: IntentDialog(stringLiteral: playableContainer.spokenString),
      view:
      PlayPlayableContainableResultView(playableContainable: playableContainer)
    )
  }
}

extension IntentDialog {
  fileprivate static var searchTermParameterPrompt: Self {
    "What do you want to search and play?"
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
