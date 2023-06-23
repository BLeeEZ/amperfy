//
//  LibrarySettingsView.swift
//  Amperfy
//
//  Created by Maximilian Bauer on 15.09.22.
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

struct LibrarySettingsView: View {
    
    @EnvironmentObject private var settings: Settings
    
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    @State var playlistCount = 0
    @State var artistCount = 0
    @State var albumCount = 0
    @State var songCount = 0
    @State var podcastCount = 0
    @State var podcastEpisodeCount = 0
    @State var albumWithSyncedSongsCount = 0
    @State var cachedSongCount = 0
    @State var cachedPodcastEpisodesCount = 0
    @State var completeCacheSize = ""
    @State var cacheSizeLimit = ""
    @State var cacheSelection = ["0", " MB"]
    @State var autoSyncProgressText = ""
    
    @State var isShowDeleteCacheAlert = false
    @State var isShowDownloadSongsAlert = false
    @State var isShowResyncLibraryAlert = false
    
    let byteValues = (stride(from: 0, through: 19, by: 1).map({$0.description}))+(stride(from: 20, through: 970, by: 25).map({$0.description}))
    
    private func updateValues() {
        appDelegate.storage.async.perform { asyncCompanion in
            self.playlistCount = asyncCompanion.library.playlistCount
            self.artistCount = asyncCompanion.library.artistCount
            self.albumCount = asyncCompanion.library.albumCount
            self.podcastCount = asyncCompanion.library.podcastCount
            self.podcastEpisodeCount = asyncCompanion.library.podcastEpisodeCount
            self.songCount = asyncCompanion.library.songCount
            self.albumWithSyncedSongsCount = asyncCompanion.library.albumWithSyncedSongsCount
            if albumCount < 1 {
                self.autoSyncProgressText = String(format: "%.1f", 0.0) + "%"
            } else {
                let progress = Float(albumWithSyncedSongsCount) * 100.0 / Float(albumCount)
                self.autoSyncProgressText = String(format: "%.1f", progress) + "%"
            }
            self.cachedSongCount = asyncCompanion.library.cachedSongCount
            self.cachedPodcastEpisodesCount = asyncCompanion.library.cachedPodcastEpisodeCount
            self.completeCacheSize = asyncCompanion.library.cachedPlayableSizeInByte.asByteString
            let cacheSize = Int64(settings.cacheSizeLimit)
            self.cacheSizeLimit = cacheSize > 0 ? cacheSize.asByteString : "No Limit"
                                                                          
        }.catch { error in }
    }
    
    private func resyncLibrary() {
        // reset library sync flag -> rest library at new start and continue with sync
        self.appDelegate.storage.isLibrarySynced = false
        self.appDelegate.restartByUser()
    }
    
