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

// MARK: - MaskedScrollView

/// A UIScrollView subclass that applies a gradient mask at the top and bottom edges,
/// exactly like LyricsView does.
class MaskedScrollView: UIScrollView {
  override func layoutSubviews() {
    super.layoutSubviews()
    layer.mask = createVisibilityMask()
    layer.masksToBounds = true
  }
  
  private func createVisibilityMask() -> CAGradientLayer {
    let mask = CAGradientLayer()
    mask.frame = bounds
    mask.colors = [
      UIColor.white.withAlphaComponent(0).cgColor,
      UIColor.white.cgColor,
      UIColor.white.cgColor,
      UIColor.white.withAlphaComponent(0).cgColor,
    ]
    mask.locations = [0, 0.15, 0.85, 1]
    return mask
  }
}

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
  private var staticLyricsScrollView: MaskedScrollView?  // Scrollable container for static lyrics
  private var staticLyricsLabel: UILabel?  // Simple label for static/unsynced lyrics
  private var currentStaticLyricsText: String?  // Track current lyrics to detect new lyrics
  private var visualizerHostingView: SwiftUIContentView?
  private var displayElement: LargeDisplayElement = .artwork
  private var ratingView: RatingView?
  
  /// Flag to temporarily disable artwork scale animation (e.g., during player priming)
  var isArtworkScaleAnimationEnabled: Bool = true

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
  
  private var infoButton: UIButton!

  required init?(coder aDecoder: NSCoder) {
    super.init(coder: aDecoder)
    self.layoutMargins = Self.margin
  }

  override func layoutSubviews() {
    super.layoutSubviews()
    // Force a layout to prevent wrong size on first appearance on macOS
    upperContainerView.layoutIfNeeded()

    lyricsView?.frame = upperContainerView.bounds
    staticLyricsScrollView?.frame = upperContainerView.bounds
    visualizerHostingView?.hostingController?.view.frame = upperContainerView.bounds
  }

  func prepare(toWorkOnRootView: PopupPlayerVC?) {
    rootView = toWorkOnRootView
    titleLabel.applyAmperfyStyle()
    albumLabel.applyAmperfyStyle()
    artistLabel.applyAmperfyStyle()
    
    // Use theme color for artist name
    let themeColor = appDelegate.storage.settings.accounts.activeSetting.read.themePreference.asColor
    artistLabel.textColor = themeColor

    lyricsView = LyricsView()
    lyricsView!.frame = upperContainerView.bounds
    let lyricsTap = UITapGestureRecognizer(target: self, action: #selector(handleLyricsTap(_:)))
    lyricsView!.addGestureRecognizer(lyricsTap)
    upperContainerView.addSubview(lyricsView!)
    
    // Scrollable view for static/unsynced lyrics - no table view animations
    staticLyricsScrollView = MaskedScrollView()
    staticLyricsScrollView!.frame = upperContainerView.bounds
    staticLyricsScrollView!.isHidden = true
    staticLyricsScrollView!.showsVerticalScrollIndicator = false
    staticLyricsScrollView!.showsHorizontalScrollIndicator = false
    let staticLyricsTap = UITapGestureRecognizer(target: self, action: #selector(handleLyricsTap(_:)))
    staticLyricsScrollView!.addGestureRecognizer(staticLyricsTap)
    upperContainerView.addSubview(staticLyricsScrollView!)
    
    staticLyricsLabel = UILabel()
    staticLyricsLabel!.numberOfLines = 0
    staticLyricsLabel!.textAlignment = .center
    staticLyricsLabel!.textColor = .white
    staticLyricsLabel!.font = UIFont.systemFont(ofSize: 24, weight: .semibold)
    staticLyricsScrollView!.addSubview(staticLyricsLabel!)

    visualizerHostingView = SwiftUIContentView()
    visualizerHostingView!.hostingController?.view.frame = upperContainerView.bounds
    if let toWorkOnRootView {
      visualizerHostingView!.setupSwiftUIView(
        parentVC: toWorkOnRootView,
        parentView: self,
        visualizerType: appDelegate.storage.settings.user.selectedVisualizerType
      )
    }

    setupRatingView()
    // Info button removed - now accessible from player controls bar
    addSwipeGesturesToArtwork()
    
    // Observe network status changes to update rating enabled state
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(handleNetworkStatusChanged),
      name: .networkStatusChanged,
      object: nil
    )

    displayElement = getDisplayElementBasedOnConfig()
    refresh()
  }
  
  @objc
  private func handleNetworkStatusChanged() {
    refreshRating()
  }
  
  private func setupInfoButton() {
    guard let ratingView = ratingView else { return }
    
    infoButton = UIButton(type: .system)
    infoButton.translatesAutoresizingMaskIntoConstraints = false
    
    let config = UIImage.SymbolConfiguration(pointSize: 20, weight: .regular)
    let infoImage = UIImage(systemName: "info.circle", withConfiguration: config)
    infoButton.setImage(infoImage, for: .normal)
    infoButton.tintColor = .white
    
    infoButton.addTarget(self, action: #selector(infoButtonPressed), for: .touchUpInside)
    
    // Add to self, positioned left of rating stars, aligned with title text
    addSubview(infoButton)
    
    NSLayoutConstraint.activate([
      infoButton.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
      infoButton.centerYAnchor.constraint(equalTo: ratingView.centerYAnchor),
      infoButton.widthAnchor.constraint(equalToConstant: 30),
      infoButton.heightAnchor.constraint(equalToConstant: 30),
    ])
  }
  
  @objc
  private func infoButtonPressed() {
    guard let playable = rootView?.player.currentlyPlaying else { return }
    let metadataVC = SongMetadataVC()
    metadataVC.playable = playable
    
    let navController = UINavigationController(rootViewController: metadataVC)
    navController.modalPresentationStyle = .pageSheet
    if let sheet = navController.sheetPresentationController {
      sheet.detents = [.medium(), .large()]
      sheet.prefersGrabberVisible = true
    }
    rootView?.present(navController, animated: true)
  }

  private func setupRatingView() {
    ratingView = RatingView()
    ratingView!.translatesAutoresizingMaskIntoConstraints = false
    ratingView!.delegate = self
    ratingView!.isUserInteractionEnabled = true
    // Add directly to self and position between artwork and details
    addSubview(ratingView!)

    // Center vertically between artwork bottom and details top using a UILayoutGuide
    let spacerGuide = UILayoutGuide()
    addLayoutGuide(spacerGuide)

    NSLayoutConstraint.activate([
      // Spacer fills the gap between artwork and details
      spacerGuide.topAnchor.constraint(equalTo: artworkImage.bottomAnchor),
      spacerGuide.bottomAnchor.constraint(equalTo: detailsContainer.topAnchor),
      // Center rating view in the spacer
      ratingView!.centerXAnchor.constraint(equalTo: centerXAnchor),
      ratingView!.centerYAnchor.constraint(equalTo: spacerGuide.centerYAnchor),
      ratingView!.heightAnchor.constraint(equalToConstant: 36),
      // Width needs to accommodate 5 stars + spacing + heart
      ratingView!.widthAnchor.constraint(equalToConstant: 250),
    ])
  }

  @objc
  private func handleLyricsTap(_ gesture: UITapGestureRecognizer) {
    // Hide lyrics when tapped
    if displayElement == .lyrics {
      appDelegate.storage.settings.user.isPlayerLyricsDisplayed = false
      display(element: .artwork)
      refreshRating()
    }
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

    func createTap() -> UITapGestureRecognizer {
      UITapGestureRecognizer(target: self, action: #selector(handleArtworkTap(_:)))
    }

    artworkImage.isUserInteractionEnabled = true
    artworkImage.addGestureRecognizer(createLeftSwipe())
    artworkImage.addGestureRecognizer(createRightSwipe())
    artworkImage.addGestureRecognizer(createTap())
    visualizerHostingView?.hostingController?.view.isUserInteractionEnabled = true
    visualizerHostingView?.hostingController?.view.addGestureRecognizer(createRightSwipe())
    visualizerHostingView?.hostingController?.view.addGestureRecognizer(createLeftSwipe())
  }

  @objc
  private func handleArtworkTap(_ gesture: UITapGestureRecognizer) {
    // Toggle lyrics when artwork is tapped
    if isLyricsButtonAllowedToDisplay && displayElement != .lyrics {
      appDelegate.storage.settings.user.isPlayerLyricsDisplayed = true
      appDelegate.storage.settings.user.isPlayerVisualizerDisplayed = false
      display(element: .lyrics)
      ratingView?.isHidden = true
      infoButton?.isHidden = true
    }
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
  
  func onPlayerPause() {
    lyricsView?.onPause()
    if isArtworkScaleAnimationEnabled {
      updateArtworkScaleForCurrentState(animated: true)
    }
  }
  
  func onPlayerPlay() {
    if isArtworkScaleAnimationEnabled {
      updateArtworkScaleForCurrentState(animated: true)
    }
  }
  
  func setInitialArtworkScale() {
    updateArtworkScaleForCurrentState(animated: false)
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
    // Fade out both lyrics views
    UIView.animate(withDuration: 0.3) {
      self.lyricsView?.alpha = 0
      self.staticLyricsScrollView?.alpha = 0
    } completion: { _ in
      self.lyricsView?.clear()
      self.lyricsView?.isHidden = true
      self.staticLyricsScrollView?.isHidden = true
    }
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
    // For unsynced/static lyrics, use simple scrollable label
    if !structuredLyrics.synced {
      // Hide the table-based lyrics view
      lyricsView?.isHidden = true
      
      // Combine all lyrics lines into one text, with padding at the top
      let lyricsText = "\n\n\n\n\n" + structuredLyrics.line.map { $0.value }.joined(separator: "\n\n")
      
      // Check if these are NEW lyrics (different from current)
      let isNewLyrics = (lyricsText != currentStaticLyricsText)
      currentStaticLyricsText = lyricsText
      
      staticLyricsLabel?.text = lyricsText
      
      // Size the label to fit the text
      let maxWidth = upperContainerView.bounds.width - 40  // 20px padding on each side
      let labelSize = staticLyricsLabel?.sizeThatFits(CGSize(width: maxWidth, height: .greatestFiniteMagnitude)) ?? .zero
      staticLyricsLabel?.frame = CGRect(x: 20, y: 20, width: maxWidth, height: labelSize.height)
      
      // Set scroll view content size
      staticLyricsScrollView?.contentSize = CGSize(width: upperContainerView.bounds.width, height: labelSize.height + 40)
      
      // Only scroll to beginning for NEW lyrics, not when re-displaying same lyrics
      if isNewLyrics {
        staticLyricsScrollView?.contentOffset = .zero
      }
      
      // Only fade in if not already visible
      if staticLyricsScrollView?.isHidden == true || staticLyricsScrollView?.alpha == 0 {
        staticLyricsScrollView?.alpha = 0
        staticLyricsScrollView?.isHidden = false
        UIView.animate(withDuration: 0.3) {
          self.staticLyricsScrollView?.alpha = 1
        }
      }
    } else {
      // Hide static scroll view
      staticLyricsScrollView?.isHidden = true
      
      // For synced lyrics, use normal display
      lyricsView?.display(
        lyrics: structuredLyrics,
        scrollAnimation: appDelegate.storage.settings.user.isLyricsSmoothScrolling
      )
      
      // Only fade in if not already visible
      if lyricsView?.isHidden == true || lyricsView?.alpha == 0 {
        lyricsView?.alpha = 0
        lyricsView?.isHidden = false
        UIView.animate(withDuration: 0.3) {
          self.lyricsView?.alpha = 1
        }
      } else {
        lyricsView?.isHidden = false
      }
    }
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
    // Hide the old favorite button - favorite is now part of the rating view
    favoriteButton.isHidden = true
    // Hide the options button - its menu items are now in the player controls options menu
    optionsButton.isHidden = true
    refreshRating()
    display(element: displayElement)
  }
  
  private func updateArtworkScaleForCurrentState(animated: Bool) {
    let isPlaying = appDelegate.player.isPlaying
    
    // Fixed 10% zoom when playing
    let playingScale: CGFloat = 1.1
    let targetScale = isPlaying ? playingScale : 1.0
    
    let currentHeight = artworkImage.bounds.height
    guard currentHeight > 0 else { return }
    
    // To keep the bottom edge fixed while scaling from center anchor:
    // When scaling up, the image grows in all directions from center
    // We need to translate up by half the height difference to keep bottom edge fixed
    let heightDifference = currentHeight * (targetScale - 1.0)
    let yTranslation = -heightDifference / 2.0
    
    let targetTransform = CGAffineTransform(scaleX: targetScale, y: targetScale)
      .translatedBy(x: 0, y: yTranslation / targetScale)
    
    if animated {
      UIView.animate(withDuration: 0.4, delay: 0, options: [.curveEaseInOut]) {
        self.artworkImage.transform = targetTransform
      }
    } else {
      artworkImage.transform = targetTransform
    }
  }

  func refreshRating() {
    guard appDelegate.storage.settings.user.isShowRating else {
      ratingView?.setRating(0, animated: false)
      ratingView?.setFavorite(false, animated: false)
      ratingView?.isHidden = true
      return
    }
    
    let playable = rootView?.player.currentlyPlaying
    let song = playable?.asSong
    
    // Keep rating and info button hidden when lyrics are displayed
    ratingView?.isHidden = (displayElement == .lyrics)
    infoButton?.isHidden = (displayElement == .lyrics)
    
    // Set rating (only for songs)
    if let song = song {
      ratingView?.setRating(song.rating, animated: false)
      ratingView?.setFavorite(song.isFavorite, animated: false)
      ratingView?.setHeartVisible(true)
    } else {
      ratingView?.setRating(0, animated: false)
      ratingView?.setFavorite(false, animated: false)
      // Hide heart for non-songs (radios, podcasts, etc.)
      ratingView?.setHeartVisible(playable?.isSong == true)
    }
    
    // Disable rating interaction when offline (display only with reduced opacity)
    ratingView?.isRatingEnabled = appDelegate.networkMonitor.isConnectedToNetwork
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

// MARK: - RatingViewDelegate

extension LargeCurrentlyPlayingPlayerView: RatingViewDelegate {
  func ratingView(_ ratingView: RatingView, didChangeRating rating: Int) {
    guard let song = rootView?.player.currentlyPlaying?.asSong,
          let account = song.account
    else { return }

    // Update local rating immediately for responsive UI
    song.rating = rating

    // Sync rating to server
    Task {
      do {
        try await appDelegate.getMeta(account.info).librarySyncer.setRating(song: song, rating: rating)
      } catch {
        appDelegate.eventLogger.report(topic: "Song Rating", error: error)
      }
    }
  }
  
  func ratingView(_ ratingView: RatingView, didToggleFavorite isFavorite: Bool) {
    guard let playable = rootView?.player.currentlyPlaying,
          playable.isSong,
          let account = playable.account
    else { return }
    
    // Toggle favorite on server
    Task { @MainActor in
      do {
        try await playable.remoteToggleFavorite(
          syncer: appDelegate.getMeta(account.info).librarySyncer
        )
        // Refresh to update the heart state
        rootView?.refresh()
      } catch {
        appDelegate.eventLogger.report(topic: "Toggle Favorite", error: error)
        // Revert the UI state on error
        ratingView.setFavorite(!isFavorite, animated: true)
      }
    }
  }
}
