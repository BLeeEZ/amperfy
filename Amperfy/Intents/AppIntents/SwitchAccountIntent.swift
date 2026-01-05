//
//  SwitchAccountIntent.swift
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
import SwiftUI

// MARK: - SwitchAccounResultView

struct SwitchAccounResultView: View {
  var account: AccountAppEntity

  var body: some View {
    VStack {
      AmperfyImage.account.asImage
        .font(intentResultViewHeaderImageFont)
        .foregroundStyle(
          appDelegate.storage.settings.accounts
            .getSetting(AccountInfo.create(basedOnIdent: account.id)).read.themePreference
            .asSwiftUIColor
        )
      Spacer()
      Text("Switched to \(account.userName) account.")
    }
    .padding()
  }
}

// MARK: - SwitchAccountIntent

struct SwitchAccountIntent: AppIntent {
  static let intentClassName = "SwitchAccountIntent"
  static let title: LocalizedStringResource = "Switch Account"
  static let description = IntentDescription("Switch active account.")

  @Parameter(
    title: "Account",
    description: "Target account to switch to.",
    requestValueDialog: "Which account?"
  )
  var account: AccountAppEntity

  static var parameterSummary: some ParameterSummary {
    Summary("Switch to \(\.$account) account") {}
  }

  @MainActor
  func perform() async throws -> some IntentResult & ProvidesDialog & ShowsSnippetView {
    guard let accountInfo = AccountInfo.create(basedOnIdent: account.id)
    else { throw AmperfyAppIntentError.accountNotValid }
    appDelegate.switchAccount(accountInfo: accountInfo)
    return .result(
      dialog: "Switched to \(account.userName) account.",
      view:
      SwitchAccounResultView(account: account)
    )
  }
}
