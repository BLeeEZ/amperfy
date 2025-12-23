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
  @State
  var isShowResyncLibraryAlert = false
  @EnvironmentObject
  var settings: Settings

  func setThemePreference(preference: ThemePreference) {
    settings.themePreference = preference
    appDelegate.setAppTheme(color: preference.asColor)
    appDelegate.applyAppThemeToAlreadyLoadedViews()
  }

  private func resyncLibrary(accountInfo: AccountInfo) {
    appDelegate.closeAllButActiveMainTabs()
    if appDelegate.storage.settings.accounts.allAccounts.count <= 1 {
      appDelegate.stopForInit()
    }

    let meta = appDelegate.getMeta(accountInfo)
    meta.stopManager()
    appDelegate.resetMeta(accountInfo)

    // reset quick actions
    appDelegate.quickActionsManager.configureQuickActions()
    appDelegate.configureMainMenu()

    appDelegate.storage.settings.user.isOfflineMode = false
    let account = appDelegate.storage.main.library.getAccount(info: accountInfo)
    appDelegate.player.logout(account: account)
    let syncVC = AppStoryboard.Main.segueToSync(account: account)
    syncVC.modalPresentationStyle = .formSheet
    AppDelegate.mainSceneDelegate?.window?.rootViewController?.dismiss(animated: false)
    AppDelegate.mainSceneDelegate?.window?.rootViewController?.present(syncVC, animated: true)
  }

  private func logout(accountInfo: AccountInfo) {
    appDelegate.closeAllButActiveMainTabs()
    if appDelegate.storage.settings.accounts.allAccounts.count <= 1 {
      appDelegate.stopForInit()
    }

    let meta = appDelegate.getMeta(accountInfo)
    meta.stopManager()
    appDelegate.resetMeta(accountInfo)

    // delete cached files
    CacheFileManager.shared.deleteAccountCache(accountInfo: accountInfo)
    // reset login credentials -> at new start the login view is presented to auth and resync library
    appDelegate.storage.settings.accounts.logout(accountInfo)
    appDelegate.notificationHandler.post(name: .accountDeleted, object: nil, userInfo: nil)
    appDelegate.notificationHandler.post(name: .accountActiveChanged, object: nil, userInfo: nil)

    // reset quick actions
    appDelegate.quickActionsManager.configureQuickActions()
    appDelegate.configureMainMenu()

    appDelegate.storage.settings.user.isOfflineMode = false
    let account = appDelegate.storage.main.library.getAccount(info: accountInfo)
    appDelegate.player.logout(account: account)
    if let newActiveAccountInfo = appDelegate.storage.settings.accounts.active {
      let newActiveAccount = appDelegate.storage.main.library.getAccount(info: newActiveAccountInfo)
      appDelegate.closeAllButActiveMainTabs()
      appDelegate
        .setAppTheme(
          color: appDelegate.storage.settings.accounts.getSetting(newActiveAccountInfo)
            .read.themePreference.asColor
        )
      appDelegate.applyAppThemeToAlreadyLoadedViews()
      guard let mainScene = AppDelegate.mainSceneDelegate else { return }
      mainScene
        .replaceMainRootViewController(
          vc: AppStoryboard.Main
            .segueToMainWindow(account: newActiveAccount)
        )
    } else {
      // No other account: Behave like initial App start
      // force resync after login
      appDelegate.storage.settings.app.isLibrarySynced = false
      let loginVC = AppStoryboard.Main.segueToLogin()
      AppDelegate.mainSceneDelegate?.replaceMainRootViewController(vc: loginVC)
    }
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
            SettingsButtonRow(title: "Resync Library") {
              isShowResyncLibraryAlert = true
            }.alert(isPresented: $isShowResyncLibraryAlert) {
              Alert(
                title: Text("Resync Library"),
                message: Text(
                  "This will reset your local library and start syncing again from the server. Your downloaded files will remain on this device.\n\nDo you want to resync your library?"
                ),
                primaryButton: .destructive(Text("Resync")) {
                  resyncLibrary(accountInfo: activeAccountInfo)
                },
                secondaryButton: .cancel()
              )
            }
          }

          SettingsSection {
            SettingsButtonRow(title: "Logout", actionType: .destructive) {
              isShowLogoutAlert = true
            }
            .alert(isPresented: $isShowLogoutAlert) {
              Alert(
                title: Text("Logout"),
                message: Text(
                  "Logging out will sign you out of the current account. Your login credentials will be removed, and all downloaded files for this account will be deleted.\n\nDo you want to log out?"
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
