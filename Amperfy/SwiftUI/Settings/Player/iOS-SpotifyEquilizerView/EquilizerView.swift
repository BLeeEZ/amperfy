// The Swift Programming Language
// https://docs.swift.org/swift-book

import AmperfyKit
import SwiftUI

// MARK: - EqualizerView

public struct EqualizerView: View {
  private var frequency: Int
  public var sliderFrameHeight: CGFloat
  public var sliderTintColor: Color
  public var gradientColors: [Color]
  @Binding
  public var sliderValues: [CGFloat]
  @State
  private var viewWidth: CGFloat = 300
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
    self.frequency = sliderValues.count - 1
    self.sliderFrameHeight = sliderFrameHeight
    self.sliderTintColor = sliderTintColor
    self.gradientColors = gradientColors
  }

  public var body: some View {
    GeometryReader { geometry in
      let sliderWidth: CGFloat = (geometry.size.width - 35) / CGFloat(frequency + 2)
      let spacing: CGFloat = 0
      HStack(alignment: .top, spacing: 0) {
        addScale(sliderWidth: sliderWidth)
          .frame(width: 35, height: 200)
        VStack {
          ZStack(alignment: .top) {
            addScaleLines(sliderWidth: sliderWidth)
            addEqPath(spacing: spacing, sliderWidth: sliderWidth)
            setSlider(sliderWidth: sliderWidth)
          }
          .frame(height: 200)
          setSliderLabel(sliderWidth: sliderWidth)
        }
      }
      .background(
        Color.clear
      )
    }
    .frame(height: 220)
  }
}

extension EqualizerView {
  func addEqPath(spacing: CGFloat, sliderWidth: CGFloat) -> some View {
    ZStack {
      EqualizerPathTopLine(
        sliderValues: sliderValues,
        sliderFrameH: sliderFrameHeight,
        sliderSpacing: spacing,
        sliderWidth: sliderWidth
      )
      .stroke(sliderTintColor, lineWidth: 3)

      EqualizerPath(
        sliderValues: sliderValues,
        sliderFrameH: sliderFrameHeight,
        sliderSpacing: spacing,
        sliderWidth: sliderWidth
      )
      .fill(
        LinearGradient(
          gradient: Gradient(colors: self.gradientColors),
          startPoint: .top,
          endPoint: .bottom
        )
      )
      .animation(.easeInOut, value: sliderValues)
    }
  }

  func setSlider(sliderWidth: CGFloat) -> some View {
    HStack(spacing: 0) {
      ForEach(0 ... frequency, id: \.self) { i in
        SliderView(
          sliderValue: $sliderValues[i],
          sliderFrameHeight: sliderFrameHeight,
          sliderTintColor: sliderTintColor
        )
        .frame(width: sliderWidth)
      }
    }
  }

  func setSliderLabel(sliderWidth: CGFloat) -> some View {
    HStack(spacing: 0) {
      ForEach(0 ... sliderLabel.count - 1, id: \.self) { i in
        Text(sliderLabel[i])
          .fontWeight(.thin)
          .lineLimit(1)
          .minimumScaleFactor(0.8)
          .frame(width: sliderWidth)
          .font(.system(size: 14))
      }
    }
  }

  func addScale(sliderWidth: CGFloat) -> some View {
    // For ±24dB range (eqMac official spec), we show labels at +24, +12, 0, -12, -24
    // Number of steps from 0 to max (24/6 = 4 steps of 6dB each)
    VStack {
      // Positive dB values (top)
      ForEach([4, 3, 2, 1], id: \.self) { i in
        Text("+\(i * 6)")
          .fontWeight(.thin)
          .lineLimit(1)
          .minimumScaleFactor(0.6)
          .font(.system(size: 11))
          .foregroundColor(.secondary)
          .frame(maxHeight: .infinity)
      }

      // 0 dB center line
      Text("0 dB")
        .fontWeight(.semibold)
        .lineLimit(1)
        .minimumScaleFactor(0.6)
        .font(.system(size: 11))
        .frame(maxHeight: .infinity)

      // Negative dB values (bottom)
      ForEach([1, 2, 3, 4], id: \.self) { i in
        Text("-\(i * 6)")
          .fontWeight(.thin)
          .lineLimit(1)
          .minimumScaleFactor(0.6)
          .font(.system(size: 11))
          .foregroundColor(.secondary)
          .frame(maxHeight: .infinity)
      }
    }
  }

  func addScaleLines(sliderWidth: CGFloat) -> some View {
    // Match the scale steps for ±24dB range (eqMac official spec)
    VStack {
      // Lines for positive dB section
      ForEach([4, 3, 2, 1], id: \.self) { _ in
        VStack {
          Rectangle()
            .fill(Color.quaternaryLabel.opacity(0.4))
            .frame(height: 1)
            .edgesIgnoringSafeArea(.horizontal)
        }.frame(maxHeight: .infinity)
      }

      // Center line at 0 dB (more prominent)
      VStack {
        Rectangle()
          .fill(Color.secondaryLabel)
          .frame(height: 2)
          .edgesIgnoringSafeArea(.horizontal)
      }.frame(maxHeight: .infinity)

      // Lines for negative dB section
      ForEach([1, 2, 3, 4], id: \.self) { _ in
        VStack {
          Rectangle()
            .fill(Color.quaternaryLabel.opacity(0.4))
            .frame(height: 1)
            .edgesIgnoringSafeArea(.horizontal)
        }.frame(maxHeight: .infinity)
      }
    }.padding(.horizontal)
  }
}
