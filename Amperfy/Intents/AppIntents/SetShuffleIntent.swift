//
//  SetShuffleIntent.swift
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

extension EnableDisableShuffleAppEnum {
  var spokenString: String {
    switch self {
    case .enable:
      return "Shuffle is enabled."
    case .disable:
      return "Shuffle is disabled."
    }
  }
}

// MARK: - SetShuffleResultView

struct SetShuffleResultView: View {
  var enabled: EnableDisableShuffleAppEnum

  var body: some View {
    VStack {
      AmperfyImage.shuffle.asImage
        .font(intentResultViewHeaderImageFont)
        .foregroundStyle(
          appDelegate.storage.settings.accounts.activeSetting.read.themePreference
            .asSwiftUIColor
        )
      Spacer()
      Text("\(enabled.spokenString)")
    }
    .padding()
  }
}

// MARK: - SetShuffleIntent

struct SetShuffleIntent: AppIntent {
  static let intentClassName = "SetShuffleIntent"
  static let title: LocalizedStringResource = "Enable/Disable Shuffle"
  static let description = IntentDescription("Enable/Disable shuffle.")

  @Parameter(
    title: "Shuffle",
  )
  var isShuffle: EnableDisableShuffleAppEnum

  static var parameterSummary: some ParameterSummary {
    Summary("\(\.$isShuffle) shuffle") {}
  }

  @MainActor
  func perform() async throws -> some IntentResult & ProvidesDialog & ShowsSnippetView {
    guard appDelegate.player.playerMode == .music
    else { return .result(dialog: "This option is not available for podcasts.") }
    let isEnabled = isShuffle == .enable
    if appDelegate.player.isShuffle != isEnabled {
      appDelegate.player.toggleShuffle()
    }
    return .result(
      dialog: "\(isShuffle.spokenString)",
      view:
      SetShuffleResultView(enabled: isShuffle)
    )
  }
}
