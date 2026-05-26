//
//  SongTagsFilterView.swift
//  Amperfy
//
//  Created by Amperfy on 25.05.26.
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

import Foundation
import SwiftUI

// MARK: - SongTagsFilterView

struct SongTagsFilterView: View {
  @ObservedObject var store: TagVisibilityStore
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    List {
      Section {
        ForEach(SongTagKey.allCases, id: \.rawValue) { key in
          let isOn = Binding<Bool>(
            get: { !store.hiddenKeys.contains(key.rawValue) },
            set: { store.setVisible(key, visible: $0) }
          )
          SettingsCheckBoxRow(title: key.displayName, isOn: isOn)
        }
      }
      Section {
        Button("Show All") {
          store.showAll()
        }
      }
    }
    .navigationTitle("Visible Tags")
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
      ToolbarItem(placement: .navigationBarTrailing) {
        Button("Done") { dismiss() }
      }
    }
  }
}
