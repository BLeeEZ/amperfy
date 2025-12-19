//
//  UpdatePasswordView.swift
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

// MARK: - UpdatePasswordView

struct UpdatePasswordView: View {
  @Binding
  var isVisible: Bool
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

  func updatePassword() {
    resetStatus()
    let newPassword = passwordInput
    guard let activeAccountInfo = settings.activeAccountInfo,
          var loginCredentials = appDelegate.storage.settings.accounts
          .getSetting(activeAccountInfo).read
          .loginCredentials,
          !newPassword.isEmpty else {
      errorMsg = "Please provide the new password."
      return
    }
    isValidating = true
    loginCredentials.changePasswordAndHash(password: newPassword)
    Task { @MainActor in
      do {
        try await appDelegate.getMeta(activeAccountInfo).backendApi
          .isAuthenticationValid(credentials: loginCredentials)
        appDelegate.storage.settings.accounts.updateSetting(activeAccountInfo) { accountSettings in
          accountSettings.loginCredentials = loginCredentials
        }
        appDelegate.getMeta(activeAccountInfo).backendApi
          .provideCredentials(credentials: loginCredentials)
        successMsg = "Password updated!"
      } catch {
        errorMsg = "Authentication failed! Password has not been updated."
      }
      isValidating = false
    }
  }

  var body: some View {
    ZStack {
      List {
        Section {
          VStack {
            VStack(spacing: 20) {
              Text("Update Password").font(.title2).fontWeight(.bold).padding(.all, 10)

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
                SecureField("Change account password...", text: $passwordInput)
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
              Button(action: { updatePassword() }) {
                HStack {
                  Spacer()
                  Text("OK")
                  Spacer()
                }
              }
              .buttonStyle(DefaultButtonStyle())
              .disabled(isValidating)
            }
            .padding([.top], 8)
          }
        }
        #if targetEnvironment(macCatalyst) /// ok
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

// MARK: - UpdatePasswordView_Previews

struct UpdatePasswordView_Previews: PreviewProvider {
  @State
  static var isVisible = true

  static var previews: some View {
    UpdatePasswordView(isVisible: $isVisible)
  }
}
