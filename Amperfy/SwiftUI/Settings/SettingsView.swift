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

// There is no way to hide the second navigationbar in catalyst
// That is why we recreate a navigation view with a HStack

enum NavigationTarget {
    case displayAndInteraction
    case server
    case library
    case player
    case swipe
    case artwork
    case support
    case license
    case xcallback
    case developer

    func view() -> any View {
        switch self {
        case .displayAndInteraction: DisplaySettingsView()
        case .server: ServerSettingsView()
        case .library: LibrarySettingsView()
        case .player: PlayerSettingsView()
        case .swipe: SwipeSettingsView()
        case .artwork: ArtworkSettingsView()
        case .support: SupportSettingsView()
        case .license: LicenseSettingsView()
        case .xcallback: XCallbackURLsSetttingsView()
        case .developer: DeveloperView()
        }
    }

    var name: String {
        switch self {
        case .displayAndInteraction: "Display & Interaction"
        case .server: "Server"
        case .library: "Library"
        case .player: "Player, Stream & Scrobble"
        case .swipe: "Swipe"
        case .artwork: "Artwork"
        case .support: "Support"
        case .license: "License"
        case .xcallback: "X-Callback-URL Documentation"
        case .developer: "Developer"
        }
    }
}

struct SettingsView: View {

    @EnvironmentObject private var settings: Settings

    @State private var detailedItem: NavigationTarget = .displayAndInteraction

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
        #if targetEnvironment(macCatalyst)
        HStack {
            Text(item.name)
            Spacer()
            Image(systemName: "chevron.right")
                .foregroundColor( detailedItem == item ? Color.white : nil )
        }
        .contentShape(Rectangle())
        .onTapGesture { detailedItem = item }
        .foregroundColor(detailedItem == item ? Color.white : nil)
        .listRowBackground(detailedItem == item ? Color.accentColor : nil)
        #else
        NavigationLink(destination: AnyView(item.view())) {
            Text(item.name)
        }
        #endif
    }

    var body: some View {
        let list =
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

                }, footer: {
                    Text("Songs, podcasts and artworks will not be downloaded when you are offline. Searches are restricted to device only. Playlists will not be synced with the server.")
                })

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
                    navigationLink(.displayAndInteraction)
                    navigationLink(.server)
                    navigationLink(.library)
                    navigationLink(.player)
                    navigationLink(.swipe)
                    navigationLink(.artwork)
                }

                Section() {
                    navigationLink(.support)
                    navigationLink(.license)
                    navigationLink(.xcallback)

                    #if true
                    navigationLink(.developer)
                    #endif
                }
            }

        #if targetEnvironment(macCatalyst)
        HStack(spacing: 2.0) {
            list
            AnyView(detailedItem.view())
        }
        .background(Color.separator)
        #else
        NavigationView {
            list.navigationTitle("Settings")
        }.navigationViewStyle(.stack)
        #endif
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
    }
}
