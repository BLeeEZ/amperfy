import SwiftUI

public struct AmplitudeSpectrumView: View {
  let shapeType: ShapeType
  let magnitudes: [Magnitude]
  let range: Range<Int>
  let hue: Double?
  let rms: Float?

  public init(shapeType: ShapeType, magnitudes: [Magnitude], range: Range<Int>?, rms: Float?) {
    self.shapeType = shapeType
    self.magnitudes = magnitudes
    self.range = range ?? magnitudes.indices
    self.hue = nil
    self.rms = rms
  }

  public var body: some View {
    Canvas { context, size in
      let color = if let hue {
        Color(hue: hue, saturation: 0.7, brightness: 0.8)
      } else {
        Color.primary
      }
      switch shapeType {
      case .straight:
        let unit = size.width / CGFloat(range.count)
        let width = 0.8 * unit
        let radius = 0.5 * width
        range.forEach { index in
          let x = unit * CGFloat(index)
          let height = size.height * CGFloat(magnitudes[index].value)
          let y = 0.5 * (size.height - height)
          let path = Path(
            roundedRect: CGRect(x: x, y: y, width: width, height: height),
            cornerRadius: radius
          )
          context.fill(path, with: .color(color))
        }
      case .ring:
        let center = CGPoint(x: 0.5 * size.width, y: 0.5 * size.height)
        let sideLength = min(size.width, size.height)
        let radiusInner = sideLength / 4.0
        let radiusOuter = 0.95 * (sideLength / 2.0)
        let availableBarLenght = radiusOuter - radiusInner
        let width = 1.6 * CGFloat.pi * radiusInner / CGFloat(range.count)
        let strokeStyle = StrokeStyle(lineWidth: width, lineCap: .round)
        range.forEach { index in
          let phi = (2.0 * CGFloat.pi * CGFloat(index) / CGFloat(range.count)) + (CGFloat.pi / 2)
          let radius2 = radiusInner + (availableBarLenght * CGFloat(magnitudes[index].value))
          var path = Path()
          path.move(to: CGPoint(
            x: center.x + radiusInner * cos(phi),
            y: center.y + radiusInner * sin(phi)
          ))
          path.addLine(to: CGPoint(
            x: center.x + radius2 * cos(phi),
            y: center.y + radius2 * sin(phi)
          ))
          context.stroke(path, with: .color(color), style: strokeStyle)
        }
        if let rms {
          let loudnessSideLength = radiusInner * CGFloat(rms)
          let loudnessRectOrigin = CGPoint(
            x: center.x - (loudnessSideLength / 2),
            y: center.y - (loudnessSideLength / 2)
          )
          let loudnessRect = CGRect(
            origin: loudnessRectOrigin,
            size: CGSizeMake(loudnessSideLength, loudnessSideLength)
          )
          let path = Circle().path(in: loudnessRect)
          context.fill(path, with: .color(color))
        }
      }
    }
  }
}

#Preview {
  AmplitudeSpectrumView(shapeType: .straight, magnitudes: [], range: nil, rms: nil)
}
