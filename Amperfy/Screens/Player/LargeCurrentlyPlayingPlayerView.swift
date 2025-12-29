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
      case .generativeArt:
        GenerativeArtView(
          magnitudes: audioAnalyzer.magnitudes,
          rms: audioAnalyzer.rms
        )
      case .ring:
        AmplitudeSpectrumView(
          shapeType: .ring,
          magnitudes: audioAnalyzer.magnitudes,
          range: 0 ..< 75,
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
