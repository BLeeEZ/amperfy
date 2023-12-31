//
//  DisplaySettingsView.swift
//  Amperfy
//
//  Created by Maximilian Bauer on 30.12.23.
//  Copyright (c) 2023 Maximilian Bauer. All rights reserved.
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

struct DisplaySettingsView: View {
    
    @EnvironmentObject private var settings: Settings
    
    var body: some View {
        ZStack{
            List {
                Section(content: {
                    HStack {
                        Text("Detailed Information")
                        Spacer()
                        Toggle(isOn: $settings.isShowDetailedInfo) {}
                            .frame(width: 130)
                    }
 
                }
                , footer: {
                    Text("Display detailed information (bitrate, ID) and button \"Copy ID to Clipboard\".")
                })
                
                Section(content: {
                    HStack {
                        Text("Song Duration")
                        Spacer()
                        Toggle(isOn: $settings.isShowSongDuration) {}
                            .frame(width: 130)
                    }
 
                }
                , footer: {
                    Text("Display song duration in table rows.")
                })
            }
        }
        .navigationTitle("Display")
    }
}

struct DisplaySettingsView_Previews: PreviewProvider {
    @State static var settings = Settings()
    
    static var previews: some View {
        DisplaySettingsView().environmentObject(settings)
    }
}
