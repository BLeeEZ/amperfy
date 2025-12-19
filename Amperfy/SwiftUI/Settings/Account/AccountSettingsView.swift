//
//  AccountSettingsView.swift
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

// MARK: - AccountSettingsView

struct AccountSettingsView: View {
  let splitPercentage = 0.25

  @State
  var isPwUpdateDialogVisible = false
  @State
  var isShowLogoutAlert = false
  @EnvironmentObject
  var settings: Settings

  func setThemePreference(preference: ThemePreference) {
    settings.themePreference = preference
    appDelegate.setAppTheme(color: preference.asColor)

    // the following applies the tint color to already loaded views in all windows (UIKit)
    let windowScene = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
    let windows = windowScene.flatMap { $0.windows }

    for window in windows {
      for view in window.subviews {
        view.removeFromSuperview()
        window.addSubview(view)
      }
    }
  }

  private func logout(accountInfo: AccountInfo) {
    appDelegate.storage.settings.user.isOfflineMode = false
    // reset login credentials -> at new start the login view is presented to auth and resync library
    appDelegate.storage.settings.accounts.logout(accountInfo)
    // force resync after login
    appDelegate.storage.settings.app.isLibrarySynced = false
    // reset quick actions
    appDelegate.quickActionsManager.configureQuickActions()
    appDelegate.restartByUser()
  }

  var body: some View {
    ZStack {
      SettingsList {
        if let activeAccountInfo = settings.activeAccountInfo {
          SettingsSection {
            SettingsRow(title: "URL", orientation: .vertical, splitPercentage: splitPercentage) {
              SecondaryText(
                appDelegate.storage.settings.accounts.getSetting(settings.activeAccountInfo).read
                  .loginCredentials?.displayServerUrl ?? ""
              )
            }
            SettingsRow(
              title: "Username",
              orientation: .vertical,
              splitPercentage: splitPercentage
            ) {
              SecondaryText(
                appDelegate.storage.settings.accounts.getSetting(settings.activeAccountInfo).read
                  .loginCredentials?.username ?? ""
              )
            }
          }

          SettingsSection {
            SettingsRow(title: "Theme Color") {
              Menu(settings.themePreference.description) {
                Button(ThemePreference.blue.description) {
                  setThemePreference(preference: .blue)
                }
                Button(ThemePreference.green.description) {
                  setThemePreference(preference: .green)
                }
                Button(ThemePreference.red.description) {
                  setThemePreference(preference: .red)
                }
                Button(ThemePreference.yellow.description) {
                  setThemePreference(preference: .yellow)
                }
                Button(ThemePreference.orange.description) {
                  setThemePreference(preference: .orange)
                }
                Button(ThemePreference.purple.description) {
                  setThemePreference(preference: .purple)
                }
              }
            }
          }

          SettingsSection(content: {
            SettingsCheckBoxRow(
              title: "Newest Songs",
              isOn: $settings.isAutoCacheLatestSongs
            )
            SettingsCheckBoxRow(
              title: "Newest Podcast Episodes",
              isOn: $settings.isAutoCacheLatestPodcastEpisodes
            )
          }, header: "Auto Cache")

          SettingsSection(
            content: {
              SettingsCheckBoxRow(
                title: "Scrobble streamed Songs",
                isOn: $settings.isScrobbleStreamedItems
              )
            },
            footer: "Enable to scrobble all streamed songs, even if the server already marks them as played."
          )

          SettingsSection {
            SettingsRow(title: "Backend API", splitPercentage: splitPercentage) {
              Text(
                appDelegate.storage.settings.accounts.getSetting(settings.activeAccountInfo).read
                  .loginCredentials?
                  .backendApi.description ?? ""
              )
              .foregroundColor(.secondary)
              .help(
                appDelegate.storage.settings.accounts.getSetting(settings.activeAccountInfo).read
                  .loginCredentials?
                  .backendApi.description ?? ""
              )
            }

            SettingsRow(title: "Server API Version", splitPercentage: splitPercentage) {
              Text(appDelegate.getMeta(activeAccountInfo).backendApi.serverApiVersion)
                .foregroundColor(.secondary)
                .help(appDelegate.getMeta(activeAccountInfo).backendApi.serverApiVersion)
            }
            SettingsRow(title: "Client API Version", splitPercentage: splitPercentage) {
              Text(appDelegate.getMeta(activeAccountInfo).backendApi.clientApiVersion)
                .foregroundColor(.secondary)
                .help(appDelegate.getMeta(activeAccountInfo).backendApi.clientApiVersion)
            }
          }

          SettingsSection {
            NavigationLink(destination: ServerURLsSettingsView()) {
              Text("Manage Server URLs")
            }
          }

          SettingsSection {
            SettingsButtonRow(title: "Update Password") {
              withPopupAnimation { isPwUpdateDialogVisible = true }
            }
            SettingsButtonRow(title: "Logout", actionType: .destructive) {
              isShowLogoutAlert = true
            }
            .alert(isPresented: $isShowLogoutAlert) {
              Alert(
                title: Text("Logout"),
                message: Text(
                  "This action leads to a user logout. Login credentials of the current user are removed. Amperfy needs to restart to perform a logout. After a successful login a resync of the remote library is neccessary.\n\nDo you want to logout and restart Amperfy?"
                ),
                primaryButton: .destructive(Text("Logout")) {
                  logout(accountInfo: activeAccountInfo)
                },
                secondaryButton: .cancel()
              )
            }
          }
        } else {
          // User is not logged in yet
          SettingsSection {
            SecondaryText("You aren't logged in yet.")
          }
        }
      }
    }
    .navigationTitle("Account")
    .navigationBarTitleDisplayMode(.inline)
    .sheet(isPresented: $isPwUpdateDialogVisible) {
      UpdatePasswordView(isVisible: $isPwUpdateDialogVisible)
    }
  }
}

// MARK: - AccountSettingsView_Previews

struct AccountSettingsView_Previews: PreviewProvider {
  static var previews: some View {
    AccountSettingsView()
  }
}
