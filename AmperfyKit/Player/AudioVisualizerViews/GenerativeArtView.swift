//
//  GenerativeArtView.swift
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

/// Procedural/generative art visualization with particle effects
public struct GenerativeArtView: View {
  let magnitudes: [Magnitude]
  let rms: Float?

  public init(magnitudes: [Magnitude], rms: Float?) {
    self.magnitudes = magnitudes
    self.rms = rms
  }

  private func bassEnergy() -> Float {
    guard magnitudes.count > 10 else { return 0.3 }
    return magnitudes[0 ..< 10].reduce(0) { $0 + $1.value } / 10.0
  }

  private func midEnergy() -> Float {
    guard magnitudes.count > 50 else { return 0.3 }
    return magnitudes[10 ..< 50].reduce(0) { $0 + $1.value } / 40.0
  }

  private func trebleEnergy() -> Float {
    guard magnitudes.count > 50 else { return 0.3 }
    let end = min(magnitudes.count, 100)
    return magnitudes[50 ..< end].reduce(0) { $0 + $1.value } / Float(end - 50)
  }

  public var body: some View {
    TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
      Canvas { context, size in
        let time = timeline.date.timeIntervalSinceReferenceDate
        let center = CGPoint(x: size.width / 2, y: size.height / 2)

        let bass = CGFloat(bassEnergy())
        let mid = CGFloat(midEnergy())
        let treble = CGFloat(trebleEnergy())
        let rmsVal = CGFloat(rms ?? 0.3)

        // Draw flowing organic shapes
        let layers = 5
        for layer in 0 ..< layers {
          let layerOffset = Double(layer) * 0.5
          let baseRadius = min(size.width, size.height) * 0.15 * (1 + CGFloat(layer) * 0.3)

          var path = Path()
          let points = 60
          for i in 0 ... points {
            let angle = Double(i) / Double(points) * 2 * .pi
            let noise1 = sin(angle * 3 + time * 2 + layerOffset) * bass * 30
            let noise2 = cos(angle * 5 + time * 1.5) * mid * 20
            let noise3 = sin(angle * 7 + time * 3) * treble * 15

            let radius = baseRadius + noise1 + noise2 + noise3 + rmsVal * 20
            let x = center.x + radius * cos(angle)
            let y = center.y + radius * sin(angle)

            if i == 0 {
              path.move(to: CGPoint(x: x, y: y))
            } else {
              path.addLine(to: CGPoint(x: x, y: y))
            }
          }
          path.closeSubpath()

          let hue = (time * 0.1 + Double(layer) * 0.15).truncatingRemainder(dividingBy: 1.0)
          let color = Color(hue: hue, saturation: 0.6, brightness: 0.85)
          let opacity = 0.3 - Double(layer) * 0.04

          context.fill(path, with: .color(color.opacity(opacity)))
          context.stroke(
            path,
            with: .color(color.opacity(opacity + 0.2)),
            style: StrokeStyle(lineWidth: 1.5)
          )
        }

        // Draw particle-like dots
        let particleCount = 30
        for i in 0 ..< particleCount {
          let seed = Double(i) * 1.618
          let angle = seed + time * (0.2 + bass * 0.5)
          let distance =
            40 + sin(seed * 3 + time) * 30 * mid + CGFloat(i) * 3 * (1 + rmsVal)

          let x = center.x + distance * cos(angle)
          let y = center.y + distance * sin(angle)

          let particleSize = 2 + treble * 6
          let particleRect = CGRect(
            x: x - particleSize / 2,
            y: y - particleSize / 2,
            width: particleSize,
            height: particleSize
          )

          let hue = (seed / Double(particleCount) + time * 0.05)
            .truncatingRemainder(dividingBy: 1.0)
          let particleColor = Color(hue: hue, saturation: 0.7, brightness: 0.95)

          context.fill(Circle().path(in: particleRect), with: .color(particleColor))
        }
      }
    }
  }
}

#Preview {
  GenerativeArtView(magnitudes: [], rms: nil)
}
