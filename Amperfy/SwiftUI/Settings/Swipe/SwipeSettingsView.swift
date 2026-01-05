//
//  SwipeSettingsView.swift
//  Amperfy
//
//  Created by Maximilian Bauer on 15.09.22.
//  Copyright (c) 2022 Maximilian Bauer. All rights reserved.
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

// MARK: - SwipePosition

enum SwipePosition {
  case leading
  case trailing

  var description: String {
    switch self {
    case .leading:
      return "leading"
    case .trailing:
      return "trailing"
    }
  }
}

// MARK: - SwipeSettingsView

struct SwipeSettingsView: View {
  @EnvironmentObject
  private var settings: Settings
  @State
  private var leading = [SwipeActionType]()
  @State
  private var trailing = [SwipeActionType]()
  @State
  var isShowingAddView = false
  @State
  var addPositionType = SwipePosition.leading

  func reload() {
    leading = settings.swipeActionSettings.leading
    trailing = settings.swipeActionSettings.trailing
  }

  func add(swipePosition: SwipePosition, elementToAdd: SwipeActionType) {
    switch swipePosition {
    case .leading:
      leading.append(elementToAdd)
    case .trailing:
      trailing.append(elementToAdd)
    }
    save()
  }

  func save() {
    settings.swipeActionSettings = SwipeActionSettings(leading: leading, trailing: trailing)
  }

  var body: some View {
    ZStack {
      SettingsList {
        Section(
          header:
          HStack {
            Text("Leading")
            Spacer()
            Button(action: {
              addPositionType = .leading
              isShowingAddView = true
            }) {
              AmperfyImage.plus.asImage
            }
          }
        ) {
          ForEach(leading, id: \.self) { swipe in
            SwipeCellView(swipe: swipe)
          }
          .onDelete { index in
            leading.remove(at: index.first!)
            save()
          }
          .onMove { fromOffsets, toOffset in
            leading.move(fromOffsets: fromOffsets, toOffset: toOffset)
            save()
          }
        }
        Section(
          header:
          HStack {
            Text("Trailing")
            Spacer()
            Button(action: {
              addPositionType = .trailing
              isShowingAddView = true
            }) {
              AmperfyImage.plus.asImage
            }
          }
        ) {
          ForEach(trailing, id: \.self) { swipe in
            SwipeCellView(swipe: swipe)
          }
          .onDelete { index in
            trailing.remove(at: index.first!)
            save()
          }
          .onMove { fromOffsets, toOffset in
            trailing.move(fromOffsets: fromOffsets, toOffset: toOffset)
            save()
          }
        }
      }.environment(\.editMode, .constant(.active))
        .listStyle(.insetGrouped)
        .sheet(isPresented: $isShowingAddView) {
          AddSwipeActionView(
            isVisible: $isShowingAddView,
            swipePosition: $addPositionType,
            addCB: add
          )
        }
    }
    .navigationTitle("Swipe")
    .navigationBarTitleDisplayMode(.inline)
    .onAppear {
      reload()
    }
  }
}

// MARK: - SwipeSettingsView_Previews

struct SwipeSettingsView_Previews: PreviewProvider {
  @State
  static var settings = Settings()

  static var previews: some View {
    SwipeSettingsView().environmentObject(settings)
  }
}
