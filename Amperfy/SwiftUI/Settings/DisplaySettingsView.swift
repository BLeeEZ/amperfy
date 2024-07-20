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
    
    func setThemePreference(preference: ThemePreference) {
        settings.themePreference = preference
        appDelegate.setAppTheme(color: preference.asColor)
        // the following applies the tint color to already loaded views
        guard let window = appDelegate.window else { return }
        for view in window.subviews {
            view.removeFromSuperview()
            window.addSubview(view)
        }
    }
    
    func tooglePlayerLyricsButtonPreference() {
        settings.isAlwaysHidePlayerLyricsButton.toggle()
        if settings.isAlwaysHidePlayerLyricsButton {
            appDelegate.storage.settings.isPlayerLyricsDisplayed = false
        }
    }
    
    var body: some View {
        ZStack{
            List {
                Section(content: {
                    HStack {
                        Text("Theme Color")
                        Spacer()
                        Menu(settings.themePreference.description) {
                            Button(ThemePreference.blue.description) {
                                setThemePreference(preference: .blue)
                            }
                            Button(ThemePreference.green.description) {
                                setThemePreference(preference: .green)
                            }
                            Button(ThemePreference.red.description) {
                                setThemePreference(preference: .red)
                            }
                            Button(ThemePreference.yellow.description) {
                                setThemePreference(preference: .yellow)
                            }
                            Button(ThemePreference.orange.description) {
                                setThemePreference(preference: .orange)
                            }
                            Button(ThemePreference.purple.description) {
                                setThemePreference(preference: .purple)
                            }
                            Button(ThemePreference.pink.description) {
                                setThemePreference(preference: .pink)
                            }
                        }
                    }
                })
                
                Section(content: {
                    HStack {
                        Text("Haptic Feedback")
                        Spacer()
                        Toggle(isOn: $settings.isHapticsEnabled) {}
                    }
                }
                , footer: {
                    Text("Certain interactions provide haptic feedback. Long pressing to display the details menu will always trigger haptic feedback.")
                })
                
                Section(content: {
                    HStack {
                        Text("Music Player Skip Buttons")
                        Spacer()
                        Toggle(isOn: $settings.isShowMusicPlayerSkipButtons) {}
                            //.frame(width: 130)
                    }
                    
                }
                , footer: {
                    Text("Display skip forward button and skip backward button in music player in addition to previous/next buttons.")
                })
                
                if appDelegate.backendApi.selectedApi != .ampache {
                    Section(content: {
                        HStack {
                            Text("Music Player Lyrics Button")
                            Spacer()
                            Toggle(isOn: Binding<Bool>(
                                get: { !settings.isAlwaysHidePlayerLyricsButton },
                                set: { _ in tooglePlayerLyricsButtonPreference() }
                            )) {}
                                //.frame(width: 130)
                        }
                        
                    }
                    , footer: {
                        Text("Display lyrics button in music player.")
                    })
                    
                    Section(content: {
                        HStack {
                            Text("Lyrics Smooth Scrolling")
                            Spacer()
                            Toggle(isOn: $settings.isLyricsSmoothScrolling) {}
                                //.frame(width: 130)
                        }
                        
                    }
                    , footer: {
                        Text("Lyrics are smoothly scrolled to next line. Deactivating will result in jumping from line to line.")
                    })
                }
                
                Section(content: {
                    HStack {
                        Text("Detailed Information")
                        Spacer()
                        Toggle(isOn: $settings.isShowDetailedInfo) {}
                            //.frame(width: 130)
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
                            //.frame(width: 130)
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
                            //.frame(width: 130)
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
                            //.frame(width: 130)
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
                            //.frame(width: 130)
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
