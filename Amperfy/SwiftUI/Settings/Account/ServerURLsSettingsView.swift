//
//  ServerURLsSettingsView.swift
//  Amperfy
//
//  Created by Maximilian Bauer on 15.09.22.
//  Copyright (c) 2022 Maximilian Bauer. All rights reserved.
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

// MARK: - ServerURLsSettingsView

struct ServerURLsSettingsView: View {
  @State
  var serverURLs = [String]()
  @State
  var activeServerURL: String = ""
  @State
  var accountServerURL: String = ""
  @State
  var isAddDialogVisible: Bool = false
  @State
  private var selection: String?
  @EnvironmentObject
  var settings: Settings

  func reload() {
    guard let activeAccountInfo = settings.activeAccountInfo else {
      serverURLs = []
      activeServerURL = ""
      accountServerURL = ""
      return
    }
    serverURLs = appDelegate.storage.settings.accounts.getSetting(activeAccountInfo).read
      .loginCredentials?
      .availableServerURLs ?? []
    activeServerURL = appDelegate.storage.settings.accounts.getSetting(activeAccountInfo)
      .read.loginCredentials?
      .activeBackendServerUrl ?? ""
    accountServerURL = appDelegate.storage.settings.accounts.getSetting(activeAccountInfo)
      .read.loginCredentials?
      .serverUrl ?? ""
  }

  func setAsActiveURL(url: String) {
    guard url != activeServerURL, let activeAccountInfo = settings.activeAccountInfo else { return }
    appDelegate.storage.settings.accounts
      .updateSetting(activeAccountInfo) { accountSettings in
        accountSettings.loginCredentials?.activeBackendServerUrl = url
      }
    if let updatedCredentials = appDelegate.storage.settings.accounts
      .getSetting(activeAccountInfo).read
      .loginCredentials {
      appDelegate.getMeta(activeAccountInfo).backendApi
        .provideCredentials(credentials: updatedCredentials)
    }
    reload()
  }

  func deleteURL(url: String) {
    guard url != activeServerURL, url != accountServerURL,
          let activeAccountInfo = settings.activeAccountInfo,
          let currentCredentials = appDelegate.storage.settings.accounts
          .getSetting(activeAccountInfo).read
          .loginCredentials,
          let altIndex = currentCredentials.alternativeServerURLs.firstIndex(of: url)
    else { return }
    var altURLs = currentCredentials.alternativeServerURLs
    altURLs.remove(at: altIndex)
    appDelegate.storage.settings.accounts
      .updateSetting(activeAccountInfo) { accountSettings in
        accountSettings.loginCredentials?.alternativeServerURLs = altURLs
      }
  }

  var body: some View {
    ZStack {
      List(selection: $selection) {
        ForEach(serverURLs, id: \.self) { url in
          HStack {
            Text(url)
            Spacer()
            if url == activeServerURL {
              AmperfyImage.check.asImage
            }
          }
          .id(url)
          .deleteDisabled(url == activeServerURL || url == accountServerURL)
          .onTapGesture {
            setAsActiveURL(url: url)
          }
        }
        .onDelete { indexSet in
          guard let index = indexSet.first else { return }
          deleteURL(url: serverURLs[index])
          serverURLs.remove(atOffsets: indexSet)
        }
        .onChange(of: selection) { oldSelection, newSelection in
          selection = nil
        }
      }
    }
    .sheet(isPresented: $isAddDialogVisible) {
      AlternativeURLAddDialogView(
        isVisible: $isAddDialogVisible,
        activeServerURL: $activeServerURL,
        serverURLs: $serverURLs
      )
    }
    .navigationTitle("Server URLs")
    .toolbar {
      ToolbarItemGroup(placement: .navigationBarTrailing) {
        EditButton()
        Button(action: {
          withPopupAnimation { isAddDialogVisible = true }
        }) {
          AmperfyImage.plus.asImage
        }
      }
    }
    .onAppear {
      reload()
    }
  }
}

// MARK: - ServerURLsSettingsView_Previews

struct ServerURLsSettingsView_Previews: PreviewProvider {
  static var previews: some View {
    ServerURLsSettingsView()
  }
}
