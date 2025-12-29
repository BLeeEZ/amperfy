//
//  SpectrumBarsView.swift
//  AmperfyKit
//
//  Created by Aarav Chourishi on 29.12.25.
//  Copyright (c) 2025 Aarav Chourishi. All rights reserved.
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

/// Frequency-based spectrum bar visualization (classic equalizer style)
public struct SpectrumBarsView: View {
  let magnitudes: [Magnitude]
  let barCount: Int

  public init(magnitudes: [Magnitude], barCount: Int = 32) {
    self.magnitudes = magnitudes
    self.barCount = barCount
  }

  private func groupedMagnitudes() -> [Float] {
    guard !magnitudes.isEmpty else {
      return Array(repeating: 0, count: barCount)
    }

    let groupSize = max(1, magnitudes.count / barCount)
    var grouped = [Float]()

    for i in 0 ..< barCount {
      let startIndex = i * groupSize
      let endIndex = min(startIndex + groupSize, magnitudes.count)
      if startIndex < magnitudes.count {
        let slice = magnitudes[startIndex ..< endIndex]
        let avg = slice.reduce(0) { $0 + $1.value } / Float(max(1, slice.count))
        grouped.append(avg)
      } else {
        grouped.append(0)
      }
    }
    return grouped
  }

  private func barColor(for index: Int, total: Int) -> Color {
    let hue = Double(index) / Double(total) * 0.7
    return Color(hue: hue, saturation: 0.8, brightness: 0.9)
  }

  public var body: some View {
    Canvas { context, size in
      let bars = groupedMagnitudes()
      let spacing: CGFloat = 2
      let totalSpacing = spacing * CGFloat(bars.count - 1)
      let barWidth = (size.width - totalSpacing) / CGFloat(bars.count)
      let cornerRadius = barWidth * 0.3

      for (index, value) in bars.enumerated() {
        let x = CGFloat(index) * (barWidth + spacing)
        let height = max(4, CGFloat(value) * size.height * 0.9)
        let y = size.height - height

        let rect = CGRect(x: x, y: y, width: barWidth, height: height)
        let path = Path(roundedRect: rect, cornerRadius: cornerRadius)

        let gradient = Gradient(colors: [
          barColor(for: index, total: bars.count),
          barColor(for: index, total: bars.count).opacity(0.6),
        ])
        context.fill(
          path,
          with: .linearGradient(
            gradient,
            startPoint: CGPoint(x: x, y: y),
            endPoint: CGPoint(x: x, y: size.height)
          )
        )
      }
    }
  }
}

#Preview {
  SpectrumBarsView(magnitudes: [])
}
