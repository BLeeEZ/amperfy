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
    
    var body: some View {
        NavigationView {
            List {
                Section() {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text(AppDelegate.version)
                            .foregroundColor(.secondary)
                    }
                    HStack {
                        Text("Build Number")
                        Spacer()
                        Text(AppDelegate.buildNumber)
                            .foregroundColor(.secondary)
                    }
                }
                
                Section(content: {
                    HStack {
                        Text("Offline Mode")
                        Spacer()
                        Toggle(isOn: $settings.isOfflineMode) {}
                    }
 
                }
                , footer: {
                    Text("Songs, podcasts and artworks will not be downloaded when you are offline. Searches are restricted to device only. Playlists will not be synced with the server.")
                })
                
                Section() {
                    NavigationLink(destination: SleepTimerView()) {
                        Text("Sleep Timer")
                    }
                }
                
                Section(content: {
                    HStack {
                        Text("Prevent Screen Lock")
                        Spacer()
                        Menu(settings.screenLockPreventionPreference.description) {
                            Button(ScreenLockPreventionPreference.never.description, action: screenLockPreventionOffPressed)
                            Button(ScreenLockPreventionPreference.always.description, action: screenLockPreventionOnPressed)
                            Button(ScreenLockPreventionPreference.onlyIfCharging.description, action: screenLockPreventionChargingPressed)
                        }
                    }
                })
                
                Section() {
                    NavigationLink(destination: DisplaySettingsView()) {
                        Text("Display")
                    }
                    NavigationLink(destination: ServerSettingsView()) {
                        Text("Server")
                    }
                    NavigationLink(destination: LibrarySettingsView()) {
                        Text("Library")
                    }
                    NavigationLink(destination: PlayerSettingsView()) {
                        Text("Player")
                    }
                    NavigationLink(destination: SwipeSettingsView()) {
                        Text("Swipe")
                    }
                    NavigationLink(destination: ArtworkSettingsView()) {
                        Text("Artwork")
                    }
                }
                
                Section() {
                    NavigationLink(destination: SupportSettingsView()) {
                        Text("Support")
                    }
                    NavigationLink(destination: LicenseSettingsView()) {
                        Text("License")
                    }
                    NavigationLink(destination: XCallbackURLsSetttingsView()) {
                        Text("X-Callback-URL Documentation")
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
    }
}
