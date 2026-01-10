//
//  SetRepeatIntent.swift
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

extension RepeatTypeAppEnum {
  var image: Image {
    switch self {
    case .single:
      return AmperfyImage.repeatOne.asImage
    case .all:
      return AmperfyImage.repeatAll.asImage
    case .off:
      return AmperfyImage.repeatOff.asImage
    }
  }

  var spokenString: String {
    switch self {
    case .single:
      return "Repeat one track is active."
    case .all:
      return "Repeat all is active."
    case .off:
      return "Repeat is disabled."
    }
  }
}

// MARK: - SetRepeatResultView

struct SetRepeatResultView: View {
  var mode: RepeatTypeAppEnum

  var body: some View {
    VStack {
      mode.image
        .font(intentResultViewHeaderImageFont)
        .foregroundStyle(
          appDelegate.storage.settings.accounts.activeSetting.read.themePreference
            .asSwiftUIColor
        )
      Spacer()
      Text("\(mode.spokenString)")
    }
    .padding()
  }
}

// MARK: - SetRepeatIntent

struct SetRepeatIntent: AppIntent {
  static let intentClassName = "SetRepeatIntent"
  static let title: LocalizedStringResource = "Set Repeat"
  static let description = IntentDescription("Set the repeat mode to all, one or off.")

  @Parameter(
    title: "Repeat",
    requestValueDialog: "Which repeat mode?"
  )
  var repeatMode: RepeatTypeAppEnum

  static var parameterSummary: some ParameterSummary {
    Summary("Set repeat to \(\.$repeatMode)") {}
  }

  @MainActor
  func perform() async throws -> some IntentResult & ProvidesDialog & ShowsSnippetView {
    guard appDelegate.player.playerMode == .music
    else { return .result(dialog: "This option is not available for podcasts.") }

    let repeatModePlayer = RepeatMode.fromIntent(type: repeatMode)
    appDelegate.player.setRepeatMode(repeatModePlayer)
    return .result(
      dialog: "\(repeatMode.spokenString)",
      view:
      SetRepeatResultView(mode: repeatMode)
    )
  }
}
