//
//  SetFavoriteForCurrentlyPlayingSongIntent.swift
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

extension FavoriteTypeAppEnum {
  var image: Image {
    switch self {
    case .favorite:
      return AmperfyImage.heartFill.asImage
    case .removeFromFavorites:
      return AmperfyImage.heartSlash.asImage
    }
  }
}

// MARK: - SetFavoriteForCurrentlyPlayingSongResultView

struct SetFavoriteForCurrentlyPlayingSongResultView: View {
  var isFavorite: FavoriteTypeAppEnum
  var displayString: String

  var body: some View {
    VStack {
      isFavorite.image
        .font(intentResultViewHeaderImageFont)
        .foregroundStyle(
          appDelegate.storage.settings.accounts.activeSetting.read.themePreference
            .asSwiftUIColor
        )
      Spacer()
      Text(displayString)
    }
    .padding()
  }
}

// MARK: - SetFavoriteForCurrentlyPlayingSongIntent

struct SetFavoriteForCurrentlyPlayingSongIntent: AppIntent {
  static let intentClassName = "SetFavoriteForCurrentlyPlayingSongIntent"
  static let title: LocalizedStringResource = "Favorite currently playing song"
  static let description = IntentDescription("Favorite or stop favoriting currently playing song.")

  @Parameter(
    title: "Favorite"
  )
  var isFavorite: FavoriteTypeAppEnum

  static var parameterSummary: some ParameterSummary {
    Summary("\(\.$isFavorite) currently playing song") {}
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
    let isFavoriteBool = isFavorite == .favorite
    let dialog =
      "\(song.title)\(song.creatorName != "" ? " by \(song.creatorName)" : "") has been \(isFavoriteBool ? "added to" : "removed from") favorites."
    guard currentlyPlaying.isFavorite != isFavoriteBool else {
      // do nothing
      return .result(
        dialog: IntentDialog(stringLiteral: dialog),
        view:
        SetFavoriteForCurrentlyPlayingSongResultView(isFavorite: isFavorite, displayString: dialog)
      )
    }

    do {
      if let accountInfo = currentlyPlaying.account?.info {
        let librarySyncer = appDelegate.getMeta(accountInfo).librarySyncer
        try await currentlyPlaying.remoteToggleFavorite(syncer: librarySyncer)
      }
    } catch {
      throw AmperfyAppIntentError.serverSyncFailed
    }
    return .result(
      dialog: IntentDialog(stringLiteral: dialog),
      view:
      SetFavoriteForCurrentlyPlayingSongResultView(isFavorite: isFavorite, displayString: dialog)
    )
  }
}
