
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

  #if !targetEnvironment(macCatalyst)
    @State
    private var selectedAppIconName: String?
    @State
    private var selectedAppIconCategory: AppIconCategory = .amperfy
    @State
    private var isChangingAppIcon = false
    @State
    private var isShowingAppIconError = false
    @State
    private var appIconErrorMessage = ""

    private let appIconGridColumns = [
      GridItem(.adaptive(minimum: 72, maximum: 96), spacing: 12),
    ]

    private let appIconOptions = [
      AppIconOption(
        title: "Default",
        iconName: nil,
        previewName: "AmperfyAppIconPreview",
        category: .amperfy
      ),
      AppIconOption(
        title: "Teal",
        iconName: "AmperfyTeal",
        previewName: "AmperfyTealPreview",
        category: .amperfy
      ),
      AppIconOption(
        title: "Green",
        iconName: "AmperfyGreen",
        previewName: "AmperfyGreenPreview",
        category: .amperfy
      ),
      AppIconOption(
        title: "Yellow",
        iconName: "AmperfyYellow",
        previewName: "AmperfyYellowPreview",
        category: .amperfy
      ),
      AppIconOption(
        title: "Orange",
        iconName: "AmperfyOrange",
        previewName: "AmperfyOrangePreview",
        category: .amperfy
      ),
      AppIconOption(
        title: "Red",
        iconName: "AmperfyRed",
        previewName: "AmperfyRedPreview",
        category: .amperfy
      ),
      AppIconOption(
        title: "Pink",
        iconName: "AmperfyPink",
        previewName: "AmperfyPinkPreview",
        category: .amperfy
      ),
      AppIconOption(
        title: "Purple",
        iconName: "AmperfyPurple",
        previewName: "AmperfyPurplePreview",
        category: .amperfy
      ),
      AppIconOption(
        title: "Music Blue",
        iconName: "AmperfyMusicBlue",
        previewName: "AmperfyMusicBluePreview",
        category: .music
      ),
      AppIconOption(
        title: "Music Teal",
        iconName: "AmperfyMusicTeal",
        previewName: "AmperfyMusicTealPreview",
        category: .music
      ),
      AppIconOption(
        title: "Music Green",
        iconName: "AmperfyMusicGreen",
        previewName: "AmperfyMusicGreenPreview",
        category: .music
      ),
      AppIconOption(
        title: "Music Yellow",
        iconName: "AmperfyMusicYellow",
        previewName: "AmperfyMusicYellowPreview",
        category: .music
      ),
      AppIconOption(
        title: "Music Orange",
        iconName: "AmperfyMusicOrange",
        previewName: "AmperfyMusicOrangePreview",
        category: .music
      ),
      AppIconOption(
        title: "Music Red",
        iconName: "AmperfyMusicRed",
        previewName: "AmperfyMusicRedPreview",
        category: .music
      ),
      AppIconOption(
        title: "Music Pink",
        iconName: "AmperfyMusicPink",
        previewName: "AmperfyMusicPinkPreview",
        category: .music
      ),
      AppIconOption(
        title: "Music Purple",
        iconName: "AmperfyMusicPurple",
        previewName: "AmperfyMusicPurplePreview",
        category: .music
      ),
      AppIconOption(
        title: "Music Single",
        iconName: "AmperfyMusicSingle",
        previewName: "AmperfyMusicSinglePreview",
        category: .music
      ),
      AppIconOption(
        title: "Music Single Gradient",
        iconName: "AmperfyMusicSingleGradient",
        previewName: "AmperfyMusicSingleGradientPreview",
        category: .music
      ),
    ]

    private var visibleAppIcons: [AppIconOption] {
      guard selectedAppIconCategory != .all else {
        return appIconOptions
      }

      return appIconOptions.filter {
        $0.category == selectedAppIconCategory
      }
    }
  #endif

  func setAppearanceMode(style: UIUserInterfaceStyle) {
    settings.appearanceMode = style
    appDelegate.setAppAppearanceMode(style: style)
  }

  #if !targetEnvironment(macCatalyst)
    private func changeAppIcon(to iconName: String?) {
      guard !isChangingAppIcon else { return }
      guard UIApplication.shared.alternateIconName != iconName else { return }

      guard UIApplication.shared.supportsAlternateIcons else {
        appIconErrorMessage = "Alternate app icons are not supported on this device."
        isShowingAppIconError = true
        return
      }

      isChangingAppIcon = true
      Task { @MainActor in
        defer { isChangingAppIcon = false }

        do {
          try await UIApplication.shared.setAlternateIconName(iconName)
          selectedAppIconName = UIApplication.shared.alternateIconName
        } catch {
          selectedAppIconName = UIApplication.shared.alternateIconName
          appIconErrorMessage = error.localizedDescription
          isShowingAppIconError = true
        }
      }
    }
  #endif

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
              VStack(spacing: 16) {
                Picker("Icon Family", selection: $selectedAppIconCategory) {
                  ForEach(AppIconCategory.allCases) { category in
                    Text(category.title)
                      .tag(category)
                  }
                }
                .pickerStyle(.segmented)

                LazyVGrid(columns: appIconGridColumns, spacing: 16) {
                  ForEach(visibleAppIcons) { option in
                    let isSelected = selectedAppIconName == option.iconName

                    Button {
                      changeAppIcon(to: option.iconName)
                    } label: {
                      VStack(spacing: 8) {
                        Image(option.previewName)
                          .resizable()
                          .aspectRatio(contentMode: .fit)
                          .frame(width: 64, height: 64)
                          .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                          .overlay {
                            if isSelected {
                              RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(Color.accentColor, lineWidth: 3)
                            }
                          }

                        Text(option.title)
                          .font(.caption)
                          .multilineTextAlignment(.center)
                          .lineLimit(2)
                          .frame(height: 32, alignment: .top)
                          .foregroundStyle(isSelected ? Color.accentColor : Color.primary)
                      }
                      .frame(maxWidth: .infinity)
                      .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .disabled(isChangingAppIcon)
                    .accessibilityLabel(option.title)
                    .accessibilityValue(isSelected ? "Selected" : "Not selected")
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                  }
                }
              }
            },
            header: "App Icon"
          )
        #endif

        #if !targetEnvironment(macCatalyst)
          SettingsSection(
            content: {
              SettingsCheckBoxRow(title: "Haptic Feedback", isOn: $settings.isHapticsEnabled)
            },
            footer:
            "Certain interactions provide haptic feedback. Long pressing to display the details menu will always trigger haptic feedback."
          )
        #endif

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
    #if !targetEnvironment(macCatalyst)
      .onAppear {
        selectedAppIconName = UIApplication.shared.alternateIconName

        selectedAppIconCategory = appIconOptions.first {
          $0.iconName == selectedAppIconName
        }?.category ?? .amperfy
      }
      .alert("Unable to Change App Icon", isPresented: $isShowingAppIconError) {
        Button("OK", role: .cancel) {}
      } message: {
        Text(appIconErrorMessage)
      }
    #endif
  }
}

#if !targetEnvironment(macCatalyst)
  private enum AppIconCategory: String, CaseIterable, Identifiable {
    case amperfy
    case music
    case all

    var id: Self { self }

    var title: String {
      switch self {
      case .amperfy: "Amperfy"
      case .music: "Music"
      case .all: "All"
      }
    }
  }

  private struct AppIconOption: Identifiable {
    let title: String
    let iconName: String?
    let previewName: String
    let category: AppIconCategory

    var id: String { iconName ?? "Default" }
  }
#endif

// MARK: - DisplaySettingsView_Previews

struct DisplaySettingsView_Previews: PreviewProvider {
  @State
  static var settings = Settings()

  static var previews: some View {
    DisplaySettingsView().environmentObject(settings)
  }
}
