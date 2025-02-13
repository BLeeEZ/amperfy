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
  var isAddDialogVisible: Bool = false
  @State
  private var selection: String?

  func reload() {
    serverURLs = appDelegate.storage.alternativeServerURLs
    activeServerURL = appDelegate.storage.loginCredentials?.serverUrl ?? ""
    serverURLs.append(activeServerURL)
  }

  func setAsActiveURL(url: String) {
    guard url != activeServerURL else { return }
    if let altIndex = appDelegate.storage.alternativeServerURLs.firstIndex(of: url),
       let currentCredentials = appDelegate.storage.loginCredentials {
      var altURLs = appDelegate.storage.alternativeServerURLs
      altURLs.remove(at: altIndex)
      altURLs.append(currentCredentials.serverUrl)
      appDelegate.storage.alternativeServerURLs = altURLs

      let newCredentials = LoginCredentials(
        serverUrl: url,
        username: currentCredentials.username,
        password: currentCredentials.password,
        backendApi: currentCredentials.backendApi
      )
      appDelegate.storage.loginCredentials = newCredentials
      appDelegate.backendApi.provideCredentials(credentials: newCredentials)
    }
    reload()
  }

  func deleteURL(url: String) {
    guard url != activeServerURL else { return }
    if let altIndex = appDelegate.storage.alternativeServerURLs.firstIndex(of: url) {
      var altURLs = appDelegate.storage.alternativeServerURLs
      altURLs.remove(at: altIndex)
      appDelegate.storage.alternativeServerURLs = altURLs
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
              Image.checkmark
            }
          }
          .id(url)
          .deleteDisabled(url == activeServerURL)
          .onTapGesture {
            setAsActiveURL(url: url)
          }
        }
        .onDelete { indexSet in
          guard let index = indexSet.first else { return }
          deleteURL(url: serverURLs[index])
          serverURLs.remove(atOffsets: indexSet)
        }
        .onChange(of: selection) { newSelection in
          #if targetEnvironment(macCatalyst)
            // Disable selection of the active element
            if newSelection == activeServerURL {
              selection = nil
            }
          #else
            // Disable selection of all elements on iOS
            selection = nil
          #endif
        }
      }
      #if targetEnvironment(macCatalyst)
      .listStyle(.plain)
      .border(Color.separator, width: 1.0)
      #endif
    }
    #if targetEnvironment(macCatalyst)
    .formSheet(isPresented: $isAddDialogVisible) {
      AlternativeURLAddDialogView(
        isVisible: $isAddDialogVisible,
        activeServerURL: $activeServerURL,
        serverURLs: $serverURLs
      )
      .frame(width: 400, height: 260)
      .environment(\.managedObjectContext, appDelegate.storage.main.context)
    }
    .background {
      Color.systemBackground
    }
    .listToolbar {
      Button(action: {
        withPopupAnimation { isAddDialogVisible = true }
      }) {
        Image.plus
      }
      .buttonStyle(BorderlessButtonStyle())
      .tint(Color(uiColor: appDelegate.storage.settings.themePreference.asColor))
      Button(action: {
        guard let selection = selection,
              let index = serverURLs.firstIndex(of: selection) else { return }
        deleteURL(url: selection)
        serverURLs.remove(at: index)
      }) {
        Image.minus
      }
      .buttonStyle(BorderlessButtonStyle())
      .tint(Color(uiColor: appDelegate.storage.settings.themePreference.asColor))
    }
    #else
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
              Image.plus
            }
          }
        }
    #endif
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
