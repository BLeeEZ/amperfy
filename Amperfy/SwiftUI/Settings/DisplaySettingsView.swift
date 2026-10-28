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

  func setAppearanceMode(style: UIUserInterfaceStyle) {
    settings.appearanceMode = style
    appDelegate.setAppAppearanceMode(style: style)
  }

  /// Text size that is displayed while the system text size is used
  private var currentTextSize: UIContentSizeCategory {
    if let textSize = settings.textSize {
      return textSize
    }
    #if targetEnvironment(macCatalyst)
      return .large
    #else
      let systemTextSize = UIApplication.shared.preferredContentSizeCategory
      return TextScaling.textSizes.contains(systemTextSize) ? systemTextSize : .large
    #endif
  }

  /// Position of the text size in `TextScaling.textSizes`
  private var textSizeIndex: Binding<Double> {
    Binding<Double>(
      get: {
        let index = TextScaling.textSizes.firstIndex(of: currentTextSize) ??
          TextScaling.textSizes.firstIndex(of: .large) ?? 0
        return Double(index)
      },
      set: { newValue in
        let index = min(max(Int(newValue.rounded()), 0), TextScaling.textSizes.count - 1)
        let textSize = TextScaling.textSizes[index]
        if settings.textSize != textSize {
          settings.textSize = textSize
        }
      }
    )
  }

  private var isSystemTextSize: Binding<Bool> {
    Binding<Bool>(
      get: { settings.textSize == nil },
      set: { settings.textSize = $0 ? nil : currentTextSize }
    )
  }

  /// Mac: always (no system text size), iOS: if the system text size is not used
  private var isTextSizeSliderVisible: Bool {
    #if targetEnvironment(macCatalyst)
      return true
    #else
      return settings.textSize != nil
    #endif
  }

  private var textSizeFooter: String {
    #if targetEnvironment(macCatalyst)
      return "\(Self.textSizeName(currentTextSize)): Size of the text in lists and album grids."
    #else
      guard settings.textSize != nil else {
        return "Amperfy uses the text size from the iOS settings."
      }
      return "\(Self.textSizeName(currentTextSize)): Size of the text in Amperfy."
    #endif
  }

  private static func textSizeName(_ textSize: UIContentSizeCategory) -> String {
    switch textSize {
    case .extraSmall: "Extra Small"
    case .small: "Small"
    case .medium: "Medium"
    case .large: "Default"
    case .extraLarge: "Large"
    case .extraExtraLarge: "Extra Large"
    case .extraExtraExtraLarge: "Extra Extra Large"
    case .accessibilityMedium: "Accessibility 1"
    case .accessibilityLarge: "Accessibility 2"
    case .accessibilityExtraLarge: "Accessibility 3"
    case .accessibilityExtraExtraLarge: "Accessibility 4"
    case .accessibilityExtraExtraExtraLarge: "Accessibility 5"
    default: textSize.rawValue
    }
  }

  var body: some View {
    ZStack {
      SettingsList {
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

        #if !targetEnvironment(macCatalyst)
          SettingsSection(
            content: {
              SettingsCheckBoxRow(title: "Haptic Feedback", isOn: $settings.isHapticsEnabled)
            },
            footer:
            "Certain interactions provide haptic feedback. Long pressing to display the details menu will always trigger haptic feedback."
          )
        #endif

        SettingsSection(
          content: {
            #if !targetEnvironment(macCatalyst)
              SettingsCheckBoxRow(title: "Use System Text Size", isOn: isSystemTextSize)
            #endif
            if isTextSizeSliderVisible {
              SettingsRow(title: "Text Size") {
                Slider(
                  value: textSizeIndex,
                  in: 0 ... Double(TextScaling.textSizes.count - 1),
                  step: 1
                ) {
                  Text("Text Size")
                } minimumValueLabel: {
                  Image(systemName: "textformat.size.smaller")
                } maximumValueLabel: {
                  Image(systemName: "textformat.size.larger")
                }
              }
            }
          },
          footer: textSizeFooter
        )

        #if targetEnvironment(macCatalyst)
          SettingsSection(
            content: {
              SettingsCheckBoxRow(
                title: "Mini Player Always on Top",
                isOn: $settings.isMiniPlayerAlwaysOnTop
              )
            },
            footer:
            "Keep the mini player window floating above all other windows."
          )
        #endif

        SettingsSection(
          content: {
            SettingsCheckBoxRow(
              title: "Music Player Skip Buttons",
              isOn: $settings.isShowMusicPlayerSkipButtons
            )
          },
          footer:
          "Add skip forward and skip backward buttons to the music player, along with the previous/next buttons."
        )

        if let activeAccountInfo = settings.activeAccountInfo,
           let credentials = appDelegate.storage.settings.accounts.getSetting(activeAccountInfo)
           .read.loginCredentials,
           credentials.backendApi.asServerApiType != .ampache {
          SettingsSection(
            content: {
              SettingsCheckBoxRow(
                title: "Lyrics Smooth Scrolling",
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
              title: "Detailed Information",
              isOn: $settings.isShowDetailedInfo
            )
          },
          footer:
          "Display detailed information (bitrate, ID) and button \"Copy ID to Clipboard\"."
        )

        SettingsSection(
          content: {
            SettingsCheckBoxRow(title: "Song Duration", isOn: $settings.isShowSongDuration)
          },
          footer:
          "Display song duration in table rows."
        )

        SettingsSection(
          content: {
            SettingsCheckBoxRow(title: "Album Duration", isOn: $settings.isShowAlbumDuration)
          },
          footer:
          "Display album duration in table rows."
        )

        SettingsSection(
          content: {
            SettingsCheckBoxRow(title: "Artist Duration", isOn: $settings.isShowArtistDuration)
          },
          footer:
          "Display artist duration in table rows."
        )

        SettingsSection(
          content: {
            SettingsCheckBoxRow(title: "Show Star Rating", isOn: $settings.isShowRating)
          },
          footer:
          "Display star rating in song cells and the currently playing view."
        )

        SettingsSection(
          content: {
            SettingsCheckBoxRow(
              title: "Disable Player Shuffle Button",
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
