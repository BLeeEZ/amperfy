//
//  PlayerSettingsView.swift
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

// MARK: - PlayerSettingsView

struct PlayerSettingsView: View {
  @EnvironmentObject
  private var settings: Settings

  private func updateBitrate(
    wifi: StreamingMaxBitratePreference? = nil,
    cellular: StreamingMaxBitratePreference? = nil
  ) {
    if let wifi = wifi {
      settings.streamingMaxBitrateWifiPreference = wifi
    }
    if let cellular = cellular {
      settings.streamingMaxBitrateCellularPreference = cellular
    }
    appDelegate.player.setStreamingMaxBitrates(
      to: StreamingMaxBitrates(
        wifi: settings.streamingMaxBitrateWifiPreference,
        cellular: settings.streamingMaxBitrateCellularPreference
      )
    )
  }

  private func updateFormat(_ format: StreamingFormatPreference) {
    settings.streamingFormatPreference = format
  }

  private func updateCacheFormat(_ format: CacheTranscodingFormatPreference) {
    settings.cacheTranscodingFormatPreference = format
  }

  var body: some View {
    ZStack {
      SettingsList {
        // General Settings
        SettingsSection {
          SettingsCheckBoxRow(
            label: "Auto cache played Songs",
            isOn: $settings.isPlayerAutoCachePlayedItems
          )
        }

        SettingsSection(
          content: {
            SettingsCheckBoxRow(
              label: "Scrobble streamed Songs",
              isOn: $settings.isScrobbleStreamedItems
            )
          },
          footer: "Enable to scrobble all streamed songs, even if the server already marks them as played."
        )

        SettingsSection(content: {
          SettingsCheckBoxRow(label: "Manual Playback", isOn: $settings.isPlaybackStartOnlyOnPlay)
        }, footer: "Enable to start playback only when the Play button is pressed.")

        // Streaming Bitrate Settings
        SettingsSection(content: {
          SettingsRow(title: "Max Bitrate for Streaming (WiFi)") {
            Menu(settings.streamingMaxBitrateWifiPreference.description) {
              ForEach(StreamingMaxBitratePreference.allCases, id: \.self) { bitrate in
                Button(bitrate.description) {
                  updateBitrate(wifi: bitrate)
                }
              }
            }
          }
        }, footer: "Set the maximum streaming bitrate for WiFi")

        SettingsSection(content: {
          SettingsRow(title: "Max Bitrate for Streaming (Cellular)") {
            Menu(settings.streamingMaxBitrateCellularPreference.description) {
              ForEach(StreamingMaxBitratePreference.allCases, id: \.self) { bitrate in
                Button(bitrate.description) {
                  updateBitrate(cellular: bitrate)
                }
              }
            }
          }
        }, footer: "Set the maximum streaming bitrate for Cellular")

        // Streaming Format Settings
        SettingsSection(
          content: {
            SettingsRow(title: "Streaming Format (Transcoding)") {
              Menu(settings.streamingFormatPreference.description) {
                ForEach(StreamingFormatPreference.allCases, id: \.self) { format in
                  Button(format.description) {
                    updateFormat(format)
                  }
                }
              }
            }
          },
          footer: "Select a transcoding format for streaming. Transcoding is recommended for better compatibility."
        )

        // Cache Format Settings
        SettingsSection(content: {
          SettingsRow(title: "Cache Format (Transcoding)") {
            Menu(settings.cacheTranscodingFormatPreference.description) {
              ForEach(CacheTranscodingFormatPreference.allCases, id: \.self) { format in
                Button(format.description) {
                  updateCacheFormat(format)
                }
              }
            }
          }
        }, footer: """
        Select a transcoding format for cached songs. Changes will not apply to already downloaded songs; clear cache and redownload if needed.
        \(
          appDelegate.storage.loginCredentials?.backendApi == .ampache ? "" :
            """
            For 'raw', Amperfy uses the Subsonic API's 'download' action, which skips transcoding. Other formats use the 'stream' action, which requires proper server configuration for transcoding.
            """
        )
        """)
      }
    }
    .navigationTitle("Player, Stream & Scrobble")
    .navigationBarTitleDisplayMode(.inline)
    .onAppear {
      appDelegate.userStatistics.visited(.settingsPlayer)
    }
  }
}

// MARK: - PlayerSettingsView_Previews

struct PlayerSettingsView_Previews: PreviewProvider {
  @State
  static var settings = Settings()

  static var previews: some View {
    PlayerSettingsView().environmentObject(settings)
  }
}
