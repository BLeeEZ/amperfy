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

      // Glow effect
      let glowStyle = StrokeStyle(lineWidth: lineWidth + 4, lineCap: .round, lineJoin: .round)
      context.stroke(path, with: .color(.primary.opacity(0.3)), style: glowStyle)

      // Main waveform line
      let mainStyle = StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round)
      context.stroke(path, with: .color(.primary), style: mainStyle)
    }
  }
}

#Preview {
  WaveformView(magnitudes: [], rms: nil)
}
