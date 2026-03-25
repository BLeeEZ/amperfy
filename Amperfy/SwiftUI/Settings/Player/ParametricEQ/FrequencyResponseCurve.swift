//
//  FrequencyResponseCurve.swift
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

// MARK: - FrequencyResponseCurve

struct FrequencyResponseCurve: View {
  @Binding
  var bands: [ParametricBand]
  @Binding
  var selectedBandId: UUID?
  var globalBypass: Bool
  var accentColor: Color

  let onBandDragStart: () -> ()
  let onBandDrag: (UUID, Float, Float) -> ()
  let onBandDragEnd: () -> ()
  let onBandSelect: (UUID?) -> ()

  // Constants
  private let minFreq: Float = 20
  private let maxFreq: Float = 20000
  private let minGain: Float = -12
  private let maxGain: Float = 12
  private let sampleRate: Float = 44100

  // Frequency labels for the grid
  private let freqLabels: [(Float, String)] = [
    (20, "20"), (50, "50"), (100, "100"), (200, "200"),
    (500, "500"), (1000, "1k"), (2000, "2k"), (5000, "5k"),
    (10000, "10k"), (20000, "20k"),
  ]

  // Gain labels for the grid
  private let gainLabels: [Float] = [-12, -6, 0, 6, 12]

  var body: some View {
    GeometryReader { geometry in
      let size = geometry.size
      ZStack {
        // Background grid
        gridView(size: size)

        // Frequency response curve
        responseCurvePath(size: size)
          .stroke(
            globalBypass ? Color.gray : accentColor,
            lineWidth: 2
          )

        // Filled area under curve
        responseCurveFilledPath(size: size)
          .fill(
            LinearGradient(
              gradient: Gradient(colors: [
                (globalBypass ? Color.gray : accentColor).opacity(0.3),
                Color.clear,
              ]),
              startPoint: .top,
              endPoint: .bottom
            )
          )

        // Band nodes (draggable)
        ForEach(bands) { band in
          bandNode(band: band, size: size)
        }
      }
      .contentShape(Rectangle())
      .gesture(
        DragGesture(minimumDistance: 0)
          .onEnded { value in
            // Tap on empty space deselects
            let location = value.location
            if !isNearAnyBand(location: location, size: size) {
              onBandSelect(nil)
            }
          }
      )
    }
    .aspectRatio(2.5, contentMode: .fit)
  }

  // MARK: - Grid View

  @ViewBuilder
  private func gridView(size: CGSize) -> some View {
    ZStack {
      // Vertical frequency lines (logarithmic)
      ForEach(freqLabels, id: \.0) { freq, label in
        let x = freqToX(freq, width: size.width)
        Path { path in
          path.move(to: CGPoint(x: x, y: 0))
          path.addLine(to: CGPoint(x: x, y: size.height))
        }
        .stroke(Color.gray.opacity(0.3), lineWidth: 0.5)

        Text(label)
          .font(.system(size: 9))
          .foregroundColor(.secondary)
          .position(x: x, y: size.height - 8)
      }

      // Horizontal gain lines
      ForEach(gainLabels, id: \.self) { gain in
        let y = gainToY(gain, height: size.height)
        Path { path in
          path.move(to: CGPoint(x: 0, y: y))
          path.addLine(to: CGPoint(x: size.width, y: y))
        }
        .stroke(
          gain == 0 ? Color.gray.opacity(0.6) : Color.gray.opacity(0.3),
          lineWidth: gain == 0 ? 1 : 0.5
        )

        Text("\(Int(gain)) dB")
          .font(.system(size: 9))
          .foregroundColor(.secondary)
          .position(x: 24, y: y)
      }
    }
  }

  // MARK: - Response Curve

  private func responseCurvePath(size: CGSize) -> Path {
    Path { path in
      let points = calculateResponsePoints(size: size)
      guard let first = points.first else { return }
      path.move(to: first)
      for point in points.dropFirst() {
        path.addLine(to: point)
      }
    }
  }

  private func responseCurveFilledPath(size: CGSize) -> Path {
    Path { path in
      let points = calculateResponsePoints(size: size)
      guard let first = points.first else { return }
      path.move(to: CGPoint(x: first.x, y: size.height))
      path.addLine(to: first)
      for point in points.dropFirst() {
        path.addLine(to: point)
      }
      if let last = points.last {
        path.addLine(to: CGPoint(x: last.x, y: size.height))
      }
      path.closeSubpath()
    }
  }

  private func calculateResponsePoints(size: CGSize) -> [CGPoint] {
    let numPoints = Int(size.width)
    var points: [CGPoint] = []

    for i in 0 ..< numPoints {
      let x = CGFloat(i)
      let freq = xToFreq(Float(x), width: Float(size.width))
      let totalGain = calculateTotalGain(at: freq)
      let y = gainToY(totalGain, height: size.height)
      points.append(CGPoint(x: x, y: y))
    }

    return points
  }

  private func calculateTotalGain(at freq: Float) -> Float {
    guard !globalBypass else { return 0 }

    var totalGain: Float = 0

    for band in bands where !band.bypass {
      let bandGain = calculateBandResponse(band: band, at: freq)
      totalGain += bandGain
    }

    return totalGain.clamped(to: minGain ... maxGain)
  }

  // MARK: - Biquad Filter Response Calculation

