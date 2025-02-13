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

import AmperfyKit
import SwiftUI

// MARK: - ArtworkSettingsView

struct ArtworkSettingsView: View {
  nonisolated static let artworkNotCheckedThreshold = 10

  let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
  let fileManager = CacheFileManager.shared

  @State
  var artworkNotCheckedCountText = ""
  @State
  var cachedArtworksCountText = ""

  @State
  var isShowDownloadArtworksAlert = false
  @State
  var isShowDeleteArtworksAlert = false

  func updateValues() {
    Task { @MainActor in do {
      (artworkNotCheckedCountText, cachedArtworksCountText) = try await appDelegate.storage.async
        .performAndGet { asyncCompanion in
          let artworkNotCheckedCount = asyncCompanion.library.artworkNotCheckedCount
          let artworkNotCheckedDisplayCount = artworkNotCheckedCount > Self
            .artworkNotCheckedThreshold ? artworkNotCheckedCount : 0
          let cachedArtworkCount = asyncCompanion.library.cachedArtworkCount
          return (String(artworkNotCheckedDisplayCount), String(cachedArtworkCount))
        }
    } catch {
      // do nothing
    }}
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
            Alert(
              title: Text("Download all artworks in library"),
              message: Text(
                "This action will add all uncached artworks to the download queue. With this action a lot network traffic can be generated and device storage capacity will be taken. Continue?"
              ),
              primaryButton: .default(Text("OK")) {
                let allArtworksToDownload = appDelegate.storage.main.library
                  .getArtworksForCompleteLibraryDownload()
                appDelegate.artworkDownloadManager.download(objects: allArtworksToDownload)
              },
              secondaryButton: .cancel()
            )
          }
          SettingsButtonRow(label: "Delete all downloaded artworks") {
            isShowDeleteArtworksAlert = true
          }
          .alert(isPresented: $isShowDeleteArtworksAlert) {
            Alert(
              title: Text("Delete all downloaded artworks"),
              message: Text(
                "This action will delete all downloaded artworks. Artworks embedded in song/podcast episode files will be kept. Continue?"
              ),
              primaryButton: .destructive(Text("Delete")) {
                appDelegate.artworkDownloadManager.stop()
                appDelegate.artworkDownloadManager.cancelDownloads()
                appDelegate.artworkDownloadManager.clearFinishedDownloads()
                appDelegate.storage.main.library.deleteRemoteArtworkCachePaths()
                appDelegate.storage.main.library.saveContext()
                fileManager.deleteRemoteArtworkCache()
                appDelegate.artworkDownloadManager.start()
              },
              secondaryButton: .cancel()
            )
          }
        }
        SettingsSection {
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
      timer.upstream.connect().cancel()
    }
  }
}

// MARK: - ArtworkSettingsView_Previews

struct ArtworkSettingsView_Previews: PreviewProvider {
  static var previews: some View {
    ArtworkSettingsView()
  }
}
