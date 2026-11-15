//
//  AdvancedLoginOptionsView.swift
//  Amperfy
//
//  Created by Jerzy Królak on 10.07.26.
//  Copyright (c) 2026 Maximilian Bauer. All rights reserved.
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
import SwiftUI

// MARK: - AdvancedLoginOptionsView

/// The optional network-access layers shown during login: custom HTTP headers (e.g. a
/// Cloudflare Access service token) and a client certificate for mTLS. Both are independent
/// and layered on top of the regular username/password login. The page inlines the same
/// sections the account settings use.
struct AdvancedLoginOptionsView: View {
  let headers: [String: String]
  let onHeadersChange: ([String: String]) -> ()
  let onDismiss: () -> ()
  /// Closes the sheet. Provided by the presenting UIKit controller, since
  /// `@Environment(\.dismiss)` is unreliable for a UIHostingController root.
  let onDone: () -> ()

  var body: some View {
    NavigationStack {
      SettingsList {
        CustomHTTPHeaderSections(
          title: "Custom HTTP Headers",
          headers: headers,
          onChange: onHeadersChange
        )
        ClientCertificateSections(certTag: ClientCertificateManager.loginTag)
      }
      .navigationTitle("Advanced")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          EditButton()
        }
        ToolbarItem(placement: .confirmationAction) {
          Button("Done") { onDone() }
        }
      }
    }
    .onDisappear { onDismiss() }
  }
}