  private func calculateBandResponse(band: ParametricBand, at freq: Float) -> Float {
    // Calculate biquad filter frequency response
    let w0 = 2 * Float.pi * band.frequency / sampleRate
    let A = pow(10, band.gain / 40) // Gain in linear form (sqrt for amplitude)

    let cosW0 = cos(w0)
    let sinW0 = sin(w0)
    let alpha = sinW0 / (2 * band.q)

    var b0: Float = 1, b1: Float = 0, b2: Float = 0
    var a0: Float = 1, a1: Float = 0, a2: Float = 0

    switch band.filterType {
    case .bell:
      // Peaking EQ
      b0 = 1 + alpha * A
      b1 = -2 * cosW0
      b2 = 1 - alpha * A
      a0 = 1 + alpha / A
      a1 = -2 * cosW0
      a2 = 1 - alpha / A

    case .lowShelf:
      // Low shelf
      let sqrtA = sqrt(A)
      let sqrtA2Alpha = 2 * sqrtA * alpha
      b0 = A * ((A + 1) - (A - 1) * cosW0 + sqrtA2Alpha)
      b1 = 2 * A * ((A - 1) - (A + 1) * cosW0)
      b2 = A * ((A + 1) - (A - 1) * cosW0 - sqrtA2Alpha)
      a0 = (A + 1) + (A - 1) * cosW0 + sqrtA2Alpha
      a1 = -2 * ((A - 1) + (A + 1) * cosW0)
      a2 = (A + 1) + (A - 1) * cosW0 - sqrtA2Alpha

    case .highShelf:
      // High shelf
      let sqrtA = sqrt(A)
      let sqrtA2Alpha = 2 * sqrtA * alpha
      b0 = A * ((A + 1) + (A - 1) * cosW0 + sqrtA2Alpha)
      b1 = -2 * A * ((A - 1) + (A + 1) * cosW0)
      b2 = A * ((A + 1) + (A - 1) * cosW0 - sqrtA2Alpha)
      a0 = (A + 1) - (A - 1) * cosW0 + sqrtA2Alpha
      a1 = 2 * ((A - 1) - (A + 1) * cosW0)
      a2 = (A + 1) - (A - 1) * cosW0 - sqrtA2Alpha
    }

    // Normalize coefficients
    b0 /= a0
    b1 /= a0
    b2 /= a0
    a1 /= a0
    a2 /= a0

    // Calculate frequency response at the given frequency
    let w = 2 * Float.pi * freq / sampleRate
    let cosW = cos(w)
    let cos2W = cos(2 * w)
    let sinW = sin(w)
    let sin2W = sin(2 * w)

    // H(e^jw) = (b0 + b1*e^-jw + b2*e^-2jw) / (1 + a1*e^-jw + a2*e^-2jw)
    let numReal = b0 + b1 * cosW + b2 * cos2W
    let numImag = -(b1 * sinW + b2 * sin2W)
    let denReal = 1 + a1 * cosW + a2 * cos2W
    let denImag = -(a1 * sinW + a2 * sin2W)

    let numMag = sqrt(numReal * numReal + numImag * numImag)
    let denMag = sqrt(denReal * denReal + denImag * denImag)

    let magnitude = numMag / denMag
    let gainDb = 20 * log10(max(magnitude, 0.0001))

    return gainDb
  }

  // MARK: - Band Nodes

  @ViewBuilder
  private func bandNode(band: ParametricBand, size: CGSize) -> some View {
    let x = freqToX(band.frequency, width: size.width)
    let y = gainToY(band.gain, height: size.height)
    let isSelected = band.id == selectedBandId

    Circle()
      .fill(band.bypass ? Color.gray : accentColor)
      .frame(width: isSelected ? 20 : 14, height: isSelected ? 20 : 14)
      .overlay(
        Circle()
          .stroke(isSelected ? Color.white : Color.clear, lineWidth: 2)
      )
      .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
      .position(x: x, y: y)
      .gesture(
        DragGesture()
          .onChanged { value in
            onBandSelect(band.id)
            onBandDragStart()
            let newFreq = xToFreq(Float(value.location.x), width: Float(size.width))
            let newGain = yToGain(Float(value.location.y), height: Float(size.height))
            onBandDrag(band.id, newFreq, newGain)
          }
          .onEnded { _ in
            onBandDragEnd()
          }
      )
      .onTapGesture {
        onBandSelect(band.id)
      }
  }

  // MARK: - Coordinate Conversion

  private func freqToX(_ freq: Float, width: CGFloat) -> CGFloat {
    // Logarithmic scale
    let logMin = log10(minFreq)
    let logMax = log10(maxFreq)
    let logFreq = log10(freq.clamped(to: minFreq ... maxFreq))
    return CGFloat((logFreq - logMin) / (logMax - logMin)) * width
  }

  private func xToFreq(_ x: Float, width: Float) -> Float {
    let logMin = log10(minFreq)
    let logMax = log10(maxFreq)
    let logFreq = logMin + (x / width) * (logMax - logMin)
    return pow(10, logFreq).clamped(to: minFreq ... maxFreq)
  }

  private func gainToY(_ gain: Float, height: CGFloat) -> CGFloat {
    // Linear scale, inverted (positive gain at top)
    let normalizedGain = (gain - minGain) / (maxGain - minGain)
    return CGFloat(1 - normalizedGain) * height
  }

  private func yToGain(_ y: Float, height: Float) -> Float {
    let normalizedY = 1 - (y / height)
    return (normalizedY * (maxGain - minGain) + minGain).clamped(to: minGain ... maxGain)
  }

  private func isNearAnyBand(location: CGPoint, size: CGSize) -> Bool {
    let threshold: CGFloat = 20
    for band in bands {
      let x = freqToX(band.frequency, width: size.width)
      let y = gainToY(band.gain, height: size.height)
      let distance = sqrt(pow(location.x - x, 2) + pow(location.y - y, 2))
      if distance < threshold {
        return true
      }
    }
    return false
  }
}
