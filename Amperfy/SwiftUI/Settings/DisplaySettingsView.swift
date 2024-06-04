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
import AmperfyKit

struct DisplaySettingsView: View {
    
    @EnvironmentObject private var settings: Settings
    
    @State var isShowRestartAppThemeChange = false

    
    func setAppThemePreference(preference: AppThemePreference) {
        settings.appThemePreference = preference
        isShowRestartAppThemeChange = true
    }
    
    var body: some View {
        ZStack{
            List {
                Section(content: {
                    HStack {
                        Text("App color")
                        Spacer()
                        Menu(settings.appThemePreference.description) {
                            Button(AppThemePreference.blue.description) {
                                setAppThemePreference(preference: AppThemePreference.blue)
                            }
                            Button(AppThemePreference.green.description) {
                                setAppThemePreference(preference: AppThemePreference.green)
                            }
                            Button(AppThemePreference.red.description) {
                                setAppThemePreference(preference: AppThemePreference.red)
                            }
                            Button(AppThemePreference.yellow.description) {
                                setAppThemePreference(preference: AppThemePreference.yellow)
                            }
                            Button(AppThemePreference.pink.description) {
                                setAppThemePreference(preference: AppThemePreference.pink)
                            }
                            Button(AppThemePreference.purple.description) {
                                setAppThemePreference(preference: AppThemePreference.purple)
                            }
                        }.alert(isPresented: $isShowRestartAppThemeChange) {
                            Alert(title: Text("Apply Theme"), message: Text("In order to change the theme you should restart the app now"),
                            primaryButton: .destructive(Text("Restart")) {
                                self.appDelegate.restartByUser()
                            },secondaryButton: .cancel())
                        }
                    }
 
                }
                , footer: {
                    Text("Sets the app accent color")
                })
                Section(content: {
                    HStack {
                        Text("Music player skip buttons")
                        Spacer()
                        Toggle(isOn: $settings.isShowMusicPlayerSkipButtons) {}
                            .frame(width: 130)
                    }
 
                }
                , footer: {
                    Text("Displays skip forward button and skip backward button in music player in addition to previous/next buttons.")
                })
                
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
                
                Section(content: {
                    HStack {
                        Text("Album Duration")
                        Spacer()
                        Toggle(isOn: $settings.isShowAlbumDuration) {}
                            .frame(width: 130)
                    }
 
                }
                , footer: {
                    Text("Display album duration in table rows.")
                })
                
                Section(content: {
                    HStack {
                        Text("Artist Duration")
                        Spacer()
                        Toggle(isOn: $settings.isShowArtistDuration) {}
                            .frame(width: 130)
                    }
 
                }
                , footer: {
                    Text("Display artist duration in table rows.")
                })
                
                Section(content: {
                    HStack {
                        Text("Disable Player Shuffle Button")
                        Spacer()
                        Toggle(isOn: Binding<Bool>(
                            get: { !settings.isPlayerShuffleButtonEnabled },
                            set: { settings.isPlayerShuffleButtonEnabled = !$0 }
                        )) {}
                            .frame(width: 130)
                    }
                }
                , footer: {
                    Text("Player Shuffle Button is displayed but it can't be interacted with.")
                })
            }
        }
        .navigationTitle("Display")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct DisplaySettingsView_Previews: PreviewProvider {
    @State static var settings = Settings()
    
    static var previews: some View {
        DisplaySettingsView().environmentObject(settings)
    }
}
