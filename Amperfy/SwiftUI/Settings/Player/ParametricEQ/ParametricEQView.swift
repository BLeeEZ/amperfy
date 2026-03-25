//
//  ParametricEQView.swift
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

import AmperfyKit
import SwiftUI

// MARK: - ParametricEQView

struct ParametricEQView: View {
  @ObservedObject
  var viewModel: ParametricEQViewModel
  var accentColor: Color
  var onSettingChanged: (ParametricEqualizerSetting) -> ()

  var body: some View {
    VStack(spacing: 16) {
      // Toolbar
      EQToolbar(
        canUndo: viewModel.canUndo,
        canRedo: viewModel.canRedo,
        canAddBand: viewModel.canAddBand,
        globalBypass: viewModel.globalBypass,
        isABCompareActive: viewModel.isABCompareActive,
        currentABState: viewModel.currentABState,
        accentColor: accentColor,
        onUndo: {
          viewModel.undo()
          notifyChange()
        },
        onRedo: {
          viewModel.redo()
          notifyChange()
        },
        onAddBand: {
          viewModel.addBand()
          notifyChange()
        },
        onToggleBypass: {
          viewModel.setGlobalBypass(!viewModel.globalBypass)
          notifyChange()
        },
        onStartABCompare: {
          viewModel.startABCompare()
        },
        onToggleAB: {
          viewModel.toggleAB()
          notifyChange()
        },
        onEndABCompare: { keepCurrent in
          viewModel.endABCompare(keepCurrent: keepCurrent)
          notifyChange()
        },
        onReset: {
          viewModel.resetAllBands()
          notifyChange()
        }
      )

      // Frequency response curve
      FrequencyResponseCurve(
        bands: $viewModel.bands,
        selectedBandId: $viewModel.selectedBandId,
        globalBypass: viewModel.globalBypass,
        accentColor: accentColor,
        onBandDragStart: {
          viewModel.beginDrag()
        },
        onBandDrag: { id, freq, gain in
          viewModel.updateBand(id: id, frequency: freq, gain: gain)
          notifyChange()
        },
        onBandDragEnd: {
          viewModel.endDrag()
        },
        onBandSelect: { id in
          viewModel.selectBand(id: id)
        }
      )
      .padding(.horizontal)

      // Band control panel
      if let selectedBand = viewModel.selectedBand,
         let index = viewModel.bands.firstIndex(where: { $0.id == selectedBand.id }) {
        BandControlPanel(
          band: Binding(
            get: {
              guard index < viewModel.bands.count else { return selectedBand }
              return viewModel.bands[index]
            },
            set: { newValue in
              guard index < viewModel.bands.count else { return }
              viewModel.bands[index] = newValue
              notifyChange()
            }
          ),
          accentColor: accentColor,
          onDelete: {
            viewModel.removeBand(id: selectedBand.id)
            notifyChange()
          }
        )
        .padding(.horizontal)
      } else {
        NoBandSelectedView()
          .padding(.horizontal)
      }

      // Band list (compact)
      if !viewModel.bands.isEmpty {
        bandListView
          .padding(.horizontal)
      }
    }
  }

  // MARK: - Band List View

  private var bandListView: some View {
    ScrollView(.horizontal, showsIndicators: false) {
      HStack(spacing: 8) {
        ForEach(viewModel.bands) { band in
          bandChip(band: band)
        }
      }
      .padding(.vertical, 4)
    }
  }

  private func bandChip(band: ParametricBand) -> some View {
    let isSelected = band.id == viewModel.selectedBandId

    return Button {
      viewModel.selectBand(id: band.id)
    } label: {
      VStack(spacing: 2) {
        Text(formatFrequency(band.frequency))
          .font(.caption2)
        Text(formatGain(band.gain))
          .font(.caption.bold())
      }
      .padding(.horizontal, 10)
      .padding(.vertical, 6)
      .background(
        RoundedRectangle(cornerRadius: 8)
          .fill(isSelected ? accentColor : Color(.tertiarySystemBackground))
      )
      .foregroundColor(isSelected ? .white : (band.bypass ? .secondary : .primary))
      .overlay(
        RoundedRectangle(cornerRadius: 8)
          .stroke(band.bypass ? Color.orange : Color.clear, lineWidth: 1)
      )
    }
    .buttonStyle(.plain)
  }

  // MARK: - Helpers

  private func notifyChange() {
    let setting = viewModel.toSetting()
    onSettingChanged(setting)
  }

  private func formatFrequency(_ freq: Float) -> String {
    if freq >= 1000 {
      return String(format: "%.1fk", freq / 1000)
    } else {
      return String(format: "%.0f", freq)
    }
  }

  private func formatGain(_ gain: Float) -> String {
    let sign = gain >= 0 ? "+" : ""
    return String(format: "%@%.1f", sign, gain)
  }
}
