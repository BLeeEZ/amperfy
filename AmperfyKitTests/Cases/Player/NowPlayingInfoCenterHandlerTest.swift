//
//  NowPlayingInfoCenterHandlerTest.swift
//  AmperfyKitTests
//
//  Created by hiei26 on 05.11.26.
//  Copyright (c) 2026 hiei26. All rights reserved.
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

@testable import AmperfyKit
import UIKit
import XCTest

class NowPlayingInfoCenterHandlerTest: XCTestCase {
  private let publishedTiming = NowPlayingTiming(
    elapsedTime: 10,
    duration: 200,
    playbackRate: 1,
    measuredAt: 100
  )

  private func timing(
    elapsedTime: Double,
    duration: Double = 200,
    playbackRate: Double = 1,
    measuredAt: TimeInterval
  )
    -> NowPlayingTiming {
    NowPlayingTiming(
      elapsedTime: elapsedTime,
      duration: duration,
      playbackRate: playbackRate,
      measuredAt: measuredAt
    )
  }

  private func createImage(width: CGFloat, height: CGFloat) -> UIImage {
    let format = UIGraphicsImageRendererFormat()
    format.scale = 1
    let size = CGSize(width: width, height: height)
    return UIGraphicsImageRenderer(size: size, format: format).image { context in
      UIColor.red.setFill()
      context.fill(CGRect(origin: .zero, size: size))
    }
  }

  func testTimingSteadyPlaybackNeedsNoRefresh() {
    XCTAssertFalse(publishedTiming.needsRefresh(comparedTo: timing(
      elapsedTime: 11,
      measuredAt: 101
    )))
    XCTAssertFalse(publishedTiming.needsRefresh(comparedTo: timing(
      elapsedTime: 70,
      measuredAt: 160
    )))
  }

  func testTimingJitterWithinToleranceNeedsNoRefresh() {
    XCTAssertFalse(publishedTiming.needsRefresh(comparedTo: timing(
      elapsedTime: 11.9,
      measuredAt: 101
    )))
  }

  func testTimingStalledPlaybackNeedsRefresh() {
    XCTAssertTrue(publishedTiming.needsRefresh(comparedTo: timing(
      elapsedTime: 10,
      measuredAt: 102
    )))
  }

  func testTimingSeekNeedsRefresh() {
    XCTAssertTrue(publishedTiming.needsRefresh(comparedTo: timing(
      elapsedTime: 90,
      measuredAt: 101
    )))
    XCTAssertTrue(publishedTiming.needsRefresh(comparedTo: timing(elapsedTime: 2, measuredAt: 101)))
  }

  func testTimingDurationChangeNeedsRefresh() {
    XCTAssertTrue(publishedTiming.needsRefresh(comparedTo: timing(
      elapsedTime: 11,
      duration: 0,
      measuredAt: 101
    )))
  }

  func testTimingDurationEstimateJitterNeedsNoRefresh() {
    XCTAssertFalse(publishedTiming.needsRefresh(comparedTo: timing(
      elapsedTime: 11,
      duration: 200.4,
      measuredAt: 101
    )))
  }

  func testTimingNonFiniteDurationNeedsRefresh() {
    XCTAssertTrue(publishedTiming.needsRefresh(comparedTo: timing(
      elapsedTime: 11,
      duration: .nan,
      measuredAt: 101
    )))
  }

  func testTimingPlaybackRateChangeNeedsRefresh() {
    XCTAssertTrue(publishedTiming.needsRefresh(comparedTo: timing(
      elapsedTime: 11,
      playbackRate: 1.5,
      measuredAt: 101
    )))
  }

  func testTimingExtrapolatesWithPlaybackRate() {
    let doubleSpeedTiming = timing(elapsedTime: 10, playbackRate: 2, measuredAt: 100)
    XCTAssertFalse(doubleSpeedTiming.needsRefresh(comparedTo: timing(
      elapsedTime: 30,
      playbackRate: 2,
      measuredAt: 110
    )))
  }

  func testArtworkIsScaledDownToRequestedSize() {
    let image = createImage(width: 1500, height: 1500)
    let artwork = NowPlayingArtwork.image(image, fittingIn: CGSize(width: 300, height: 300))
    XCTAssertEqual(artwork.size.width * artwork.scale, 300, accuracy: 0.5)
    XCTAssertEqual(artwork.size.height * artwork.scale, 300, accuracy: 0.5)
  }

  func testArtworkKeepsAspectRatio() {
    let image = createImage(width: 2000, height: 1000)
    let artwork = NowPlayingArtwork.image(image, fittingIn: CGSize(width: 300, height: 300))
    XCTAssertEqual(artwork.size.width / artwork.size.height, 2, accuracy: 0.02)
    XCTAssertLessThanOrEqual(artwork.size.width * artwork.scale, 300.5)
  }

  func testArtworkIsNeverScaledUp() {
    let image = createImage(width: 200, height: 200)
    let artwork = NowPlayingArtwork.image(image, fittingIn: CGSize(width: 600, height: 600))
    XCTAssertIdentical(artwork, image)
  }

  func testArtworkReturnsInputForEmptyImage() {
    let image = UIImage()
    let artwork = NowPlayingArtwork.image(image, fittingIn: CGSize(width: 300, height: 300))
    XCTAssertIdentical(artwork, image)
  }

  func testArtworkReturnsInputForZeroRequestedSize() {
    let image = createImage(width: 1500, height: 1500)
    let artwork = NowPlayingArtwork.image(image, fittingIn: .zero)
    XCTAssertIdentical(artwork, image)
  }
}