    var body: some View {
        ZStack{
            List {
                Section(content: {
                    HStack {
                        Text("Playlists")
                        Spacer()
                        Text(playlistCount.description)
                            .foregroundColor(.secondary)
                    }
                    HStack {
                        Text("Artists")
                        Spacer()
                        Text(artistCount.description)
                            .foregroundColor(.secondary)
                    }
                    HStack {
                        Text("Albums")
                        Spacer()
                        Text(albumCount.description)
                            .foregroundColor(.secondary)
                    }
                    HStack {
                        Text("Songs")
                        Spacer()
                        Text(songCount.description)
                            .foregroundColor(.secondary)
                    }
                    HStack {
                        Text("Podcasts")
                        Spacer()
                        Text(podcastCount.description)
                            .foregroundColor(.secondary)
                    }
                    HStack {
                        Text("Podcast Episodes")
                        Spacer()
                        Text(podcastEpisodeCount.description)
                            .foregroundColor(.secondary)
                    }
                }, header: {
                })

                Section(content: {
                    HStack {
                        Text("Progress")
                        Spacer()
                        Text(autoSyncProgressText)
                            .foregroundColor(.secondary)
                    }
                }, header: {
                    Text("Background song sync")
                })
                
                Section(content: {
                    HStack {
                        Text("Latest Songs")
                        Spacer()
                        Toggle(isOn: $settings.isAutoCacheLatestSongs) {
                        }
                    }
                    HStack {
                        Text("Latest Podcast Episodes")
                        Spacer()
                        Toggle(isOn: $settings.isAutoCacheLatestPodcastEpisodes) {
                        }
                    }
                }, header: {
                    Text("Auto Cache")
                })
                
                Section(content: {
                    HStack {
                        Text("Cached Songs")
                        Spacer()
                        Text(cachedSongCount.description)
                            .foregroundColor(.secondary)
                    }
                    HStack {
                        Text("Cached Podcast Episodes")
                        Spacer()
                        Text(cachedPodcastEpisodesCount.description)
                            .foregroundColor(.secondary)
                    }
                    HStack {
                        Text("Complete Cache Size")
                        Spacer()
                        Text(completeCacheSize.description)
                            .foregroundColor(.secondary)
                    }
                    NavigationLink{
                        MultiPickerView(data: [("Size", byteValues),(" Bytes",[" MB"," GB"])], selection: $cacheSelection)
                    } label: {
                        
                        HStack {
                            Text("Cache Size Limit")
                            Spacer()
                            Text(cacheSizeLimit.description)
                                .foregroundColor(.secondary)
                        }
                    }
                    .onChange(of: cacheSelection, perform: { cacheString in
                        if cacheString[1] == ""{
                            settings.cacheSizeLimit = 0
                            cacheSelection = ["0"," KB"]
                        }
                        if let cacheInByte = (cacheString[0] + cacheString[1]).asByteCount{
                            settings.cacheSizeLimit = cacheInByte
                        }
                    })
                    
                    
                    Button(action: {
                        isShowDownloadSongsAlert = true
                    }) {
                        Text("Download all songs in library")
                    }
                    .alert(isPresented: $isShowDownloadSongsAlert) {
                        Alert(title: Text("Download all songs in library"), message: Text("This action will add all uncached songs in \"Library -> Songs\" to the download queue. High network traffic can be generated and device storage capacity will be taken. Continue?"),
                        primaryButton: .default(Text("OK")) {
                            let allSongsToDownload = self.appDelegate.storage.main.library.getSongsForCompleteLibraryDownload()
                            self.appDelegate.playableDownloadManager.download(objects: allSongsToDownload)
                        },secondaryButton: .cancel())
                    }
                    
                    Button(action: {
                        isShowDeleteCacheAlert = true
                    }) {
                        Text("Delete Cache")
                            .foregroundColor(.red)
                    }
                    .alert(isPresented: $isShowDeleteCacheAlert) {
                        Alert(title: Text("Delete Cache"), message: Text("Are you sure to delete all downloaded files from cache?"),
                        primaryButton: .destructive(Text("Delete")) {
                            self.appDelegate.player.stop()
                            self.appDelegate.playableDownloadManager.stopAndWait()
                            self.appDelegate.storage.main.library.deleteCompleteSongCache()
                            self.appDelegate.storage.main.library.saveContext()
                            self.appDelegate.playableDownloadManager.start()
                        },secondaryButton: .cancel())
                    }
                }, header: {
                    Text("Cache")
                })
                
                Section() {
                    Button(action: {
                        isShowResyncLibraryAlert = true
                    }) {
                        Text("Resync Library")
                            .foregroundColor(.red)
                    }
                    .alert(isPresented: $isShowResyncLibraryAlert) {
                        Alert(title: Text("Resync Library"), message: Text("This action resets your local library and starts the sync process from remote. Amperfy needs to restart to perform a resync.\n\nDo you want to resync your library and restart Amperfy?"),
                        primaryButton: .destructive(Text("Resync")) {
                            resyncLibrary()
                        },secondaryButton: .cancel())
                    }
                }
            }
        }
        .navigationTitle("Library")
        .onAppear {
            updateValues()
            appDelegate.userStatistics.visited(.settingsLibrary)
        }
        .onReceive(timer) { _ in
            updateValues()
        }
        .onDisappear {
            self.timer.upstream.connect().cancel()
        }
    }
}

struct LibrarySettingsView_Previews: PreviewProvider {
    @State static var settings = Settings()
    
    static var previews: some View {
        LibrarySettingsView().environmentObject(settings)
    }
}
