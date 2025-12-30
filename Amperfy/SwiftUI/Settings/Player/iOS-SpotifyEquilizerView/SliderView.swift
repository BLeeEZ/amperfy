import AmperfyKit
import SwiftUI

struct SliderView: View {
  @Binding
  var sliderValue: CGFloat
  var range: ClosedRange<CGFloat> = -12...12
  var sliderFrameHeight: CGFloat
  var sliderTintColor: Color

  var body: some View {
    VStack(spacing: 8) {
      GeometryReader { geometry in
        let height = geometry.size.height
        let width = geometry.size.width
        
        let safeSliderValue = sliderValue.isNaN ? 0 : sliderValue
        let rangeWidth = range.upperBound - range.lowerBound
        let safeRangeWidth = rangeWidth == 0 ? 1 : rangeWidth
        
        ZStack(alignment: .bottom) {
          // Track
          Capsule()
            .fill(Color.secondary.opacity(0.1))
            .frame(width: width * 0.4)
          
          // Progress
          let progressHeight = safeRangeWidth > 0 ? (height * (safeSliderValue - range.lowerBound) / safeRangeWidth) : 0
          Capsule()
            .fill(sliderTintColor.opacity(0.3))
            .frame(width: width * 0.4, height: max(0, min(height, progressHeight)))
          
          // Thumb (Pill)
          let thumbPosition = height - (safeRangeWidth > 0 ? (height * (safeSliderValue - range.lowerBound) / safeRangeWidth) : 0)
          
          RoundedRectangle(cornerRadius: 4)
            .fill(Color(UIColor.secondarySystemBackground))
            .frame(width: width * 0.8, height: 24)
            .overlay(
              Rectangle()
                .fill(sliderTintColor.opacity(0.8))
                .frame(height: 2)
                .padding(.horizontal, 4)
            )
            .shadow(radius: 1)
            .offset(y: (thumbPosition.isNaN ? 0 : thumbPosition) - height + 12)
        }
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle()) // Make the whole area tappable
        .gesture(
          DragGesture(minimumDistance: 0)
            .onChanged { value in
              guard height > 0 else { return }
              let delta = value.location.y / height
              let newValue = range.upperBound - (delta * safeRangeWidth)
              let finalizedValue = min(max(newValue, range.lowerBound), range.upperBound)
              if !finalizedValue.isNaN {
                sliderValue = finalizedValue
              }
            }
        )
      }
      .frame(height: sliderFrameHeight)
      
      Text(String(format: "%+.1fdB", sliderValue.isNaN ? 0 : sliderValue))
        .font(.system(size: 10, weight: .medium, design: .monospaced))
        .padding(.horizontal, 4)
        .padding(.vertical, 2)
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(4)
    }
  }
}
