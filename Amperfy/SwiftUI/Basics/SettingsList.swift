//
//  SettingsList.swift
//  Amperfy
//
//  Created by David Klopp on 07.09.24.
//  Copyright (c) 2024 Maximilian Bauer. All rights reserved.
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

import Foundation
import SwiftUI

// MARK: - SettingsList

struct SettingsList<Content: View>: View {
  let content: () -> Content

  init(@ViewBuilder content: @escaping () -> Content) {
    self.content = content
  }

  var body: some View {
    List {
      content()
        .settingsRowBackground()
    }
    .settingsListBackground()
  }
}

// MARK: - Settings colors

extension Color {
  #if targetEnvironment(macCatalyst) // ok
    // macOS style (like System Settings): the content area uses the window background and the
    // grouped rows are drawn as a subtle fill on top of it. The fill is translucent, so the rows
    // become slightly darker in light mode and slightly lighter in dark mode.
    static let settingsBackground = Color(UIColor.systemBackground)
    static let settingsRowBackground = Color(UIColor.quaternarySystemFill)
  #endif
}

extension View {
  /// Background of a settings `List`
  @ViewBuilder
  func settingsListBackground() -> some View {
    #if targetEnvironment(macCatalyst) // ok
      scrollContentBackground(.hidden)
        .background(Color.settingsBackground)
    #else
      background(Color.clear)
    #endif
  }

  /// Background of the rows inside a settings `List`
  @ViewBuilder
  func settingsRowBackground() -> some View {
    #if targetEnvironment(macCatalyst) // ok
      listRowBackground(Color.settingsRowBackground)
    #else
      self
    #endif
  }
}
