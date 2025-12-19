//
//  AlternativeURLAddDialogView.swift
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

// MARK: - AlternativeURLAddDialogView

struct AlternativeURLAddDialogView: View {
  @Binding
  var isVisible: Bool
  @Binding
  var activeServerURL: String
  @Binding
  var serverURLs: [String]

  @State
  var urlInput: String = ""
  @State
  var usernameInput: String = ""
  @State
  var passwordInput: String = ""

  @State
  var isValidating = false
  @State
  var errorMsg: String = ""
  @State
  var successMsg: String = ""
  @EnvironmentObject
  var settings: Settings

  func resetStatus() {
    isValidating = false
    errorMsg = ""
    successMsg = ""
  }

  func handleAdd() {
    resetStatus()
    guard let activeAccountInfo = settings.activeAccountInfo else { return }
    let newAltUrl = urlInput.trimmingCharacters(in: .whitespacesAndNewlines)
    let password = passwordInput
    let username = appDelegate.storage.settings.accounts.getSetting(activeAccountInfo).read
      .loginCredentials?
      .username ?? ""
    guard !newAltUrl.isEmpty,
          !username.isEmpty,
          !password.isEmpty,
          let activeCred = appDelegate.storage.settings.accounts
          .getSetting(settings.activeAccountInfo).read
          .loginCredentials
    else {
      errorMsg = "Inputs are not valid."
      return
    }

    guard !serverURLs.contains(where: { $0 == newAltUrl }) else {
      errorMsg = "Provided URL is already in URLs list."
      return
    }

    guard newAltUrl.isHyperTextProtocolProvided else {
      errorMsg = "Please provide either 'https://' or 'http://' in your server URL."
      return
    }

    var credentialsToCheck = activeCred
    credentialsToCheck.activeBackendServerUrl = newAltUrl
    credentialsToCheck.alternativeServerURLs.append(newAltUrl)

    isValidating = true
    Task { @MainActor in
      do {
        try await appDelegate.getMeta(activeAccountInfo).backendApi
          .isAuthenticationValid(credentials: credentialsToCheck)
        appDelegate.storage.settings.accounts
          .updateSetting(activeAccountInfo) { accountSettings in
            accountSettings.loginCredentials = credentialsToCheck
          }
        appDelegate.getMeta(activeAccountInfo).backendApi
          .provideCredentials(credentials: credentialsToCheck)
        activeServerURL = credentialsToCheck.activeBackendServerUrl
        serverURLs = credentialsToCheck.availableServerURLs
        successMsg = "Alternative URL added."
      } catch {
        errorMsg =
          "Alternative URL could not be verified! Authentication failed! Alternative URL has not been added."
      }
      isValidating = false
    }
  }

  var body: some View {
    ZStack {
      SettingsList {
        Section {
          VStack {
            VStack(spacing: 20) {
              Text("Add alternative URL").font(.title2).fontWeight(.bold).padding(.all, 10)

              Text(
                "The URL must reach the same server. Otherwise library inconsistencies will occur."
              )

              if !successMsg.isEmpty {
                InfoBannerView(message: successMsg, color: .success)
              }
              if !errorMsg.isEmpty {
                InfoBannerView(message: errorMsg, color: .error)
              }
              if isValidating {
                ProgressView("Please wait...")
              }

              VStack(spacing: 5) {
                TextField("https://localhost/ampache", text: $urlInput)
                  .textFieldStyle(.roundedBorder)
                TextField(
                  appDelegate.storage.settings.accounts.getSetting(settings.activeAccountInfo).read
                    .loginCredentials?
                    .username ?? "",
                  text: $usernameInput
                )
                .disabled(true)
                .textFieldStyle(.roundedBorder)
                SecureField("Password", text: $passwordInput)
                  .textFieldStyle(.roundedBorder)
              }
            }

            HStack {
              Button(action: { isVisible = false }) {
                HStack {
                  Spacer()
                  Text("Cancel")
                    .fontWeight(.semibold)
                  Spacer()
                }
              }
              .buttonStyle(DefaultButtonStyle())
              Spacer()
              Button(action: { handleAdd() }) {
                HStack {
                  Spacer()
                  Text("Add")
                  Spacer()
                }
              }
              .buttonStyle(DefaultButtonStyle())
              .disabled(isValidating)
            }
            .padding([.top], 8)
          }
        }
        #if targetEnvironment(macCatalyst) // ok
        .listRowBackground(Color.clear)
        #else
        .padding()
        #endif
      }
      #if targetEnvironment(macCatalyst) // ok
      .listStyle(.plain)
      #endif
    }
    .onAppear {
      resetStatus()
    }
  }
}

// MARK: - AlternativeURLAddDialogView_Previews

struct AlternativeURLAddDialogView_Previews: PreviewProvider {
  @State
  static var isVisible = true
  @State
  static var activeServerURL: String = ""
  @State
  static var serverURLs = [String]()

  static var previews: some View {
    AlternativeURLAddDialogView(
      isVisible: $isVisible,
      activeServerURL: $activeServerURL,
      serverURLs: $serverURLs
    )
  }
}
