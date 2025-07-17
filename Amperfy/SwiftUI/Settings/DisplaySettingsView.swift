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

import AmperfyKit
import SwiftUI

// MARK: - DisplaySettingsView

struct DisplaySettingsView: View {
  @EnvironmentObject
  private var settings: Settings

  func setThemePreference(preference: ThemePreference) {
    settings.themePreference = preference
    appDelegate.setAppTheme(color: preference.asColor)

    #if targetEnvironment(macCatalyst)
      // the following applies the tint color to already loaded views in all windows (AppKit)
      AppDelegate.updateAppKitControlColor(preference.asColor)
    #endif

    // the following applies the tint color to already loaded views in all windows (UIKit)
    let windowScene = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
    let windows = windowScene.flatMap { $0.windows }

    for window in windows {
      for view in window.subviews {
        view.removeFromSuperview()
        window.addSubview(view)
      }
    }
  }

  func setAppearanceMode(style: UIUserInterfaceStyle) {
    settings.appearanceMode = style
    appDelegate.setAppAppearanceMode(style: style)
  }

  func tooglePlayerLyricsButtonPreference() {
    settings.isAlwaysHidePlayerLyricsButton.toggle()
    if settings.isAlwaysHidePlayerLyricsButton {
      appDelegate.storage.settings.isPlayerLyricsDisplayed = false
    }
  }

  var body: some View {
    ZStack {
      SettingsList {
        SettingsSection {
          SettingsRow(title: "Theme Color") {
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
        }

        #if !targetEnvironment(macCatalyst)
          SettingsSection {
            SettingsRow(title: "Appearance") {
              Menu(
                settings.appearanceMode == .unspecified ? "System" :
                  (settings.appearanceMode == .light ? "Light" : "Dark")
              ) {
                Button("System") {
                  setAppearanceMode(style: .unspecified)
                }
                Button("Light") {
                  setAppearanceMode(style: .light)
                }
                Button("Dark") {
                  setAppearanceMode(style: .dark)
                }
              }
            }
          }
        #endif

        #if !targetEnvironment(macCatalyst)
          SettingsSection(
            content: {
              SettingsCheckBoxRow(label: "Haptic Feedback", isOn: $settings.isHapticsEnabled)
            },
            footer:
            "Certain interactions provide haptic feedback. Long pressing to display the details menu will always trigger haptic feedback."
          )
        #endif

        SettingsSection(
          content: {
            SettingsCheckBoxRow(
              title: "Music Player",
              label: "Music Player Skip Buttons",
              isOn: $settings.isShowMusicPlayerSkipButtons
            )
          },
          footer:
          "Add skip forward and skip backward buttons to the music player, along with the previous/next buttons."
        )

        if appDelegate.backendApi.selectedApi != .ampache {
          SettingsSection(
            content: {
              SettingsCheckBoxRow(label: "Music Player Lyrics Button", isOn: Binding<Bool>(
                get: { !settings.isAlwaysHidePlayerLyricsButton },
                set: { _ in tooglePlayerLyricsButtonPreference() }
              ))
            },
            footer:
            "Display lyrics button in music player."
          )

          SettingsSection(
            content: {
              SettingsCheckBoxRow(
                label: "Lyrics Smooth Scrolling",
                isOn: $settings.isLyricsSmoothScrolling
              )
            },
            footer:
            "Lyrics are smoothly scrolled to next line. Deactivating will result in jumping from line to line."
          )
        }

        SettingsSection(
          content: {
            SettingsCheckBoxRow(
              title: "Information",
              label: "Detailed Information",
              isOn: $settings.isShowDetailedInfo
            )
          },
          footer:
          "Display detailed information (bitrate, ID) and button \"Copy ID to Clipboard\"."
        )

        SettingsSection(
          content: {
            SettingsCheckBoxRow(label: "Song Duration", isOn: $settings.isShowSongDuration)
          },
          footer:
          "Display song duration in table rows."
        )

        SettingsSection(
          content: {
            SettingsCheckBoxRow(label: "Album Duration", isOn: $settings.isShowAlbumDuration)
          },
          footer:
          "Display album duration in table rows."
        )

        SettingsSection(
          content: {
            SettingsCheckBoxRow(label: "Artist Duration", isOn: $settings.isShowArtistDuration)
          },
          footer:
          "Display artist duration in table rows."
        )

        SettingsSection(
          content: {
            SettingsCheckBoxRow(
              title: "Shuffle",
              label: "Disable Player Shuffle Button",
              isOn: Binding<Bool>(
                get: { !settings.isPlayerShuffleButtonEnabled },
                set: {
                  settings.isPlayerShuffleButtonEnabled = !$0
                  UIMenuSystem.main.setNeedsRebuild()
                }
              )
            )
          },
          footer:
          "The player shuffle button is displayed but non-interactive."
        )
      }
    }
    .navigationTitle("Display")
    .navigationBarTitleDisplayMode(.inline)
  }
}

// MARK: - DisplaySettingsView_Previews

struct DisplaySettingsView_Previews: PreviewProvider {
  @State
  static var settings = Settings()

  static var previews: some View {
    DisplaySettingsView().environmentObject(settings)
  }
}
