//
//  LargeCurrentlyPlayingPlayerView.swift
//  Amperfy
//
//  Created by Maximilian Bauer on 07.02.24.
//  Copyright (c) 2024 Maximilian Bauer. All rights reserved.
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

import AmperfyKit
import MarqueeLabel
import MediaPlayer
import UIKit

import SwiftUI

// MARK: - LargeDisplayElement

enum LargeDisplayElement {
  case artwork
  case lyrics
  case visualizer
}

// MARK: - WaveformView

struct WaveformView: View {
  let magnitudes: [Magnitude]
  let rms: Float?

  var body: some View {
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

      let glowStyle = StrokeStyle(lineWidth: lineWidth + 4, lineCap: .round, lineJoin: .round)
      context.stroke(path, with: .color(.primary.opacity(0.3)), style: glowStyle)

      let mainStyle = StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round)
      context.stroke(path, with: .color(.primary), style: mainStyle)
    }
  }
}

// MARK: - SpectrumBarsView

struct SpectrumBarsView: View {
  let magnitudes: [Magnitude]
  let barCount: Int

  private func groupedMagnitudes() -> [Float] {
    guard !magnitudes.isEmpty else {
      return Array(repeating: 0, count: barCount)
    }

    let groupSize = max(1, magnitudes.count / barCount)
    var grouped = [Float]()

    for i in 0..<barCount {
      let startIndex = i * groupSize
      let endIndex = min(startIndex + groupSize, magnitudes.count)
      if startIndex < magnitudes.count {
        let slice = magnitudes[startIndex..<endIndex]
        let avg = slice.reduce(0) { $0 + $1.value } / Float(max(1, slice.count))
        grouped.append(avg)
      } else {
        grouped.append(0)
      }
    }
    return grouped
  }

  private func barColor(for index: Int, total: Int) -> Color {
    let hue = Double(index) / Double(total) * 0.7
    return Color(hue: hue, saturation: 0.8, brightness: 0.9)
  }

  var body: some View {
    Canvas { context, size in
      let bars = groupedMagnitudes()
      let spacing: CGFloat = 2
      let totalSpacing = spacing * CGFloat(bars.count - 1)
      let barWidth = (size.width - totalSpacing) / CGFloat(bars.count)
      let cornerRadius = barWidth * 0.3

      for (index, value) in bars.enumerated() {
        let x = CGFloat(index) * (barWidth + spacing)
        let height = max(4, CGFloat(value) * size.height * 0.9)
        let y = size.height - height

        let rect = CGRect(x: x, y: y, width: barWidth, height: height)
        let path = Path(roundedRect: rect, cornerRadius: cornerRadius)

        let gradient = Gradient(colors: [
          barColor(for: index, total: bars.count),
          barColor(for: index, total: bars.count).opacity(0.6),
        ])
        context.fill(
          path,
          with: .linearGradient(
            gradient,
            startPoint: CGPoint(x: x, y: y),
            endPoint: CGPoint(x: x, y: size.height)
          )
        )
      }
    }
  }
}

// MARK: - RadialVisualizerView

struct RadialVisualizerView: View {
  let magnitudes: [Magnitude]
  let range: Range<Int>
  let rms: Float?

