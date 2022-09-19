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

struct SettingsView: View {
    
    @EnvironmentObject private var settings: Settings
    
    #if false
    func resetAppData() {
        // ask if user is sure
        self.appDelegate.player.stop()
        self.appDelegate.scrobbleSyncer.stopAndWait()
        self.appDelegate.artworkDownloadManager.stopAndWait()
        self.appDelegate.playableDownloadManager.stopAndWait()
        self.appDelegate.storage.main.context.reset()
        self.appDelegate.storage.loginCredentials = nil
        self.appDelegate.storage.main.library.cleanStorage()
        self.appDelegate.storage.isLibrarySyncInfoReadByUser = false
        self.appDelegate.storage.isLibrarySynced = false
        //self.deleteViewControllerCaches()
        self.appDelegate.reinit()
        //self.performSegue(withIdentifier: Segues.toLogin.rawValue, sender: nil)
    }
    #endif
    
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
                
                #if false
                Section() {
                    Button(action: { resetAppData() }) {
                        Text("Reset App Data")
                            .foregroundColor(.red)
                    }
                }
                #endif
            }
            .listStyle(GroupedListStyle())
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
    }
}
