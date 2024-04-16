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

struct PlayerSettingsView: View {
    
    @EnvironmentObject private var settings: Settings
    
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
