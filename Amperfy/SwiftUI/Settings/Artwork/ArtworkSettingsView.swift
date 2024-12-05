//
//  ArtworkSettingsView.swift
//  Amperfy
//
//  Created by Maximilian Bauer on 16.09.22.
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

struct ArtworkSettingsView: View {
    
    static let artworkNotCheckedThreshold = 10
    
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    let fileManager = CacheFileManager.shared
    
    @State var artworkNotCheckedCountText = ""
    @State var cachedArtworksCountText = ""
    
    @State var isShowDownloadArtworksAlert = false
    @State var isShowDeleteArtworksAlert = false

    func updateValues() {
        appDelegate.storage.async.perform { asyncCompanion in
            let artworkNotCheckedCount = asyncCompanion.library.artworkNotCheckedCount
            let artworkNotCheckedDisplayCount = artworkNotCheckedCount > Self.artworkNotCheckedThreshold ? artworkNotCheckedCount : 0
            self.artworkNotCheckedCountText = String(artworkNotCheckedDisplayCount)
            let cachedArtworkCount = asyncCompanion.library.cachedArtworkCount
                self.cachedArtworksCountText = String(cachedArtworkCount)
        }.catch { error in }
    }

    var body: some View {
        ZStack {
            SettingsList {
                SettingsSection {
                    SettingsRow(title: "Not checked Artworks") {
                        SecondaryText(artworkNotCheckedCountText)
                    }
                    SettingsRow(title: "Cached Artworks") {
                        SecondaryText(cachedArtworksCountText)
                    }
                    SettingsButtonRow(label: "Download all artworks in library") {
                        isShowDownloadArtworksAlert = true
                    }
                    .alert(isPresented: $isShowDownloadArtworksAlert) {
                        Alert(title: Text("Download all artworks in library"), message: Text("This action will add all uncached artworks to the download queue. With this action a lot network traffic can be generated and device storage capacity will be taken. Continue?"),
                        primaryButton: .default(Text("OK")) {
                            let allArtworksToDownload = self.appDelegate.storage.main.library.getArtworksForCompleteLibraryDownload()
                            self.appDelegate.artworkDownloadManager.download(objects: allArtworksToDownload)
                        },secondaryButton: .cancel())
                    }
                    SettingsButtonRow(label: "Delete all downloaded artworks") {
                        isShowDeleteArtworksAlert = true
                    }
                    .alert(isPresented: $isShowDeleteArtworksAlert) {
                        Alert(title: Text("Delete all downloaded artworks"), message: Text("This action will delete all downloaded artworks. Artworks embedded in song/podcast episode files will be kept. Continue?"),
                        primaryButton: .destructive(Text("Delete")) {
                            self.appDelegate.artworkDownloadManager.stop()
                            self.appDelegate.artworkDownloadManager.cancelDownloads()
                            self.appDelegate.artworkDownloadManager.clearFinishedDownloads()
                            self.appDelegate.storage.main.library.deleteRemoteArtworkCachePaths()
                            self.appDelegate.storage.main.library.saveContext()
                            self.fileManager.deleteRemoteArtworkCache()
                            self.appDelegate.artworkDownloadManager.start()
                        },secondaryButton: .cancel())
                    }
                }
                SettingsSection() {
                    #if targetEnvironment(macCatalyst)
                    SettingsRow(title: "Artwork Download Settings") {
                        ArtworkDownloadSettingsView()
                    }
                    SettingsRow(title: "Artwork Display Settings") {
                        ArtworkDisplaySettings()
                    }
                    #else
                    NavigationLink(destination: ArtworkDownloadSettingsView()) {
                        Text("Artwork Download Settings")
                    }
                    NavigationLink(destination: ArtworkDisplaySettings()) {
                        Text("Artwork Display Settings")
                    }
                    #endif
                }
            }
        }
        .navigationTitle("Artwork")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            updateValues()
        }
        .onReceive(timer) { _ in
            updateValues()
        }
        .onDisappear {
            self.timer.upstream.connect().cancel()
        }
    }
}

struct ArtworkSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        ArtworkSettingsView()
    }
}
