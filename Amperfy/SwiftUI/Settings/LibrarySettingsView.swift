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

import AmperfyKit
import SwiftUI

// MARK: - LibrarySettingsView

struct LibrarySettingsView: View {
  @EnvironmentObject
  private var settings: Settings

  let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
  let fileManager = CacheFileManager.shared

  @State
  var playlistCount = 0
  @State
  var artistCount = 0
  @State
  var albumCount = 0
  @State
  var songCount = 0
  @State
  var podcastCount = 0
  @State
  var podcastEpisodeCount = 0
  @State
  var albumWithSyncedSongsCount = 0
  @State
  var cachedSongCount = 0
  @State
  var cachedPodcastEpisodesCount = 0
  @State
  var completeCacheSize = ""
  @State
  var cacheSizeLimit = ""
  @State
  var cacheSelection = ["0", " MB"]
  @State
  var autoSyncProgressText = ""

  @State
  var isShowDeleteCacheAlert = false
  @State
  var isShowDownloadSongsAlert = false
  @State
  var isShowResyncLibraryAlert = false

  let byteValues = (
    stride(from: 0, through: 20, by: 1).map { $0.description } +
      stride(from: 25, through: 50, by: 5).map { $0.description } +
      stride(from: 60, through: 100, by: 10).map { $0.description } +
      stride(from: 110, through: 975, by: 25).map { $0.description }
  )

  private func updateValues() {
    Task { @MainActor in do {
      let accountObjectId = appDelegate.account.managedObject.objectID
      playlistCount = try await appDelegate.storage.async.performAndGet { asyncCompanion in
        let accountAsync = Account(
          managedObject: asyncCompanion.context
            .object(with: accountObjectId) as! AccountMO
        )
        return asyncCompanion.library.getPlaylistCount(for: accountAsync)
      }
      artistCount = try await appDelegate.storage.async.performAndGet { asyncCompanion in
        let accountAsync = Account(
          managedObject: asyncCompanion.context
            .object(with: accountObjectId) as! AccountMO
        )
        return asyncCompanion.library.getArtistCount(for: accountAsync)
      }
      albumCount = try await appDelegate.storage.async.performAndGet { asyncCompanion in
        let accountAsync = Account(
          managedObject: asyncCompanion.context
            .object(with: accountObjectId) as! AccountMO
        )
        return asyncCompanion.library.getAlbumCount(for: accountAsync)
      }
      podcastCount = try await appDelegate.storage.async.performAndGet { asyncCompanion in
        let accountAsync = Account(
          managedObject: asyncCompanion.context
            .object(with: accountObjectId) as! AccountMO
        )
        return asyncCompanion.library.getPodcastCount(for: accountAsync)
      }
      podcastEpisodeCount = try await appDelegate.storage.async.performAndGet { asyncCompanion in
        let accountAsync = Account(
          managedObject: asyncCompanion.context
            .object(with: accountObjectId) as! AccountMO
        )
        return asyncCompanion.library.getPodcastEpisodeCount(for: accountAsync)
      }
      songCount = try await appDelegate.storage.async.performAndGet { asyncCompanion in
        let accountAsync = Account(
          managedObject: asyncCompanion.context
            .object(with: accountObjectId) as! AccountMO
        )
        return asyncCompanion.library.getSongCount(for: accountAsync)
      }
      albumWithSyncedSongsCount = try await appDelegate.storage.async
        .performAndGet { asyncCompanion in
          let accountAsync = Account(
            managedObject: asyncCompanion.context
              .object(with: accountObjectId) as! AccountMO
          )
          return asyncCompanion.library.getAlbumWithSyncedSongsCount(for: accountAsync)
        }

      if albumCount < 1 {
        autoSyncProgressText = String(format: "%.1f", 0.0) + "%"
      } else {
        let progress = Float(albumWithSyncedSongsCount) * 100.0 / Float(albumCount)
        autoSyncProgressText = String(format: "%.1f", progress) + "%"
      }

      cachedSongCount = try await appDelegate.storage.async.performAndGet { asyncCompanion in
        let accountAsync = Account(
          managedObject: asyncCompanion.context
            .object(with: accountObjectId) as! AccountMO
        )
        return asyncCompanion.library.getCachedSongCount(for: accountAsync)
      }
      cachedPodcastEpisodesCount = try await appDelegate.storage.async
        .performAndGet { asyncCompanion in
          let accountAsync = asyncCompanion.library.getAccount(managedObjectId: accountObjectId)
          return asyncCompanion.library.getCachedPodcastEpisodeCount(for: accountAsync)
        }
      completeCacheSize = try await appDelegate.storage.async.performAndGet { asyncCompanion in
        let accountAsync = asyncCompanion.library.getAccount(managedObjectId: accountObjectId)
        let playableByteSize = fileManager.getPlayableCacheSize(for: accountAsync.info)
        return (playableByteSize > 1_000_000) ? playableByteSize.asByteString : Int64(0)
          .asByteString
      }

      let curCacheSizeLimit = Int64(settings.cacheSizeLimit)
      cacheSizeLimit = curCacheSizeLimit > 0 ? curCacheSizeLimit.asByteString : "No Limit"
      cacheSelection = curCacheSizeLimit > 0 ? [
        curCacheSizeLimit.asByteString.components(separatedBy: " ")[0],
        " " + curCacheSizeLimit.asByteString.components(separatedBy: " ")[1]
      ] : ["0", " MB"]
    } catch {
      // do nothing
    }}
  }

  private func resyncLibrary() {
    appDelegate.storage.settings.user.isOfflineMode = false
    // reset library sync flag -> rest library at new start and continue with sync
    appDelegate.storage.settings.app.isLibrarySynced = false
    // reset quick actions
    appDelegate.quickActionsManager.configureQuickActions()
    appDelegate.restartByUser()
  }

