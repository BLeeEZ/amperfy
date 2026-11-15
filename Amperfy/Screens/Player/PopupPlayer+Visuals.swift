//
//  PopupPlayer+Visuals.swift
//  Amperfy
//
//  Created by Maximilian Bauer on 11.02.24.
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
import DominantColors
import UIKit

extension PopupPlayerVC {
  func refresh() {
    refreshContextQueueSectionHeader()
    refreshUserQueueSectionHeader()
    refreshCellMasks()
    refreshCellsContent()
    refreshCurrentlyPlayingInfoView()
  }

  func refreshCurrentlyPlayingInfoView() {
    refreshBackgroundItemArtwork()
    largeCurrentlyPlayingView?.refresh()
    for visibleCell in tableView.visibleCells {
      if let currentlyPlayingCell = visibleCell as? CurrentlyPlayingTableCell {
        currentlyPlayingCell.refresh()
        break
      }
    }
  }

  func refreshCurrentlyPlayingArtworks() {
    refreshBackgroundItemArtwork()
    largeCurrentlyPlayingView?.refreshArtwork()
    for visibleCell in tableView.visibleCells {
      if let currentlyPlayingCell = visibleCell as? CurrentlyPlayingTableCell {
        currentlyPlayingCell.refreshArtwork()
        break
      }
    }
  }

  func refreshOptionButton(button: UIButton, rootView: UIViewController?) {
    var config = UIButton.Configuration.playerRound()
    config.image = .ellipsis
    config.baseForegroundColor = .label
    button.isEnabled = true
    button.configuration = config

    if let currentlyPlaying = appDelegate.player.currentlyPlaying,
       let rootView = rootView {
      button.showsMenuAsPrimaryAction = true
      button.menu = UIMenu.lazyMenu {
        EntityPreviewActionBuilder(container: currentlyPlaying, on: rootView).createMenuActions()
      }
      button.isEnabled = true
    } else {
      button.isEnabled = false
    }
  }

  func refreshFavoriteButton(button: UIButton) {
    var config = UIButton.Configuration.playerRound()
    switch player.playerMode {
    case .music:
      if let playableInfo = player.currentlyPlaying,
         playableInfo.isSong {
        config.image = playableInfo.isFavorite ? .heartFill : .heartEmpty
        config.baseForegroundColor = appDelegate.storage.settings.user
          .isOnlineMode ? .redHeart : .label
        button.isEnabled = appDelegate.storage.settings.user.isOnlineMode
      } else if let playableInfo = player.currentlyPlaying,
                let radio = playableInfo.asRadio {
        config.image = .followLink
        config.baseForegroundColor = .label
        button.isEnabled = radio.siteURL != nil
      } else {
        config.image = .heartEmpty
        config.baseForegroundColor = .redHeart
        button.isEnabled = false
      }
    case .podcast:
      config.image = .info
      config.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(scale: .large)
      config.baseForegroundColor = .label
      button.isEnabled = true
    }
    button.isSymbolAnimationEnabled = true
    button.configuration = config
  }

  func refreshBackgroundItemArtwork() {
    var artwork: UIImage?
    var themePreference: ThemePreference = appDelegate.storage.settings.accounts.activeSetting.read
      .themePreference
    if let playableInfo = player.currentlyPlaying, let accountInfo = playableInfo.account?.info {
      themePreference = appDelegate.storage.settings.accounts.getSetting(accountInfo).read
        .themePreference
      artwork = LibraryEntityImage.getImageToDisplayImmediately(
        libraryEntity: playableInfo,
        themePreference: themePreference,
        artworkDisplayPreference: appDelegate.storage.settings.accounts.getSetting(accountInfo).read
          .artworkDisplayPreference,
        useCache: true
      )
    } else {
      switch player.playerMode {
      case .music:
        artwork = .getGeneratedArtwork(
          theme: themePreference,
          artworkType: .song
        )
      case .podcast:
        artwork = .getGeneratedArtwork(
          theme: themePreference,
          artworkType: .podcastEpisode
        )
      }
    }
    guard let artwork = artwork else { return }
    backgroundImage.image = artwork
    let fallbackColors = [
      themePreference.asColor,
      UIColor.systemBackground,
    ]
    artworkPaletteFallbackColors = fallbackColors
    guard let image = artwork.cgImage else {
      artworkPaletteTask?.cancel()
      artworkPaletteState.invalidate()
      artworkGradientColors = fallbackColors
      applyGradientBackground()
      return
    }

    // Identity refers to the actual immutable pixels, not a song ID or file path:
    // consecutive songs sharing artwork reuse a palette, while a replacement image
    // at the same path (or a placeholder becoming real artwork) gets a new one.
    let identity = ArtworkImageIdentity(image: image)
    switch artworkPaletteState.select(identity) {
    case let .cached(palette):
      artworkPaletteTask?.cancel()
      artworkGradientColors = palette.colors?.map { UIColor(cgColor: $0) } ?? fallbackColors
      applyGradientBackground()
    case .pending:
      artworkGradientColors = fallbackColors
      applyGradientBackground()
    case let .start(generation):
      artworkPaletteTask?.cancel()
      artworkGradientColors = fallbackColors
      applyGradientBackground()
      let worker = artworkPaletteWorker
      artworkPaletteTask = Task { [weak self] in
        let palette = await worker.extract(identity)
        guard !Task.isCancelled, let self,
              artworkPaletteState.complete(identity, generation: generation, value: palette)
        else { return }
        artworkGradientColors = palette.colors?
          .map { UIColor(cgColor: $0) } ?? artworkPaletteFallbackColors
        applyGradientBackground()
      }
    }
  }

