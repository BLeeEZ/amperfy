import AmperfyKit
import SwiftUI

public struct EqualizerView: View {
  public var sliderFrameHeight: CGFloat
  public var sliderTintColor: Color
  public var gradientColors: [Color]
  @Binding
  public var sliderValues: [CGFloat]
  @Binding
  private var sliderLabel: [String]

  public init(
    sliderLabels: Binding<[String]>,
    sliderValues: Binding<[CGFloat]>,
    sliderFrameHeight: CGFloat = 200,
    sliderTintColor: Color,
    gradientColors: [Color]
  ) {
    self._sliderValues = sliderValues
    self._sliderLabel = sliderLabels
    self.sliderFrameHeight = sliderFrameHeight
    self.sliderTintColor = sliderTintColor
    self.gradientColors = gradientColors
  }

  public var body: some View {
    VStack(spacing: 8) {
      // Frequency Labels (Top Pills)
      HStack(spacing: 4) {
        ForEach(0..<sliderLabel.count, id: \.self) { i in
          Text(sliderLabel[i])
            .font(.system(size: 10, weight: .medium))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.secondary.opacity(0.1))
            .cornerRadius(4)
            .frame(maxWidth: .infinity)
        }
      }
      .padding(.horizontal, 4)

      // Sliders with Grid Background
      ZStack {
        // Grid Lines
        VStack(spacing: 0) {
          ForEach(0...10, id: \.self) { i in
            Divider()
              .background(Color.secondary.opacity(0.2))
              .frame(maxHeight: .infinity)
          }
        }
        
        // Horizontal separators for bands
        HStack(spacing: 0) {
          ForEach(0..<sliderValues.count, id: \.self) { _ in
            Divider()
              .background(Color.secondary.opacity(0.1))
              .frame(maxWidth: .infinity)
          }
        }
        
        // The actual sliders
        HStack(spacing: 4) {
          ForEach(0..<sliderValues.count, id: \.self) { i in
            SliderView(
              sliderValue: $sliderValues[i],
              range: -12...12,
              sliderFrameHeight: sliderFrameHeight,
              sliderTintColor: sliderTintColor
            )
            .frame(maxWidth: .infinity)
          }
        }
      }
      .frame(height: sliderFrameHeight + 40) // Extra space for labels at bottom if any
      .padding(4)
      .background(Color.secondary.opacity(0.05))
      .cornerRadius(8)
    }
  }
}
