//
//  ServerSettingsView.swift
//  Amperfy
//
//  Created by Maximilian Bauer on 14.09.22.
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

// MARK: - ServerSettingsView

struct ServerSettingsView: View {
  let splitPercentage = 0.25

  @State
  var isPwUpdateDialogVisible = false
  @State
  var isShowLogoutAlert = false

  private func logout() {
    appDelegate.storage.settings.isOfflineMode = false
    // reset login credentials -> at new start the login view is presented to auth and resync library
    appDelegate.storage.loginCredentials = nil
    // force resync after login
    appDelegate.storage.isLibrarySynced = false
    // reset quick actions
    appDelegate.quickActionsManager.configureQuickActions()
    appDelegate.restartByUser()
  }

  var body: some View {
    ZStack {
      SettingsList {
        SettingsSection {
          SettingsRow(title: "URL", orientation: .vertical, splitPercentage: splitPercentage) {
            SecondaryText(appDelegate.storage.loginCredentials?.serverUrl ?? "")
          }
          SettingsRow(title: "Username", orientation: .vertical, splitPercentage: splitPercentage) {
            SecondaryText(appDelegate.storage.loginCredentials?.username ?? "")
          }
        }

        SettingsSection {
          SettingsRow(title: "Backend API", splitPercentage: splitPercentage) {
            Text(appDelegate.storage.loginCredentials?.backendApi.description ?? "")
              .foregroundColor(.secondary)
              .help(appDelegate.storage.loginCredentials?.backendApi.description ?? "")
          }

          SettingsRow(title: "Server API Version", splitPercentage: splitPercentage) {
            Text(appDelegate.backendApi.serverApiVersion)
              .foregroundColor(.secondary)
              .help(appDelegate.backendApi.serverApiVersion)
          }
          SettingsRow(title: "Client API Version", splitPercentage: splitPercentage) {
            Text(appDelegate.backendApi.clientApiVersion)
              .foregroundColor(.secondary)
              .help(appDelegate.backendApi.clientApiVersion)
          }
        }

        SettingsSection {
          #if targetEnvironment(macCatalyst)
            SettingsRow(title: "Manage Server URLs", splitPercentage: splitPercentage) {
              ServerURLsSettingsView()
                .frame(width: 450, height: 150)
            }
            .frame(height: 150)
            .padding(.bottom, 10)
          #else
            NavigationLink(destination: ServerURLsSettingsView()) {
              Text("Manage Server URLs")
            }
          #endif
        }

        SettingsSection {
          SettingsButtonRow(title: "Account", label: "Update Password") {
            withPopupAnimation { isPwUpdateDialogVisible = true }
          }
          SettingsButtonRow(label: "Logout", actionType: .destructive) {
            isShowLogoutAlert = true
          }
          .alert(isPresented: $isShowLogoutAlert) {
            Alert(
              title: Text("Logout"),
              message: Text(
                "This action leads to a user logout. Login credentials of the current user are removed. Amperfy needs to restart to perform a logout. After a successful login a resync of the remote library is neccessary.\n\nDo you want to logout and restart Amperfy?"
              ),
              primaryButton: .destructive(Text("Logout")) {
                logout()
              },
              secondaryButton: .cancel()
            )
          }
        }
      }
    }
    .navigationTitle("Server")
    .navigationBarTitleDisplayMode(.inline)
    #if targetEnvironment(macCatalyst)
      .formSheet(isPresented: $isPwUpdateDialogVisible) {
        UpdatePasswordView(isVisible: $isPwUpdateDialogVisible)
          .frame(width: 400, height: 150)
          .environment(\.managedObjectContext, appDelegate.storage.main.context)
      }
    #else
      .sheet(isPresented: $isPwUpdateDialogVisible) {
          UpdatePasswordView(isVisible: $isPwUpdateDialogVisible)
        }
    #endif
  }
}

// MARK: - ServerSettingsView_Previews

struct ServerSettingsView_Previews: PreviewProvider {
  static var previews: some View {
    ServerSettingsView()
  }
}
