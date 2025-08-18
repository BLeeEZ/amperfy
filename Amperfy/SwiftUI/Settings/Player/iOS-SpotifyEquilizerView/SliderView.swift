//
//  SwiftUIView.swift
//
//
//  Created by Urvi Koladiya on 2025-04-14.
//

import AmperfyKit
import SwiftUI

struct SliderView: View {
  @Binding
  var sliderValue: CGFloat
  var sliderFrameHeight: CGFloat
  var sliderTintColor: Color

  var body: some View {
    if ProcessInfo.processInfo.isMacCatalystApp {
      // Slider will result in a crash on macCatalyst -> use Stepper instead
      Stepper(
        "",
        value: $sliderValue,
        in: CGFloat(-EqualizerSetting.rangeFromZero) ... CGFloat(EqualizerSetting.rangeFromZero)
      )
      .frame(width: 0.0)
      .frame(height: sliderFrameHeight)
    } else {
      Slider(
        value: $sliderValue,
        in: CGFloat(-EqualizerSetting.rangeFromZero) ... CGFloat(EqualizerSetting.rangeFromZero),
        step: 1,
        label: {}
      )
      .rotationEffect(.degrees(-90)) // Rotate counter-clockwise
      .tint(.clear)
      .frame(width: sliderFrameHeight) // Vertical height
      .frame(height: sliderFrameHeight)
    }
  }
}