  var body: some View {
    TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { timeline in
      Canvas { context, size in
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let sideLength = min(size.width, size.height)
        let radiusInner = sideLength / 5.0
        let radiusOuter = sideLength / 2.2

        let rotationAngle = timeline.date.timeIntervalSinceReferenceDate * 0.3

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

// MARK: - GenerativeArtView

struct GenerativeArtView: View {
  let magnitudes: [Magnitude]
  let rms: Float?

  private func bassEnergy() -> Float {
    guard magnitudes.count > 10 else { return 0.3 }
    return magnitudes[0..<10].reduce(0) { $0 + $1.value } / 10.0
  }

  private func midEnergy() -> Float {
    guard magnitudes.count > 50 else { return 0.3 }
    return magnitudes[10..<50].reduce(0) { $0 + $1.value } / 40.0
  }

  private func trebleEnergy() -> Float {
    guard magnitudes.count > 50 else { return 0.3 }
    let end = min(magnitudes.count, 100)
    return magnitudes[50..<end].reduce(0) { $0 + $1.value } / Float(end - 50)
  }

  var body: some View {
    TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
      Canvas { context, size in
        let time = timeline.date.timeIntervalSinceReferenceDate
        let center = CGPoint(x: size.width / 2, y: size.height / 2)

        let bass = CGFloat(bassEnergy())
        let mid = CGFloat(midEnergy())
        let treble = CGFloat(trebleEnergy())
        let rmsVal = CGFloat(rms ?? 0.3)

        let layers = 5
        for layer in 0..<layers {
          let layerOffset = Double(layer) * 0.5
          let baseRadius = min(size.width, size.height) * 0.15 * (1 + CGFloat(layer) * 0.3)

          var path = Path()
          let points = 60
          for i in 0...points {
            let angle = Double(i) / Double(points) * 2 * .pi
            let noise1 = sin(angle * 3 + time * 2 + layerOffset) * bass * 30
            let noise2 = cos(angle * 5 + time * 1.5) * mid * 20
            let noise3 = sin(angle * 7 + time * 3) * treble * 15

            let radius = baseRadius + noise1 + noise2 + noise3 + rmsVal * 20
            let x = center.x + radius * cos(angle)
            let y = center.y + radius * sin(angle)

            if i == 0 {
              path.move(to: CGPoint(x: x, y: y))
            } else {
              path.addLine(to: CGPoint(x: x, y: y))
            }
          }
          path.closeSubpath()

          let hue = (time * 0.1 + Double(layer) * 0.15).truncatingRemainder(dividingBy: 1.0)
          let color = Color(hue: hue, saturation: 0.6, brightness: 0.85)
          let opacity = 0.3 - Double(layer) * 0.04

          context.fill(path, with: .color(color.opacity(opacity)))
          context.stroke(
            path,
            with: .color(color.opacity(opacity + 0.2)),
            style: StrokeStyle(lineWidth: 1.5)
          )
        }

        let particleCount = 30
        for i in 0..<particleCount {
          let seed = Double(i) * 1.618
          let angle = seed + time * (0.2 + bass * 0.5)
          let distance =
            40 + sin(seed * 3 + time) * 30 * mid + CGFloat(i) * 3 * (1 + rmsVal)

          let x = center.x + distance * cos(angle)
          let y = center.y + distance * sin(angle)

          let particleSize = 2 + treble * 6
          let particleRect = CGRect(
            x: x - particleSize / 2,
            y: y - particleSize / 2,
            width: particleSize,
            height: particleSize
          )

          let hue = (seed / Double(particleCount) + time * 0.05)
            .truncatingRemainder(dividingBy: 1.0)
          let particleColor = Color(hue: hue, saturation: 0.7, brightness: 0.95)

          context.fill(Circle().path(in: particleRect), with: .color(particleColor))
        }
      }
    }
  }
}

// MARK: - AudioAnalyzerView


struct AudioAnalyzerView: View {
  @EnvironmentObject
  var audioAnalyzer: AudioAnalyzer
  let visualizerType: VisualizerType

  var body: some View {
    Group {
      switch visualizerType {
      case .waveform:
        WaveformView(
          magnitudes: audioAnalyzer.magnitudes,
          rms: audioAnalyzer.rms
        )
      case .spectrumBars:
        SpectrumBarsView(
          magnitudes: audioAnalyzer.magnitudes,
          barCount: 32
        )
      case .radial:
        RadialVisualizerView(
          magnitudes: audioAnalyzer.magnitudes,
          range: 0..<75,
          rms: audioAnalyzer.rms
        )
      case .generativeArt:
        GenerativeArtView(
          magnitudes: audioAnalyzer.magnitudes,
          rms: audioAnalyzer.rms
        )
      case .ring:
        AmplitudeSpectrumView(
          shapeType: .ring,
          magnitudes: audioAnalyzer.magnitudes,
          range: 0..<75,
          rms: audioAnalyzer.rms
        )
      }
    }
    .padding()
  }
}

// MARK: - AudioAnalyzerWrapperView

struct AudioAnalyzerWrapperView: View {
  let visualizerType: VisualizerType

  var body: some View {
    VStack {
      AudioAnalyzerView(visualizerType: visualizerType)
        .environmentObject(appDelegate.player.audioAnalyzer)
    }
  }
}

// MARK: - SwiftUIContentView

class SwiftUIContentView: UIView {
  var hostingController: UIHostingController<AudioAnalyzerWrapperView>?

  public func setupSwiftUIView(
    parentVC: UIViewController,
    parentView: UIView,
    visualizerType: VisualizerType
  ) {
    let swiftUIView = AudioAnalyzerWrapperView(visualizerType: visualizerType)
    let hostingController = UIHostingController(rootView: swiftUIView)
    self.hostingController = hostingController

    parentVC.addChild(hostingController)
    parentView.addSubview(hostingController.view)

    hostingController.view.frame = parentView.frame
    hostingController.view.backgroundColor = .clear

    hostingController.view.translatesAutoresizingMaskIntoConstraints = false
    hostingController.didMove(toParent: parentVC)
  }

  public func updateVisualizerType(_ visualizerType: VisualizerType) {
    hostingController?.rootView = AudioAnalyzerWrapperView(visualizerType: visualizerType)
  }
}

// MARK: - LargeCurrentlyPlayingPlayerView

class LargeCurrentlyPlayingPlayerView: UIView {
  static let rowHeight: CGFloat = 94.0
  static private let margin = UIEdgeInsets(
    top: 0,
    left: UIView.defaultMarginX,
    bottom: 20,
    right: UIView.defaultMarginX
  )

  private var rootView: PopupPlayerVC?
  private var lyricsView: LyricsView?
  private var visualizerHostingView: SwiftUIContentView?
  private var displayElement: LargeDisplayElement = .artwork

  @IBOutlet
  weak var upperContainerView: UIView!
  @IBOutlet
  weak var artworkImage: LibraryEntityImage!
  @IBOutlet
  weak var detailsContainer: UIView!
  @IBOutlet
  weak var titleLabel: MarqueeLabel!
  @IBOutlet
  weak var albumLabel: MarqueeLabel!
  @IBOutlet
  weak var albumButton: UIButton!
  @IBOutlet
  weak var albumContainerView: UIView!
  @IBOutlet
  weak var artistLabel: MarqueeLabel!
  @IBOutlet
  weak var favoriteButton: UIButton!
  @IBOutlet
  weak var optionsButton: UIButton!

  required init?(coder aDecoder: NSCoder) {
    super.init(coder: aDecoder)
    self.layoutMargins = Self.margin
  }

  override func layoutSubviews() {
    super.layoutSubviews()
    // Force a layout to prevent wrong size on first appearance on macOS
    upperContainerView.layoutIfNeeded()

    lyricsView?.frame = upperContainerView.bounds
    visualizerHostingView?.hostingController?.view.frame = upperContainerView.bounds
  }

  func prepare(toWorkOnRootView: PopupPlayerVC?) {
    rootView = toWorkOnRootView
    titleLabel.applyAmperfyStyle()
    albumLabel.applyAmperfyStyle()
    artistLabel.applyAmperfyStyle()

    lyricsView = LyricsView()
    lyricsView!.frame = upperContainerView.bounds
    upperContainerView.addSubview(lyricsView!)

    visualizerHostingView = SwiftUIContentView()
    visualizerHostingView!.hostingController?.view.frame = upperContainerView.bounds
    if let toWorkOnRootView {
      visualizerHostingView!.setupSwiftUIView(
        parentVC: toWorkOnRootView,
        parentView: self,
        visualizerType: appDelegate.storage.settings.user.selectedVisualizerType
      )
    }

    addSwipeGesturesToArtwork()

    displayElement = getDisplayElementBasedOnConfig()
    refresh()
  }

  private func addSwipeGesturesToArtwork() {
    func createLeftSwipe() -> UISwipeGestureRecognizer {
      let swipeLeft = UISwipeGestureRecognizer(
        target: self,
        action: #selector(handleSwipe(_:))
      )
      swipeLeft.direction = .left
      return swipeLeft
    }

    func createRightSwipe() -> UISwipeGestureRecognizer {
      let swipeRight = UISwipeGestureRecognizer(
        target: self,
        action: #selector(handleSwipe(_:))
      )
      swipeRight.direction = .right
      return swipeRight
    }

    artworkImage.isUserInteractionEnabled = true
    artworkImage.addGestureRecognizer(createLeftSwipe())
    artworkImage.addGestureRecognizer(createRightSwipe())
    visualizerHostingView?.hostingController?.view.isUserInteractionEnabled = true
    visualizerHostingView?.hostingController?.view.addGestureRecognizer(createRightSwipe())
    visualizerHostingView?.hostingController?.view.addGestureRecognizer(createLeftSwipe())
  }

  @objc
  private func handleSwipe(_ gesture: UISwipeGestureRecognizer) {
    switch gesture.direction {
    case .left:
      rootView?.controlView?.nextButtonPushed(self)
    case .right:
      rootView?.controlView?.previousButtonPushed(self)
    default:
      break
    }
  }

  func refreshLyricsTime(time: CMTime) {
    lyricsView?.scroll(toTime: time)
  }

  func initializeLyrics() {
    guard isLyricsViewAllowedToDisplay else {
      hideLyrics()
      return
    }

    guard let playable = rootView?.player.currentlyPlaying,
          let song = playable.asSong,
          let account = song.account,
          let lyricsRelFilePath = song.lyricsRelFilePath
    else {
      showLyricsAreNotAvailable()
      return
    }

    Task { @MainActor in do {
      let lyricsList = try await appDelegate.getMeta(account.info).librarySyncer
        .parseLyrics(relFilePath: lyricsRelFilePath)
      guard self.isLyricsViewAllowedToDisplay else {
        self.hideLyrics()
        return
      }

      if song == self.appDelegate.player.currentlyPlaying?.asSong,
         let structuredLyrics = lyricsList.getFirstSyncedLyricsOrUnsyncedAsDefault() {
        self.showLyrics(structuredLyrics: structuredLyrics)
      } else {
        self.showLyricsAreNotAvailable()
      }
    } catch {
      guard self.isLyricsViewAllowedToDisplay else {
        self.hideLyrics()
        return
      }
      self.showLyricsAreNotAvailable()
    }}
  }

  var isLyricsViewAllowedToDisplay: Bool {
    displayElement == .lyrics &&
      appDelegate.player.playerMode == .music &&
      appDelegate.storage.settings.accounts.availableApiTypes.contains(.subsonic)
  }

  var isLyricsButtonAllowedToDisplay: Bool {
    appDelegate.player.playerMode == .music &&
      appDelegate.storage.settings.accounts.availableApiTypes.contains(.subsonic)
  }

  public func getDisplayElementBasedOnConfig() -> LargeDisplayElement {
    if appDelegate.storage.settings.user.isPlayerLyricsDisplayed {
      return .lyrics
    } else if appDelegate.storage.settings.user.isPlayerVisualizerDisplayed {
      return .visualizer
    } else {
      return .artwork
    }
  }

  public func display(element: LargeDisplayElement) {
    displayElement = element

    switch element {
    case .artwork:
      hideVisualizer()
      hideLyrics()
      showArtwork()
    case .lyrics:
      hideVisualizer()
      almostHideArtwork()
      initializeLyrics()
    case .visualizer:
      hideLyrics()
      almostHideArtwork()
      showVisualizer()
    }
  }

  public func almostHideArtwork() {
    artworkImage.alpha = 0.1
  }

  public func showArtwork() {
    artworkImage.alpha = 1
  }

  public func hideVisualizer() {
    visualizerHostingView?.hostingController?.view.isHidden = true
    appDelegate.player.audioAnalyzer.isActive = false
  }

  public func showVisualizer() {
    visualizerHostingView?.updateVisualizerType(
      appDelegate.storage.settings.user.selectedVisualizerType
    )
    visualizerHostingView?.hostingController?.view.isHidden = false
    appDelegate.player.audioAnalyzer
      .isActive = (appDelegate.storage.settings.user.playerDisplayStyle == .large)
  }

  private func hideLyrics() {
    lyricsView?.clear()
    lyricsView?.isHidden = true
  }

  private func showLyricsAreNotAvailable() {
    var notAvailableLyrics = StructuredLyrics()
    notAvailableLyrics.synced = false
    var line = LyricsLine()
    line.value = "No Lyrics"
    notAvailableLyrics.line.append(line)
    showLyrics(structuredLyrics: notAvailableLyrics)
    lyricsView?.highlightAllLyrics()
  }

  private func showLyrics(structuredLyrics: StructuredLyrics) {
    lyricsView?.display(
      lyrics: structuredLyrics,
      scrollAnimation: appDelegate.storage.settings.user.isLyricsSmoothScrolling
    )
    lyricsView?.isHidden = false
  }

  func refresh() {
    rootView?.playerHandler?.refreshCurrentlyPlayingInfo(
      artworkImage: artworkImage,
      titleLabel: titleLabel,
      artistLabel: artistLabel,
      albumLabel: albumLabel,
      albumButton: albumButton,
      albumContainerView: albumContainerView
    )
    rootView?.refreshFavoriteButton(button: favoriteButton)
    rootView?.refreshOptionButton(button: optionsButton, rootView: rootView)
    display(element: displayElement)
  }

  func refreshArtwork() {
    rootView?.playerHandler?.refreshArtwork(artworkImage: artworkImage)
  }

  @IBAction
  func artworkPressed(_ sender: Any) {
    rootView?.controlView?.displayPlaylistPressed()
  }

  @IBAction
  func titlePressed(_ sender: Any) {
    rootView?.displayAlbumDetail()
    rootView?.displayPodcastDetail()
  }

  @IBAction
  func albumPressed(_ sender: Any) {
    rootView?.displayAlbumDetail()
    rootView?.displayPodcastDetail()
  }

  @IBAction
  func artistNamePressed(_ sender: Any) {
    rootView?.displayArtistDetail()
    rootView?.displayPodcastDetail()
  }

  @IBAction
  func favoritePressed(_ sender: Any) {
    rootView?.favoritePressed()
    rootView?.refreshFavoriteButton(button: favoriteButton)
  }
}
