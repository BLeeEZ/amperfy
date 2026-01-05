//
//  ContinuePlaybackIntent.swift
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

extension PlaybackModeAppEnum {
  var image: Image {
    switch self {
    case .music:
      return AmperfyImage.musicalNotes.asImage
    case .podcast:
      return AmperfyImage.podcast.asImage
    }
  }

  var spokenString: String {
    switch self {
    case .music:
      return "Continue Music playback."
    case .podcast:
      return "Continue Podcast playback."
    }
  }
}

// MARK: - ContinuePlaybackResultView

struct ContinuePlaybackResultView: View {
  var playbackMode: PlaybackModeAppEnum

  var body: some View {
    VStack {
      playbackMode.image
        .font(intentResultViewHeaderImageFont)
        .foregroundStyle(
          appDelegate.storage.settings.accounts.activeSetting.read.themePreference
            .asSwiftUIColor
        )
      Spacer()
      Text(playbackMode.spokenString)
    }
    .padding()
  }
}

// MARK: - ContinuePlaybackIntent

struct ContinuePlaybackIntent: AppIntent {
  static let intentClassName = "ContinuePlaybackIntent"
  static let title: LocalizedStringResource = "Continue Playback"
  static let description = IntentDescription("Continue playback.")

  @Parameter(
    title: "Playback Mode",
    description: "The mode in which the player should continue playback.",
    default: .music,
    requestValueDialog: "Which playback mode?"
  )
  var playbackMode: PlaybackModeAppEnum

  static var parameterSummary: some ParameterSummary {
    Summary("Continue \(\.$playbackMode) playback") {}
  }

  @MainActor
  func perform() async throws -> some IntentResult & ProvidesDialog & ShowsSnippetView {
    let playerMode = PlayerMode.fromIntent(type: playbackMode)
    if appDelegate.player.playerMode != playerMode {
      appDelegate.player.setPlayerMode(playerMode)
    }
    appDelegate.player.play()
    return .result(
      dialog: "\(playbackMode.spokenString)",
      view:
      ContinuePlaybackResultView(playbackMode: playbackMode)
    )
  }
}
