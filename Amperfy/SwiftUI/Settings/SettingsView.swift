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

enum NavigationTarget: String, CaseIterable {
    case general = "general"
    case displayAndInteraction = "displayAndInteraction"
    case server = "server"
    case library = "library"
    case player = "player"
    case swipe = "swipe"
    case artwork = "artwork"
    case support = "support"
    case license = "license"
    case xcallback = "xcallback"
    #if DEBUG
    case developer = "developer"
    #endif

    func view() -> any View {
        switch self {
        case .general: SettingsView()
        case .displayAndInteraction: DisplaySettingsView()
        case .server: ServerSettingsView()
        case .library: LibrarySettingsView()
        case .player: PlayerSettingsView()
        case .swipe: SwipeSettingsView()
        case .artwork: ArtworkSettingsView()
        case .support: SupportSettingsView()
        case .license: LicenseSettingsView()
        case .xcallback: XCallbackURLsSetttingsView()
        #if DEBUG
        case .developer: DeveloperView()
        #endif
        }
    }

    var displayName: String {
        switch self {
        case .general: "General"
        case .displayAndInteraction: "Display & Interaction"
        case .server: "Server"
        case .library: "Library"
        case .player: "Player, Stream & Scrobble"
        case .swipe: "Swipe"
        case .artwork: "Artwork"
        case .support: "Support"
        case .license: "License"
        case .xcallback: "X-Callback-URL Documentation"
        #if DEBUG
        case .developer: "Developer"
        #endif
        }
    }
    
    var icon: UIImage {
        let img = switch self {
        case .general: UIImage(systemName: "gear")
        case .displayAndInteraction: UIImage(systemName: "display")
        case .server: UIImage(systemName: "server.rack")
        case .library: UIImage(systemName: "music.note.house.fill")
        case .player: UIImage(systemName: "play.circle.fill")
        case .swipe: UIImage(systemName: "arrow.right.circle.fill")
        case .artwork: UIImage(systemName: "photo.fill")
        case .support: UIImage(systemName: "person.circle")
        case .license: UIImage(systemName: "doc.fill")
        case .xcallback: UIImage(systemName: "arrowshape.turn.up.backward.circle.fill")
        #if DEBUG
        case .developer: UIImage(systemName: "hammer.circle.fill")
        #endif
        }
        return img!
    }

    #if targetEnvironment(macCatalyst)
    var toolbarIdentifier: NSToolbarItem.Identifier { return NSToolbarItem.Identifier(self.rawValue) }

    func hostingController(settings: Settings, managedObjectContext: NSManagedObjectContext) -> UIHostingController<AnyView> {
        return UIHostingController(
            rootView: AnyView(
                self.view()
                    .environmentObject(settings)
                    .environment(\.managedObjectContext, managedObjectContext)
            )
        )
    }
    #endif
}

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

                #if !targetEnvironment(macCatalyst)
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