  var body: some View {
    ZStack {
      SettingsList {
        SettingsSection(content: {
          SettingsRow(title: "Playlists") {
            SecondaryText(playlistCount.description)
          }
          SettingsRow(title: "Artists") {
            SecondaryText(artistCount.description)
          }
          SettingsRow(title: "Albums") {
            SecondaryText(albumCount.description)
          }
          SettingsRow(title: "Songs") {
            SecondaryText(songCount.description)
          }
          SettingsRow(title: "Podcasts") {
            SecondaryText(podcastCount.description)
          }
          SettingsRow(title: "Podcast Episodes") {
            SecondaryText(podcastEpisodeCount.description)
          }
          SettingsRow(title: "Initial Sync") {
            SecondaryText(
              appDelegate.storage.settings.accounts.activeSettings.read
                .initialSyncCompletionStatus.description
            )
          }
        })

        let progressTitle = "Progress"

        SettingsSection(content: {
          SettingsRow(title: progressTitle) {
            SecondaryText(autoSyncProgressText)
          }
        }, header: "Background song sync")

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

        SettingsSection(content: {
          let changeHandler: ([String], [String]) -> () = { oldCacheString, newCacheString in
            if newCacheString[1] == "" {
              settings.cacheSizeLimit = 0
              cacheSelection = ["0", " MB"]
            }
            if let cacheInByte = (newCacheString[0] + newCacheString[1]).asByteCount {
              settings.cacheSizeLimit = cacheInByte
            }
          }

          SettingsRow(title: "Cached Songs") { SecondaryText(cachedSongCount.description) }
          SettingsRow(title: "Cached Podcast Episodes") {
            SecondaryText(cachedPodcastEpisodesCount.description)
          }
          SettingsRow(title: "Complete Cache Size") {
            SecondaryText(completeCacheSize.description)
          }

          #if targetEnvironment(macCatalyst) // ok
            // We can not present the picker in wheel style on macOS. It is not supported.
            // Instead, we use a menu style picker without a navigation link.
            MultiPickerView(
              data: [("Cache Size Limit", byteValues), ("", [" MB", " GB"])],
              selection: $cacheSelection
            )
            .onChange(of: cacheSelection, changeHandler)
          #else
            NavigationLink {
              MultiPickerView(
                data: [("Size", byteValues), (" Bytes", [" MB", " GB"])],
                selection: $cacheSelection
              )
              .navigationTitle("Cache Size Limit")
            } label: {
              SettingsRow(title: "Cache Size Limit") {
                SecondaryText(cacheSizeLimit.description)
              }
            }
            .onChange(of: cacheSelection, changeHandler)
          #endif

          SettingsButtonRow(title: "Download all songs in library") {
            isShowDownloadSongsAlert = true
          }
          .alert(isPresented: $isShowDownloadSongsAlert) {
            Alert(
              title: Text("Download all songs in library"),
              message: Text(
                "This will add all uncached songs in your library to the download queue. This may use a lot of data and storage. Continue?"
              ),
              primaryButton: .default(Text("OK")) {
                let allSongsToDownload = appDelegate.storage.main.library
                  .getSongsForCompleteLibraryDownload(for: appDelegate.account)
                appDelegate.getMeta(appDelegate.account.info).playableDownloadManager
                  .download(objects: allSongsToDownload)
              },
              secondaryButton: .cancel()
            )
          }

          SettingsButtonRow(
            title: "Delete downloaded songs and podcast episodes",
            actionType: .destructive
          ) {
            isShowDeleteCacheAlert = true
          }.alert(isPresented: $isShowDeleteCacheAlert) {
            Alert(
              title: Text("Delete Cache"),
              message: Text(
                "Are you sure you want to delete this account’s downloaded songs and podcast episodes?"
              ),
              primaryButton: .destructive(Text("Delete")) {
                appDelegate.player.stop()
                appDelegate.getMeta(appDelegate.account.info).playableDownloadManager.stop()
                appDelegate.storage.main.library
                  .deletePlayableCachePaths(for: appDelegate.account)
                appDelegate.storage.main.library.saveContext()
                fileManager.deletePlayableCache(accountInfo: appDelegate.account.info)
                appDelegate.getMeta(appDelegate.account.info).playableDownloadManager.start()
              }, secondaryButton: .cancel()
            )
          }
        }, header: "Cache")

        SettingsSection {
          SettingsButtonRow(title: "Resync Library") {
            isShowResyncLibraryAlert = true
          }.alert(isPresented: $isShowResyncLibraryAlert) {
            Alert(
              title: Text("Resync Library"),
              message: Text(
                "This action resets your local library and starts the sync process from remote. Amperfy needs to restart to perform a resync.\n\nDo you want to resync your library and restart Amperfy?"
              ),
              primaryButton: .destructive(Text("Resync")) {
                resyncLibrary()
              },
              secondaryButton: .cancel()
            )
          }
        }
      }
    }
    .navigationTitle("Library")
    .navigationBarTitleDisplayMode(.inline)
    .onAppear {
      updateValues()
      appDelegate.userStatistics.visited(.settingsLibrary)
    }
    .onReceive(timer) { _ in
      updateValues()
    }
    .onDisappear {
      timer.upstream.connect().cancel()
    }
  }
}

// MARK: - LibrarySettingsView_Previews

struct LibrarySettingsView_Previews: PreviewProvider {
  @State
  static var settings = Settings()

  static var previews: some View {
    LibrarySettingsView().environmentObject(settings)
  }
}
