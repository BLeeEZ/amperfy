//
//  WaveformView.swift
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

/// Amplitude-based oscilloscope-style waveform visualization
public struct WaveformView: View {
  let magnitudes: [Magnitude]
  let rms: Float?

  public init(magnitudes: [Magnitude], rms: Float?) {
    self.magnitudes = magnitudes
    self.rms = rms
  }

  public var body: some View {
    Canvas { context, size in
      let lineWidth = max(2.0, CGFloat(rms ?? 0.3) * 6.0)
      let midY = size.height / 2

      guard magnitudes.count > 1 else { return }

      var path = Path()
      let step = size.width / CGFloat(magnitudes.count - 1)

      for (index, magnitude) in magnitudes.enumerated() {
        let x = CGFloat(index) * step
        let amplitude = CGFloat(magnitude.value) * size.height * 0.4
        let y = midY + (index % 2 == 0 ? amplitude : -amplitude)

        if index == 0 {
          path.move(to: CGPoint(x: x, y: y))
        } else {
          let prevX = CGFloat(index - 1) * step
          let prevMagnitude = magnitudes[index - 1]
          let prevAmplitude = CGFloat(prevMagnitude.value) * size.height * 0.4
          let prevY = midY + ((index - 1) % 2 == 0 ? prevAmplitude : -prevAmplitude)

          let controlX1 = prevX + step * 0.5
          let controlX2 = x - step * 0.5
          path.addCurve(
            to: CGPoint(x: x, y: y),
            control1: CGPoint(x: controlX1, y: prevY),
            control2: CGPoint(x: controlX2, y: y)
          )
        }
      }

      // Main waveform line
      let mainStyle = StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round)
      context.stroke(path, with: .color(.primary), style: mainStyle)
    }
  }
}

#Preview {
  WaveformView(magnitudes: [], rms: nil)
}
