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

import AmperfyKit
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
  
  @Parameter(title: "Account", description: "Account used to select songs from. If not provided the active account will be used.")
  var account: AccountAppEntity?

  static var parameterSummary: some ParameterSummary {
    Summary("Plays random songs") {
      \.$account
      \.$filterOption
    }
  }

  static var predictionConfiguration: some IntentPredictionConfiguration {
    IntentPrediction(parameters: (\.$filterOption, \.$account)) { filterOption, account in
      DisplayRepresentation(
        title: "Plays random songs",
        subtitle: ""
      )
    }
  }

  @MainActor
  func perform() async throws -> some IntentResult {
    guard let accountCoreData = appDelegate.intentManager.getAccount(fromIntent: account) else { throw AmperfyAppIntentError.accountNotValid }
    let isCacheOnly = filterOption == .cache

    let songs = appDelegate.storage.main.library.getRandomSongs(
      for: accountCoreData,
      count: appDelegate.player.maxSongsToAddOnce,
      onlyCached: isCacheOnly
    )
    let playerContext = PlayContext(name: "Random Songs", playables: songs)
    let success = appDelegate.intentManager.play(context: playerContext, shuffleOption: true, repeatOption: .off)
    guard success else { throw AmperfyAppIntentError.notFound }
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
