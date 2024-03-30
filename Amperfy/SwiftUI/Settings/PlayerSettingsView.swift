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

import SwiftUI
import AmperfyKit

struct PlayerSettingsView: View {
    
    @EnvironmentObject private var settings: Settings
    
    func streamingMaxBitrateNoLimit() {
        settings.streamingMaxBitratePreference = .noLimit
    }
    func streamingMaxBitrate32() {
        settings.streamingMaxBitratePreference = .limit32
    }
    func streamingMaxBitrate64() {
        settings.streamingMaxBitratePreference = .limit64
    }
    func streamingMaxBitrate96() {
        settings.streamingMaxBitratePreference = .limit96
    }
    func streamingMaxBitrate128() {
        settings.streamingMaxBitratePreference = .limit128
    }
    func streamingMaxBitrate192() {
        settings.streamingMaxBitratePreference = .limit192
    }
    func streamingMaxBitrate256() {
        settings.streamingMaxBitratePreference = .limit256
    }
    func streamingMaxBitrate320() {
        settings.streamingMaxBitratePreference = .limit320
    }
    
    func streamingFormatMp3() {
        settings.streamingFormatPreference = .mp3
    }
    func streamingFormatRaw() {
        settings.streamingFormatPreference = .raw
    }
    
    var body: some View {
        ZStack{
            List {
                Section(content: {
                    HStack {
                        Text("Auto cache played Songs")
                        Spacer()
                        Toggle(isOn: $settings.isPlayerAutoCachePlayedItems) {
                        }
                    }
                }, header: {
                })
                
                Section(content: {
                    HStack {
                        Text("Scrobble streamed Songs")
                        Spacer()
                        Toggle(isOn: $settings.isScrobbleStreamedItems) {}
                            .frame(width: 130)
                    }
                }
                , footer: {
                    Text("Some server count streamed items already as played. When active streamed Songs are getting always scrobbled.")
                })
                
                Section(content: {
                    HStack {
                        Text("Max Bitrate for Streaming")
                        Spacer()
                        Menu(settings.streamingMaxBitratePreference.description) {
                            Button(StreamingMaxBitratePreference.noLimit.description, action: streamingMaxBitrateNoLimit)
                            Button(StreamingMaxBitratePreference.limit32.description, action: streamingMaxBitrate32)
                            Button(StreamingMaxBitratePreference.limit64.description, action: streamingMaxBitrate64)
                            Button(StreamingMaxBitratePreference.limit96.description, action: streamingMaxBitrate96)
                            Button(StreamingMaxBitratePreference.limit128.description, action: streamingMaxBitrate128)
                            Button(StreamingMaxBitratePreference.limit192.description, action: streamingMaxBitrate192)
                            Button(StreamingMaxBitratePreference.limit256.description, action: streamingMaxBitrate256)
                            Button(StreamingMaxBitratePreference.limit320.description, action: streamingMaxBitrate320)
                        }
                    }
                }
                , footer: {
                    Text("Lower bitrate saves bandwidth. This takes only affect when streaming.")
                })
                
                Section(content: {
                    HStack {
                        Text("Streaming Format (Transcoding)")
                        Spacer()
                        Menu(settings.streamingFormatPreference.description) {
                            Button(StreamingFormatPreference.mp3.description, action: streamingFormatMp3)
                            Button(StreamingFormatPreference.raw.description, action: streamingFormatRaw)
                        }
                    }
                }
                , footer: {
                    Text("Transicoding is recommended due to incompatibility with some formats. This takes only affect when streaming.")
                })
            }
        }
        .navigationTitle("Player & Scrobble")
        .onAppear {
            appDelegate.userStatistics.visited(.settingsPlayer)
        }
    }
}

struct PlayerSettingsView_Previews: PreviewProvider {
    @State static var settings = Settings()
    
    static var previews: some View {
        PlayerSettingsView().environmentObject(settings)
    }
}
