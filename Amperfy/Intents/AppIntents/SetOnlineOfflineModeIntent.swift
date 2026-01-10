//
//  SetOnlineOfflineModeIntent.swift
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

extension OnlineOfflineModeAppEnum {
  var image: Image {
    switch self {
    case .online:
      return AmperfyImage.onlineMode.asImage
    case .offline:
      return AmperfyImage.offlineMode.asImage
    }
  }

  var spokenString: String {
    switch self {
    case .online:
      return "Online mode is active."
    case .offline:
      return "Offline mode is active."
    }
  }
}

// MARK: - SetOnlineOfflineResultView

struct SetOnlineOfflineResultView: View {
  var mode: OnlineOfflineModeAppEnum

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

// MARK: - SetOnlineOfflineModeIntent

struct SetOnlineOfflineModeIntent: AppIntent {
  static let intentClassName = "SetOnlineOfflineModeIntent"
  static let title: LocalizedStringResource = "Activate Online/Offline Mode"
  static let description = IntentDescription("Activate online/offline mode.")

  @Parameter(
    title: "Mode",
    requestValueDialog: "Which mode?"
  )
  var mode: OnlineOfflineModeAppEnum

  static var parameterSummary: some ParameterSummary {
    Summary("Activate \(\.$mode) mode") {}
  }

  @MainActor
  func perform() async throws -> some IntentResult & ProvidesDialog & ShowsSnippetView {
    let isOfflineMode = mode == .offline
    appDelegate.switchOnlineOfflineMode(isOfflineMode: isOfflineMode)
    return .result(
      dialog: "\(mode.spokenString)",
      view: SetOnlineOfflineResultView(mode: mode)
    )
  }
}
