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
    Slider(
      value: $sliderValue,
      in: CGFloat(-EqualizerSetting.rangeFromZero) ... CGFloat(EqualizerSetting.rangeFromZero),
      step: 1,
      label: {}
    )
    // .background(Color.red.opacity(0.5))
    .rotationEffect(.degrees(-90)) // Rotate counter-clockwise
    .tint(.clear)
    .frame(width: sliderFrameHeight) // Vertical height
    .frame(height: sliderFrameHeight)
    .frame(maxWidth: (UIScreen.main.bounds.width / 6) - 20)
    .onAppear {
      // let thumbImage = UIImage(systemName: "circle.fill")
      // UISlider.appearance().setThumbImage(thumbImage, for: .normal)
    }
  }
}
