//
//  OpenAppWithConfigurationIntent.swift
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
import UIKit

// MARK: - OpenAppWithConfigurationIntent

struct OpenAppWithConfigurationIntent: AppIntent {
  static let intentClassName = "OpenAppWithConfigurationIntent"
  static let title: LocalizedStringResource = "Open With Configuration"
  static let description = IntentDescription("Open a specific account in online/offline mode.")
  static let supportedModes: IntentModes = .foreground(.deferred)

  @Parameter(
    title: "Account",
    description: "Account to switch to.",
    requestValueDialog: "Which account?"
  )
  var account: AccountAppEntity?

  @Parameter(
    title: "Online/Offline",
    description: "Activate online/offline mode.",
    requestValueDialog: "Online or offline mode?"
  )
  var mode: OnlineOfflineModeAppEnum?

  static var parameterSummary: some ParameterSummary {
    Summary("Open with \(\.$account) account in \(\.$mode) mode") {}
  }

  @MainActor
  func perform() async throws -> some IntentResult {
    if let mode {
      let isOfflineMode = mode == .offline
      appDelegate.switchOnlineOfflineMode(isOfflineMode: isOfflineMode)
    }
    if let account, let accountInfo = AccountInfo.create(basedOnIdent: account.id) {
      appDelegate.switchAccount(accountInfo: accountInfo)
    }
    return .result()
  }
}
