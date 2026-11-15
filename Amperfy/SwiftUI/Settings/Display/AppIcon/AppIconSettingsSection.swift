//
//  AppIconSettingsSection.swift
//  Amperfy
//
//  Created by Giacomo Sfratato on 09.11.26.
//  Copyright (c) 2026 Maximilian Bauer. All rights reserved.
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

/// Settings section to choose one of the alternate app icons
struct AppIconSettingsSection: View {
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

  private var visibleAppIcons: [AppIconOption] {
    guard selectedAppIconCategory != .all else {
      return AppIconOption.all
    }

    return AppIconOption.all.filter {
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
    _selectedAppIconCategory = State(initialValue: Self.category(ofIconName: iconName))
  }

  private static func category(ofIconName iconName: String?) -> AppIconCategory {
    AppIconOption.all.first { $0.iconName == iconName }?.category ?? .amperfy
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

  var body: some View {
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
    .onAppear {
      selectedAppIconName = UIApplication.shared.alternateIconName
      selectedAppIconCategory = Self.category(ofIconName: selectedAppIconName)
    }
    .alert("Unable to Change App Icon", isPresented: $isShowingAppIconError) {
      Button("OK", role: .cancel) {}
    } message: {
      Text(appIconErrorMessage)
    }
  }
}
