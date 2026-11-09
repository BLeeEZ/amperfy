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

  private let appIconGridColumnCount = 4

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

  /// `visibleAppIcons` split into rows of `appIconGridColumnCount`
  private var visibleAppIconRows: [[AppIconOption]] {
    let icons = visibleAppIcons
    return stride(from: 0, to: icons.count, by: appIconGridColumnCount).map {
      Array(icons[$0 ..< min($0 + appIconGridColumnCount, icons.count)])
    }
  }

  init() {
    let iconName = UIApplication.shared.alternateIconName
    _selectedAppIconName = State(initialValue: iconName)
    _selectedAppIconCategory = State(initialValue: appIconOptions.first {
      $0.iconName == iconName
    }?.category ?? .amperfy)
  }

  func setAppearanceMode(style: UIUserInterfaceStyle) {
    settings.appearanceMode = style
    appDelegate.setAppAppearanceMode(style: style)
  }

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

        // Mac Catalyst compiles alternate icons but doesn't support switching them
        // in our tests, so only show the picker when the system allows it.
        if UIApplication.shared.supportsAlternateIcons {
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

                // Non-lazy grid: a LazyVGrid inside a List row leaves cells blank when the
                // number of icons changes (e.g. switching the icon family).
                Grid(horizontalSpacing: 12, verticalSpacing: 16) {
                  ForEach(visibleAppIconRows.indices, id: \.self) { rowIndex in
                    let row = visibleAppIconRows[rowIndex]
                    GridRow {
                      ForEach(row) { option in
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
                }
              }
            },
            header: "App Icon"
          )
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

        #if !targetEnvironment(macCatalyst)
          SettingsSection(
            content: {
              SettingsCheckBoxRow(
                title: "Collapse Toolbar Player",
                isOn: $settings.isToolbarPlayerAutoCollapse
              )
            },
            footer:
            "Collapse the toolbar player into a compact view when scrolling"
          )
        #endif
      }
    }
    .navigationTitle("Display")
    .navigationBarTitleDisplayMode(.inline)
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
  }
}

// MARK: - AppIconCategory

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

// MARK: - AppIconOption

private struct AppIconOption: Identifiable {
  let title: String
  let iconName: String?
  let previewName: String
  let category: AppIconCategory

  var id: String { iconName ?? "Default" }
}

// MARK: - DisplaySettingsView_Previews

struct DisplaySettingsView_Previews: PreviewProvider {
  @State
  static var settings = Settings()

  static var previews: some View {
    DisplaySettingsView().environmentObject(settings)
  }
}