  internal func applyGradientBackground() {
    let colors = artworkGradientColors.compactMap { $0.cgColor }
    // remove existing gradient layer
    backgroundImage.layer.sublayers?.forEach { layer in
      if layer is CAGradientLayer {
        layer.removeFromSuperlayer()
      }
    }
    let gradientLayer = CAGradientLayer()
    gradientLayer.frame = backgroundImage.bounds
    gradientLayer.colors = colors
    gradientLayer.startPoint = CGPoint(x: 0.5, y: 0.0)
    gradientLayer.endPoint = CGPoint(x: 0.5, y: 1.0)
    backgroundImage.layer.insertSublayer(gradientLayer, at: 0)
  }

  @objc
  internal func downloadFinishedSuccessful(notification: Notification) {
    guard let downloadNotification = DownloadNotification.fromNotification(notification),
          let curPlayable = player.currentlyPlaying
    else { return }
    if curPlayable.uniqueID == downloadNotification.id ||
      curPlayable.artwork?.uniqueID == downloadNotification.id {
      Task { @MainActor in
        artworkPaletteTask?.cancel()
        artworkPaletteState.invalidate()
        refreshBackgroundItemArtwork()
      }
    }
  }

  func adjustLayoutMargins() {
    view.layoutMargins = UIEdgeInsets(top: 0.0, left: 0.0, bottom: 0.0, right: 0.0)
  }
}

// MARK: - ArtworkImageIdentity

// CGImage and CGColor are immutable Core Graphics objects. These wrappers retain
// them while crossing the actor boundary; no UIImage, UIKit view, settings or
// managed object is read by the worker.
struct ArtworkImageIdentity: Equatable, @unchecked Sendable {
  let image: CGImage

  static func == (lhs: Self, rhs: Self) -> Bool {
    lhs.image === rhs.image
  }
}

// MARK: - ArtworkPalette

struct ArtworkPalette: @unchecked Sendable {
  let colors: [CGColor]?
}

// MARK: - ArtworkPaletteWorker

actor ArtworkPaletteWorker {
  func extract(_ identity: ArtworkImageIdentity) -> ArtworkPalette {
    // The actor serializes extraction. Superseded queued requests are skipped;
    // an extraction already running may finish, but cannot overwrite newer art.
    guard !Task.isCancelled else { return ArtworkPalette(colors: nil) }
    return ArtworkPalette(
      colors: try? DominantColors.dominantColors(image: identity.image, maxCount: 2)
    )
  }
}

// MARK: - ArtworkPaletteCoordinator

/// Retains only the current image and its result. Repeated refreshes share work,
/// including failures; generations reject late results after a track change.
@MainActor
final class ArtworkPaletteCoordinator {
  enum Selection {
    case cached(ArtworkPalette)
    case pending
    case start(UInt64)
  }

  private var currentImage: ArtworkImageIdentity?
  private var result: ArtworkPalette?
  private var pendingGeneration: UInt64?
  private var generation: UInt64 = 0

  func select(_ image: ArtworkImageIdentity) -> Selection {
    if currentImage == image {
      if let result { return .cached(result) }
      if pendingGeneration != nil { return .pending }
    }
    generation &+= 1
    currentImage = image
    result = nil
    pendingGeneration = generation
    return .start(generation)
  }

  @discardableResult
  func complete(_ image: ArtworkImageIdentity, generation: UInt64, value: ArtworkPalette) -> Bool {
    guard currentImage == image, pendingGeneration == generation else { return false }
    pendingGeneration = nil
    result = value
    return true
  }

  func invalidate() {
    currentImage = nil
    result = nil
    pendingGeneration = nil
    generation &+= 1
  }
}
