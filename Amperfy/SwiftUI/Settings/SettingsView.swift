//
//  SettingsView.swift
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

// MARK: - SettingsView

struct SettingsView: View {
  @EnvironmentObject
  private var settings: Settings

  func screenLockPreventionOffPressed() {
    settings.screenLockPreventionPreference = .never
    UIDevice.current.isBatteryMonitoringEnabled = false
    appDelegate.configureLockScreenPrevention()
  }

  func screenLockPreventionOnPressed() {
    settings.screenLockPreventionPreference = .always
    UIDevice.current.isBatteryMonitoringEnabled = false
    appDelegate.configureLockScreenPrevention()
  }

  func screenLockPreventionChargingPressed() {
    settings.screenLockPreventionPreference = .onlyIfCharging
    UIDevice.current.isBatteryMonitoringEnabled = true
    appDelegate.configureLockScreenPrevention()
  }

  /// On iPhone and iPad Settings is a sheet on the main window. The account switch and the sync
  /// after a login replace the main window's root, so the sheet is closed first and the action
  /// runs on the main window, as it did from the former account menu.
  func performOnMainWindow(_ action: @escaping (UIViewController?) -> ()) {
    let mainRoot = AppDelegate.mainSceneDelegate?.window?.rootViewController
    if let mainRoot, mainRoot.presentedViewController != nil {
      mainRoot.dismiss(animated: true) { action(mainRoot) }
    } else {
      action(mainRoot)
    }
  }

  func addAccountPressed() {
    performOnMainWindow { mainRoot in
      let loginVC = AppStoryboard.Main.segueToLogin()
      loginVC.modalPresentationStyle = .formSheet
      AppDelegate.topViewController(base: mainRoot)?.present(loginVC, animated: true)
    }
  }

  func accountRow(_ accountInfo: AccountInfo) -> some View {
    let accounts = appDelegate.storage.settings.accounts
    let credentials = accounts.getSetting(accountInfo).read.loginCredentials
    let isActive = (accountInfo == settings.activeAccountInfo)
    return Button {
      guard !isActive else { return }
      performOnMainWindow { _ in
        appDelegate.switchAccount(accountInfo: accountInfo)
      }
    } label: {
      HStack {
        Label {
          VStack(alignment: .leading) {
            Text(credentials?.username ?? "Unknown")
            if let url = credentials?.displayServerUrl {
              SecondaryText(url)
            }
          }
        } icon: {
          AmperfyImage.account.asImage
        }
        Spacer()
        if isActive {
          AmperfyImage.check.asImage
        }
      }
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
  }

  func navigationLink(_ item: NavigationTarget) -> some View {
    NavigationLink(value: item) {
      Text(item.displayName)
    }
  }

  var body: some View {
    let list =
      SettingsList {
        SettingsSection {
          ForEach(settings.accounts, id: \.self) { accountInfo in
            accountRow(accountInfo)
          }
          Button(action: addAccountPressed) {
            Label {
              Text("Add Account")
            } icon: {
              AmperfyImage.userCirclePlus.asImage
            }
          }
        }

        SettingsSection {
          SettingsRow(title: "Version") {
            SecondaryText(AppDelegate.version)
          }
          SettingsRow(title: "Build Number") {
            SecondaryText(AppDelegate.buildNumber)
          }
        }

        SettingsSection(
          content: {
            SettingsCheckBoxRow(title: "Offline Mode", isOn: $settings.isOfflineMode)
          },
          footer:
          "Songs, podcasts, and artworks won’t download offline. Searches are limited to the device, and playlists won’t sync with the server."
        )

        SettingsSection {
          SettingsRow(title: "Prevent Screen Lock") {
            Menu(settings.screenLockPreventionPreference.description) {
              Button(
                ScreenLockPreventionPreference.never.description,
                action: screenLockPreventionOffPressed
              )
              Button(
                ScreenLockPreventionPreference.always.description,
                action: screenLockPreventionOnPressed
              )
              Button(
                ScreenLockPreventionPreference.onlyIfCharging.description,
                action: screenLockPreventionChargingPressed
              )
            }
          }
        }

        #if !targetEnvironment(macCatalyst) // ok
          SettingsSection {
            navigationLink(.account)
            navigationLink(.displayAndInteraction)
            navigationLink(.library)
            navigationLink(.player)
            navigationLink(.equalizer)
            navigationLink(.swipe)
            navigationLink(.artwork)
          }

          SettingsSection {
            navigationLink(.support)
            navigationLink(.license)
            navigationLink(.xcallback)

            #if DEBUG
              navigationLink(.developer)
            #endif
          }
        #endif
      }

    #if targetEnvironment(macCatalyst) // ok
      ZStack {
        list
      }
      .navigationTitle("General")
      .navigationBarTitleDisplayMode(.inline)
    #else
      NavigationStack {
        list
          .navigationTitle("Settings")
          // All pushes in this stack must be value based. Mixing view based links
          // (NavigationLink(destination:)) with the value based links of the sub pages
          // results in a navigation loop.
          .navigationDestination(for: NavigationTarget.self) { item in
            AnyView(item.view())
          }
      }
    #endif
  }
}

// MARK: - SettingsView_Previews

struct SettingsView_Previews: PreviewProvider {
  static var previews: some View {
    SettingsView()
  }
}
