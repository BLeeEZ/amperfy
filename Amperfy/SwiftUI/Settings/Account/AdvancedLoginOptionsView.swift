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

/// Combined entry point for the optional network-access layers shown during login:
/// custom HTTP headers (e.g. a Cloudflare Access service token) and a client
/// certificate for mTLS. Both are independent and layered on top of the regular
/// username/password login.
struct AdvancedLoginOptionsView: View {
  @Environment(\.dismiss)
  private var dismiss

  @State
  private var headers: [String: String]
  @State
  private var certInfo: ClientCertificateInfo?

  private let onHeadersChange: ([String: String]) -> ()
  private let onDismiss: () -> ()

  init(
    headers: [String: String],
    onHeadersChange: @escaping ([String: String]) -> (),
    onDismiss: @escaping () -> ()
  ) {
    _headers = State(initialValue: headers)
    self.onHeadersChange = onHeadersChange
    self.onDismiss = onDismiss
  }

  private var headersSubtitle: String {
    guard !headers.isEmpty else { return "None" }
    return headers.count == 1 ? "1 header" : "\(headers.count) headers"
  }

  private var certificateSubtitle: String {
    guard let info = certInfo else { return "None" }
    if info.isExpired {
      return "\(info.subjectName) (Expired)"
    }
    return info.subjectName
  }

  private func reloadCertificate() {
    certInfo = ClientCertificateManager.shared
      .getCertificateInfo(tag: ClientCertificateManager.loginTag)
  }

  var body: some View {
    NavigationStack {
      List {
        Section(footer: Text(
          "These options let you connect through a proxy or zero-trust gateway (e.g. Cloudflare Access) placed in front of your server. They are optional and applied on top of your username and password."
        )) {
          NavigationLink {
            CustomHTTPHeadersView(headers: headers) { updated in
              headers = updated
              onHeadersChange(updated)
            }
          } label: {
            optionRow(title: "Custom HTTP Headers", subtitle: headersSubtitle)
          }

          NavigationLink {
            ClientCertificateSettingsView()
          } label: {
            optionRow(title: "Client Certificate", subtitle: certificateSubtitle)
          }
        }
      }
      .navigationTitle("Advanced")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .confirmationAction) {
          Button("Done") { dismiss() }
        }
      }
      .onAppear { reloadCertificate() }
    }
    .onDisappear { onDismiss() }
  }

  private func optionRow(title: String, subtitle: String) -> some View {
    HStack {
      Text(title)
      Spacer()
      Text(subtitle)
        .foregroundColor(.secondary)
    }
  }
}
