import SwiftUI

/// Circular/radial visualization with rotating elements and pulsating center
public struct RadialVisualizerView: View {
  let magnitudes: [Magnitude]
  let rms: Float?
  let range: Range<Int>

  @State private var rotation: Double = 0

  public init(magnitudes: [Magnitude], range: Range<Int>?, rms: Float?) {
    self.magnitudes = magnitudes
    self.range = range ?? magnitudes.indices
    self.rms = rms
  }

  public var body: some View {
    TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { timeline in
      Canvas { context, size in
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let sideLength = min(size.width, size.height)
        let radiusInner = sideLength / 5.0
        let radiusOuter = sideLength / 2.2

        let rotationAngle = timeline.date.timeIntervalSinceReferenceDate * 0.3

        // Draw outer rotating ring segments
        let segmentCount = min(range.count, 64)
        let availableLength = radiusOuter - radiusInner

        for i in 0..<segmentCount {
          let magnitudeIndex = range.lowerBound + (i * range.count / segmentCount)
          guard magnitudeIndex < magnitudes.count else { continue }

          let magnitude = magnitudes[magnitudeIndex].value
          let angle = (2.0 * .pi * Double(i) / Double(segmentCount)) + rotationAngle
          let segmentLength = radiusInner + (availableLength * CGFloat(magnitude))

          let hue = Double(i) / Double(segmentCount)
          let color = Color(hue: hue, saturation: 0.7, brightness: 0.9)

          var path = Path()
          path.move(
            to: CGPoint(
              x: center.x + radiusInner * cos(angle),
              y: center.y + radiusInner * sin(angle)
            ))
          path.addLine(
            to: CGPoint(
              x: center.x + segmentLength * cos(angle),
              y: center.y + segmentLength * sin(angle)
            ))

          let lineWidth = 3.0 + CGFloat(magnitude) * 4.0
          context.stroke(
            path,
            with: .color(color),
            style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
          )
        }

        // Draw pulsating center circle
        let rmsValue = CGFloat(rms ?? 0.3)
        let pulseRadius = radiusInner * 0.6 * (0.5 + rmsValue)

        let gradient = Gradient(colors: [
          Color.white.opacity(0.8),
          Color.primary.opacity(0.4),
        ])
        let centerRect = CGRect(
          x: center.x - pulseRadius,
          y: center.y - pulseRadius,
          width: pulseRadius * 2,
          height: pulseRadius * 2
        )
        let circlePath = Circle().path(in: centerRect)
        context.fill(
          circlePath,
          with: .radialGradient(
            gradient,
            center: center,
            startRadius: 0,
            endRadius: pulseRadius
          )
        )

        // Draw inner ring
        let innerRingRect = CGRect(
          x: center.x - radiusInner,
          y: center.y - radiusInner,
          width: radiusInner * 2,
          height: radiusInner * 2
        )
        let innerRingPath = Circle().path(in: innerRingRect)
        context.stroke(
          innerRingPath,
          with: .color(.primary.opacity(0.3)),
          style: StrokeStyle(lineWidth: 2)
        )
      }
    }
  }
}

#Preview {
  RadialVisualizerView(magnitudes: [], range: nil, rms: nil)
}
