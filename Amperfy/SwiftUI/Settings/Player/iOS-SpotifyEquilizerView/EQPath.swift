//
//  EqPath.swift
//  Test1
//
//  Created by Urvi Koladiya on 2025-04-18.
//

import AmperfyKit
import SwiftUI

// MARK: - EqualizerPathTopLine

struct EqualizerPathTopLine: Shape {
  var sliderValues: [CGFloat]
  var sliderFrameH: CGFloat
  var sliderSpacing: CGFloat
  var sliderWidth: CGFloat

  func path(in rect: CGRect) -> Path {
    eqTopLine(
      rect: rect,
      sliderValues: sliderValues,
      sliderFrameH: sliderFrameH,
      sliderSpacing: sliderSpacing,
      sliderWidth: sliderWidth
    )
  }
}

// MARK: - EqualizerPath

struct EqualizerPath: Shape {
  var sliderValues: [CGFloat]
  var sliderFrameH: CGFloat
  var sliderSpacing: CGFloat
  var sliderWidth: CGFloat

  func path(in rect: CGRect) -> Path {
    var path = eqTopLine(
      rect: rect,
      sliderValues: sliderValues,
      sliderFrameH: sliderFrameH,
      sliderSpacing: sliderSpacing,
      sliderWidth: sliderWidth
    )
    let totalSpacing = sliderWidth + sliderSpacing
    path.addLine(to: CGPoint(x: totalSpacing * CGFloat(sliderValues.count), y: rect.height))
    path.addLine(to: CGPoint(x: totalSpacing, y: rect.height))
    path.closeSubpath()

    return path
  }
}

extension Shape {
  func eqTopLine(
    rect: CGRect,
    sliderValues: [CGFloat],
    sliderFrameH: CGFloat,
    sliderSpacing: CGFloat,
    sliderWidth: CGFloat
  )
    -> Path {
    var path = Path()
    guard sliderValues.count > 1 else { return path }

    let totalSpacing = sliderWidth + sliderSpacing

    func calcYPos(sliderValue: CGFloat) -> CGFloat {
      (0.05 * rect.height) +
        (
          0.90 *
            (
              rect
                .height -
                (
                  ((0.5 * (sliderValue / CGFloat(EqualizerSetting.rangeFromZero))) + 0.5) *
                    sliderFrameH
                )
            )
        )
    }

    let firstY = calcYPos(sliderValue: sliderValues[0])
    path.move(to: CGPoint(x: totalSpacing, y: firstY))

    for index in 1 ..< sliderValues.count {
      let x = CGFloat(index + 1) * totalSpacing
      let y = calcYPos(sliderValue: sliderValues[index])
      path.addLine(to: CGPoint(x: x, y: y))
    }
    return path
  }
}
