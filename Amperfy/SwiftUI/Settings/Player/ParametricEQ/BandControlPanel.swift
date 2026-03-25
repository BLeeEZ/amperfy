//
//  BandControlPanel.swift
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

// MARK: - BandControlPanel

struct BandControlPanel: View {
  @Binding
  var band: ParametricBand
  var accentColor: Color
  var onDelete: () -> ()

  @State
  private var frequencyText: String = ""
  @State
  private var gainText: String = ""
  @State
  private var qText: String = ""

  var body: some View {
    VStack(spacing: 12) {
      // Filter type picker
      HStack {
        Text("Type")
          .foregroundColor(.secondary)
        Spacer()
        Picker("Filter Type", selection: $band.filterType) {
          Text("Bell").tag(ParametricBandFilterType.bell)
          Text("Low Shelf").tag(ParametricBandFilterType.lowShelf)
          Text("High Shelf").tag(ParametricBandFilterType.highShelf)
        }
        .pickerStyle(.menu)
        .tint(accentColor)
      }

      Divider()

      // Frequency control
      VStack(alignment: .leading, spacing: 4) {
        HStack {
          Text("Frequency")
            .foregroundColor(.secondary)
          Spacer()
          Text(formatFrequency(band.frequency))
            .font(.system(.body, design: .monospaced))
            .foregroundColor(accentColor)
        }

        LogarithmicSlider(
          value: $band.frequency,
          range: ParametricBand.frequencyRange,
          accentColor: accentColor
        )
      }

      Divider()

      // Gain control
      VStack(alignment: .leading, spacing: 4) {
        HStack {
          Text("Gain")
            .foregroundColor(.secondary)
          Spacer()
          Text(formatGain(band.gain))
            .font(.system(.body, design: .monospaced))
            .foregroundColor(accentColor)
        }

        Slider(
          value: $band.gain,
          in: ParametricBand.gainRange,
          step: 0.1
        )
        .tint(accentColor)
      }

      // Q control (only for Bell filters)
      if band.filterType == .bell {
        Divider()

        VStack(alignment: .leading, spacing: 4) {
          HStack {
            Text("Q (Bandwidth)")
              .foregroundColor(.secondary)
            Spacer()
            Text(String(format: "%.2f", band.q))
              .font(.system(.body, design: .monospaced))
              .foregroundColor(accentColor)
          }

          LogarithmicSlider(
            value: $band.q,
            range: ParametricBand.qRange,
            accentColor: accentColor
          )
        }
      }

      Divider()

      // Bypass and Delete
      HStack {
        Toggle("Bypass", isOn: $band.bypass)
          .tint(accentColor)

        Spacer()

        Button(role: .destructive) {
          onDelete()
        } label: {
          Label("Delete", systemImage: "trash")
        }
        .buttonStyle(.bordered)
      }
    }
    .padding()
    .background(Color(.secondarySystemBackground))
    .cornerRadius(12)
  }

  // MARK: - Helpers

  private func formatFrequency(_ freq: Float) -> String {
    if freq >= 1000 {
      return String(format: "%.1f kHz", freq / 1000)
    } else {
      return String(format: "%.0f Hz", freq)
    }
  }

  private func formatGain(_ gain: Float) -> String {
    let sign = gain >= 0 ? "+" : ""
    return String(format: "%@%.1f dB", sign, gain)
  }
}

// MARK: - LogarithmicSlider

struct LogarithmicSlider: View {
  @Binding
  var value: Float
  let range: ClosedRange<Float>
  var accentColor: Color

  private var logValue: Binding<Double> {
    Binding(
      get: {
        let logMin = log10(Double(range.lowerBound))
        let logMax = log10(Double(range.upperBound))
        let logVal = log10(Double(value))
        return (logVal - logMin) / (logMax - logMin)
      },
      set: { newValue in
        let logMin = log10(Double(range.lowerBound))
        let logMax = log10(Double(range.upperBound))
        let logVal = logMin + newValue * (logMax - logMin)
        value = Float(pow(10, logVal)).clamped(to: range)
      }
    )
  }

  var body: some View {
    Slider(value: logValue, in: 0 ... 1)
      .tint(accentColor)
  }
}

// MARK: - NoBandSelectedView

struct NoBandSelectedView: View {
  var body: some View {
    VStack(spacing: 8) {
      Image(systemName: "slider.horizontal.3")
        .font(.largeTitle)
        .foregroundColor(.secondary)
      Text("Select a band to edit")
        .foregroundColor(.secondary)
      Text("Drag nodes on the curve or tap to select")
        .font(.caption)
        .foregroundColor(.secondary)
    }
    .frame(maxWidth: .infinity)
    .padding()
    .background(Color(.secondarySystemBackground))
    .cornerRadius(12)
  }
}
