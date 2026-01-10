//
//  SetRatingForCurrentlyPlayingSongIntent.swift
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
import SwiftUI

extension RatingAppEnum {
  var numeric: Int {
    switch self {
    case .zero:
      return 0
    case .one:
      return 1
    case .two:
      return 2
    case .three:
      return 3
    case .four:
      return 4
    case .five:
      return 5
    }
  }
}

// MARK: - SetRatingForCurrentlyPlayingSongResultView

struct SetRatingForCurrentlyPlayingSongResultView: View {
  var rating: Int
  var displayString: String

  var body: some View {
    VStack {
      if rating == 0 {
        AmperfyImage.starSlash.asImage
          .font(intentResultViewHeaderImageFont)
          .foregroundStyle(
            appDelegate.storage.settings.accounts.activeSetting.read.themePreference
              .asSwiftUIColor
          )
      } else {
        HStack {
          ForEach(0 ..< rating, id: \.self) { _ in
            AmperfyImage.starFill.asImage
              .font(intentResultViewHeaderImageFont)
              .foregroundStyle(
                appDelegate.storage.settings.accounts.activeSetting.read
                  .themePreference.asSwiftUIColor
              )
          }
        }
      }
      Spacer()
      Text(displayString)
    }
    .padding()
  }
}

// MARK: - SetRatingForCurrentlyPlayingSongIntent

struct SetRatingForCurrentlyPlayingSongIntent: AppIntent {
  static let intentClassName = "SetRatingForCurrentlyPlayingSongIntent"
  static let title: LocalizedStringResource = "Rate currently playing song"
  static let description = IntentDescription("Rate the currently playing song from 0 to 5.")

  @Parameter(
    title: "Rating",
    description: "Song rating between 0 and 5 stars.",
    requestValueDialog: "What rating would you like to give this song, from 0 to 5?",
  )
  var rating: RatingAppEnum

  static var parameterSummary: some ParameterSummary {
    Summary("Rate the currently playing song \(\.$rating) stars") {}
  }

  @MainActor
  func perform() async throws -> some IntentResult & ProvidesDialog & ShowsSnippetView {
    guard appDelegate.storage.settings.user.isOnlineMode else {
      throw AmperfyAppIntentError.changesOnlyInOnlineMode
    }
    guard let currentlyPlaying = appDelegate.player.currentlyPlaying else {
      throw AmperfyAppIntentError.noItemIsPlaying
    }
    guard let song = currentlyPlaying.asSong else {
      // ignore
      return .result(dialog: "This option is only available for songs.")
    }

    song.rating = rating.numeric
    appDelegate.storage.main.saveContext()
    do {
      if let accountInfo = song.account?.info {
        let librarySyncer = appDelegate.getMeta(accountInfo).librarySyncer
        try await librarySyncer.setRating(song: song, rating: rating.numeric)
      }
    } catch {
      throw AmperfyAppIntentError.serverSyncFailed
    }

    let dialog =
      "\(song.title)\(song.creatorName != "" ? " by \(song.creatorName)" : "") has been rated with \(rating) stars."
    return .result(
      dialog: IntentDialog(stringLiteral: dialog),
      view: SetRatingForCurrentlyPlayingSongResultView(
        rating: rating.numeric,
        displayString: dialog
      )
    )
  }
}
