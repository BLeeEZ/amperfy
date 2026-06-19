//
//  CustomHTTPHeadersView.swift
//  Amperfy
//
//  Created by Amperfy on 17.06.26.
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

import SwiftUI

// MARK: - HTTPHeaderEntry

struct HTTPHeaderEntry: Identifiable, Equatable {
  let id = UUID()
  var key: String
  var value: String
}

// MARK: - CustomHTTPHeadersView

struct CustomHTTPHeadersView: View {
  private static let cloudflareHeaderKeys = ["CF-Access-Client-Id", "CF-Access-Client-Secret"]

  @State
  private var entries: [HTTPHeaderEntry]
  private let onChange: ([String: String]) -> ()

  init(headers: [String: String], onChange: @escaping ([String: String]) -> ()) {
    _entries = State(
      initialValue: headers
        .map { HTTPHeaderEntry(key: $0.key, value: $0.value) }
        .sorted { $0.key.localizedCaseInsensitiveCompare($1.key) == .orderedAscending }
    )
    self.onChange = onChange
  }

  private func commit() {
    var result = [String: String]()
    for entry in entries {
      let field = entry.key.trimmingCharacters(in: .whitespacesAndNewlines)
      guard !field.isEmpty else { continue }
      result[field] = entry.value
    }
    onChange(result)
  }

  private func addEmptyHeader() {
    entries.append(HTTPHeaderEntry(key: "", value: ""))
  }

  private func addCloudflareAccessToken() {
    for key in Self.cloudflareHeaderKeys
      where !entries.contains(where: { $0.key.caseInsensitiveCompare(key) == .orderedSame }) {
      entries.append(HTTPHeaderEntry(key: key, value: ""))
    }
    commit()
  }

  var body: some View {
    List {
      Section(footer: Text(
        "Headers are sent with every request to the server, including streaming and downloads. Use this to provide a Cloudflare Access service token (CF-Access-Client-Id / CF-Access-Client-Secret) or any other proxy authentication header."
      )) {
        ForEach($entries) { $entry in
          VStack(alignment: .leading, spacing: 4) {
            TextField("Header name", text: $entry.key)
              .font(.headline)
              .autocorrectionDisabled()
              .textInputAutocapitalization(.never)
            TextField("Value", text: $entry.value)
              .foregroundColor(.secondary)
              .autocorrectionDisabled()
              .textInputAutocapitalization(.never)
          }
        }
        .onDelete { indexSet in
          entries.remove(atOffsets: indexSet)
          commit()
        }

        Button(action: addEmptyHeader) {
          Label("Add Header", systemImage: "plus")
        }
      }

      Section {
        Button(action: addCloudflareAccessToken) {
          Label("Add Cloudflare Access Token", systemImage: "lock.shield")
        }
      }
    }
    .onChange(of: entries) { _, _ in
      commit()
    }
    .navigationTitle("Custom HTTP Headers")
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
      EditButton()
    }
  }
}

// MARK: - CustomHTTPHeadersView_Previews

struct CustomHTTPHeadersView_Previews: PreviewProvider {
  static var previews: some View {
    NavigationView {
      CustomHTTPHeadersView(headers: ["CF-Access-Client-Id": "abc.access"]) { _ in }
    }
  }
}
