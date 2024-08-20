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

import SwiftUI
import AmperfyKit

struct SettingsView: View {

    @EnvironmentObject private var settings: Settings

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

    func navigationLink(_ item: NavigationTarget) -> some View {
        NavigationLink(destination: AnyView(item.view())) {
            Text(item.displayName)
        }
    }

    var body: some View {
        NavigationView {
            List {
                SettingsSection {
                    SettingsRow(title: "Version") {
                        SecondaryText(AppDelegate.version)
                    }
                    SettingsRow(title: "Build Number") {
                        SecondaryText(AppDelegate.buildNumber)
                    }
                }

                SettingsSection(content: {
                    SettingsCheckBoxRow(label: "Offline Mode", isOn: $settings.isOfflineMode)
                }, footer:
                    "Songs, podcasts and artworks will not be downloaded when you are offline. Searches are restricted to device only. Playlists will not be synced with the server."
                )

                SettingsSection {
                    SettingsRow(title: "Prevent Screen Lock") {
                        Menu(settings.screenLockPreventionPreference.description) {
                            Button(ScreenLockPreventionPreference.never.description, action: screenLockPreventionOffPressed)
                            Button(ScreenLockPreventionPreference.always.description, action: screenLockPreventionOnPressed)
                            Button(ScreenLockPreventionPreference.onlyIfCharging.description, action: screenLockPreventionChargingPressed)
                        }
                    }
                }

                #if !targetEnvironment(macCatalyst)
                SettingsSection {
                    navigationLink(.displayAndInteraction)
                    navigationLink(.server)
                    navigationLink(.library)
                    navigationLink(.player)
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
            #if !targetEnvironment(macCatalyst)
            .navigationTitle("Settings")
            #endif
        }.navigationViewStyle(.stack)
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
    }
}
