//
//  EQToolbar.swift
//  Amperfy
//
//  Created by Maximilian Bauer on 19.07.25.
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

import SwiftUI

// MARK: - EQToolbar

struct EQToolbar: View {
  var canUndo: Bool
  var canRedo: Bool
  var canAddBand: Bool
  var globalBypass: Bool
  var isABCompareActive: Bool
  var currentABState: ParametricEQViewModel.ABState
  var accentColor: Color

  var onUndo: () -> ()
  var onRedo: () -> ()
  var onAddBand: () -> ()
  var onToggleBypass: () -> ()
  var onStartABCompare: () -> ()
  var onToggleAB: () -> ()
  var onEndABCompare: (Bool) -> ()
  var onReset: () -> ()

  var body: some View {
    HStack {
      // Undo
      Button {
        onUndo()
      } label: {
        Image(systemName: "arrow.uturn.backward")
      }
      .disabled(!canUndo)

      Spacer()

      // Redo
      Button {
        onRedo()
      } label: {
        Image(systemName: "arrow.uturn.forward")
      }
      .disabled(!canRedo)

      Spacer()

      // Global bypass
      Button {
        onToggleBypass()
      } label: {
        Image(systemName: globalBypass ? "speaker.slash.fill" : "speaker.wave.2.fill")
          .foregroundColor(globalBypass ? .orange : accentColor)
      }

      Spacer()

      // Reset button
      Menu {
        Button(role: .destructive) {
          onReset()
        } label: {
          Label("Reset All Bands", systemImage: "arrow.counterclockwise")
        }
      } label: {
        Image(systemName: "ellipsis.circle")
      }

      Spacer()

      // Add band
      Button {
        onAddBand()
      } label: {
        Image(systemName: "plus.circle.fill")
      }
      .disabled(!canAddBand)
    }
    .buttonStyle(.bordered)
    .tint(accentColor)
  }
}
