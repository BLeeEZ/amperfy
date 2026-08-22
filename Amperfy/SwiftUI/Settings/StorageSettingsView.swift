//
//  StorageSettingsView.swift
//  Amperfy
//
//  Created by David Masek on 22.08.26.
//  Copyright (c) 2026 Maximilian Bauer. All rights reserved.
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

// MARK: - StorageSettingsView

struct StorageSettingsView: View {
  @EnvironmentObject
  private var settings: Settings

  @State
  private var usage: StorageUsage?

  private static let topAlbumCount = 20

  private func updateValues() async {
    guard let activeAccountInfo = settings.activeAccountInfo else { return }
    usage = try? await StorageUsageCalculator.calculate(
      storage: appDelegate.storage,
      accountInfo: activeAccountInfo
    )
  }

  private func refresh() {
    usage = nil
    Task { await updateValues() }
  }

  private func albumRow(_ album: StorageUsage.AlbumUsage) -> some View {
    HStack {
      VStack(alignment: .leading) {
        Text(album.albumName)
          .lineLimit(1)
        Text(album.artistName)
          .font(.caption)
          .foregroundColor(.secondary)
          .lineLimit(1)
      }
      Spacer()
      SecondaryText(album.sizeInByte.asByteString)
    }
  }

  private func allAlbumsView(albums: [StorageUsage.AlbumUsage]) -> some View {
    SettingsList {
      SettingsSection(content: {
        ForEach(albums) { album in
          albumRow(album)
        }
      })
    }
    .navigationTitle("Cached Albums")
    .navigationBarTitleDisplayMode(.inline)
  }

  var body: some View {
    ZStack {
      if let usage = usage {
        SettingsList {
          SettingsSection(
            content: {
              SettingsRow(title: "Total") {
                SecondaryText(usage.totalSize.asByteString)
              }
            },
            footer: "Cache + database for this account. Excludes the app itself and other accounts, so it will read lower than the number shown in iOS Settings ▸ General ▸ iPhone Storage."
          )

          SettingsSection(content: {
            SettingsRow(title: "Songs") {
              SecondaryText(usage.songsSize.asByteString)
            }
            SettingsRow(title: "Podcast Episodes") {
              SecondaryText(usage.episodesSize.asByteString)
            }
            SettingsRow(title: "Artwork") {
              SecondaryText(usage.artworkSize.asByteString)
            }
            SettingsRow(title: "Embedded Artwork") {
              SecondaryText(usage.embeddedArtworkSize.asByteString)
            }
            SettingsRow(title: "Lyrics") {
              SecondaryText(usage.lyricsSize.asByteString)
            }
            SettingsRow(title: "Total Cache") {
              SecondaryText(usage.cacheTotal.asByteString)
            }
          }, header: "Cache")

          SettingsSection(content: {
            SettingsRow(title: "Internal Database") {
              SecondaryText(usage.databaseSize.asByteString)
            }
          }, footer: "The database is shared across all accounts.", header: "Database")

          if let availableDiskCapacity = UIDevice.current.availableDiskCapacityInByte {
            SettingsSection(content: {
              SettingsRow(title: "Available on Device") {
                SecondaryText(availableDiskCapacity.asByteString)
              }
            }, header: "Device")
          }

          if !usage.albums.isEmpty {
            SettingsSection(content: {
              ForEach(usage.albums.prefix(Self.topAlbumCount)) { album in
                albumRow(album)
              }
              if usage.albums.count > Self.topAlbumCount {
                NavigationLink {
                  allAlbumsView(albums: usage.albums)
                } label: {
                  Text("Show All")
                }
              }
            }, header: "Cached Albums (\(usage.albums.count))")
          }
        }
      } else {
        ProgressView("Calculating…")
      }
    }
    .navigationTitle("Storage")
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
      ToolbarItem(placement: .navigationBarTrailing) {
        Button(action: {
          refresh()
        }) {
          Image(systemName: "arrow.clockwise")
        }
        .disabled(usage == nil)
      }
    }
    .task {
      await updateValues()
    }
    .onChange(of: settings.activeAccountInfo) {
      refresh()
    }
  }
}

// MARK: - StorageSettingsView_Previews

struct StorageSettingsView_Previews: PreviewProvider {
  @State
  static var settings = Settings()

  static var previews: some View {
    StorageSettingsView().environmentObject(settings)
  }
}
