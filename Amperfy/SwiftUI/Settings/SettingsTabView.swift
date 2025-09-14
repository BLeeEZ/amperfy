//
//  SettingsTabView.swift
//  Amperfy
//
//  Created by Maximilian Bauer on 11.08.25.
//  Copyright (c) 2025 Maximilian Bauer. All rights reserved.
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

struct SettingsTabView: View {
  @State
  var selectedMenu: NavigationTarget = .general
  @State
  private var columnVisibility = NavigationSplitViewVisibility.doubleColumn

  var body: some View {
    NavigationSplitView(columnVisibility: $columnVisibility) {
      List(NavigationTarget.allCases, id: \.self) { menuElement in
        HStack {
          HStack {
            Image(uiImage: menuElement.icon.withRenderingMode(.alwaysTemplate))
            Text(menuElement.displayName)
          }
          .foregroundStyle(
            selectedMenu == menuElement
              ? Color.systemBackground
              : Color.label
          )
          .padding(8)
          .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(
          selectedMenu == menuElement
            ? Color.accentColor
            : Color.clear
        )
        .cornerRadius(8)
        .contentShape(Rectangle())
        .onTapGesture { selectedMenu = menuElement }
      }
      .listStyle(.sidebar)
    } detail: {
      NavigationStack {
        AnyView(selectedMenu.view())
      }
    }
  }
}
