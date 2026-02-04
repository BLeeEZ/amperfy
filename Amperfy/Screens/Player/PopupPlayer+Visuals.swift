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
    config.baseForegroundColor = .customDarkLabel
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
          .isOnlineMode ? .redHeart : .customDarkLabel
        button.isEnabled = appDelegate.storage.settings.user.isOnlineMode
      } else if let playableInfo = player.currentlyPlaying,
                let radio = playableInfo.asRadio {
        config.image = .followLink
        config.baseForegroundColor = .customDarkLabel
        button.isEnabled = radio.siteURL != nil
      } else {
        config.image = .heartEmpty
        config.baseForegroundColor = .redHeart
        button.isEnabled = false
      }
    case .podcast:
      config.image = .info
      config.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(scale: .large)
      config.baseForegroundColor = .customDarkLabel
      button.isEnabled = true
    }
    if #available(iOS 17.0, *) {
      button.isSymbolAnimationEnabled = true
    }
    button.configuration = config
  }

  func refreshBackgroundItemArtwork() {
    var themePreference: ThemePreference = appDelegate.storage.settings.accounts.activeSetting.read
      .themePreference
    
    guard let playableInfo = player.currentlyPlaying, 
          let accountInfo = playableInfo.account?.info else {
      // No song playing - show placeholder
      let placeholderArtwork: UIImage
      switch player.playerMode {
      case .music:
        placeholderArtwork = .getGeneratedArtwork(theme: themePreference, artworkType: .song)
      case .podcast:
        placeholderArtwork = .getGeneratedArtwork(theme: themePreference, artworkType: .podcastEpisode)
      }
      backgroundImage.image = placeholderArtwork
      lastGradientSongID = nil
      artworkGradientColors = [themePreference.asColor, UIColor.customDarkBackground]
      applyGradientBackground()
      return
    }
    
    // ONLY calculate gradient ONCE per song
    let currentSongID = playableInfo.uniqueID
    if currentSongID == lastGradientSongID {
      return  // Already calculated gradient for this song, skip
    }
    lastGradientSongID = currentSongID
    
    themePreference = appDelegate.storage.settings.accounts.getSetting(accountInfo).read.themePreference
    let artworkDisplayPreference = appDelegate.storage.settings.accounts.getSetting(accountInfo).read.artworkDisplayPreference
    
    let artwork = LibraryEntityImage.getImageToDisplayImmediately(
      libraryEntity: playableInfo,
      themePreference: themePreference,
      artworkDisplayPreference: artworkDisplayPreference,
      useCache: true
    )
    
    backgroundImage.image = artwork
    artworkGradientColors = (try? artwork.dominantColors(max: 2)) ?? [
      themePreference.asColor,
      UIColor.customDarkBackground,
    ]
    applyGradientBackground()
  }

  internal func applyGradientBackground() {
    // Check if we're in dark mode
    let isDarkMode = traitCollection.userInterfaceStyle == .dark
    
    // Adjust brightness based on mode
    let adjustedColors: [UIColor] = artworkGradientColors.map { color in
      var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
      color.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
      
      if isDarkMode {
        // Reduce brightness significantly for dark mode
        let darkenedBrightness = b * 0.20
        return UIColor(hue: h, saturation: s, brightness: darkenedBrightness, alpha: a)
      } else {
        // Boost brightness for light mode (minimum 85% brightness)
        let brightenedBrightness = max(b, 0.85)
        return UIColor(hue: h, saturation: s * 0.5, brightness: brightenedBrightness, alpha: a)
      }
    }
    
    // Sort colors based on theme:
    // Dark mode: brighter at top, darker at bottom
    // Light mode: darker at top, brighter at bottom
    let sortedColors = adjustedColors.sorted { color1, color2 in
      var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
      var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0
      color1.getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
      color2.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
      let brightness1 = (r1 * 299 + g1 * 587 + b1 * 114) / 1000
      let brightness2 = (r2 * 299 + g2 * 587 + b2 * 114) / 1000
      
      if isDarkMode {
        return brightness1 > brightness2  // Brighter colors first (top), darker last (bottom)
      } else {
        return brightness1 < brightness2  // Darker colors first (top), brighter last (bottom)
      }
    }
    
    let colors = sortedColors.compactMap { $0.cgColor }
    
    // Find the blur effect view (added by setBackgroundBlur) and apply gradient to it
    // This ensures the gradient is visible on top of the blur on iPad
    let targetView: UIView
    if let blurView = backgroundImage.subviews.first(where: { $0 is UIVisualEffectView }) {
      targetView = blurView
    } else {
      targetView = backgroundImage
    }
    
    // Remove existing gradient layer
    targetView.layer.sublayers?.forEach { layer in
      if layer is CAGradientLayer {
        layer.removeFromSuperlayer()
      }
    }
    
    let gradientLayer = CAGradientLayer()
    gradientLayer.frame = targetView.bounds
    gradientLayer.colors = colors
    gradientLayer.startPoint = CGPoint(x: 0.5, y: 0.0)
    gradientLayer.endPoint = CGPoint(x: 0.5, y: 1.0)
    targetView.layer.addSublayer(gradientLayer)
  }

  @objc
  internal func downloadFinishedSuccessful(notification: Notification) {
    guard let downloadNotification = DownloadNotification.fromNotification(notification),
          let curPlayable = player.currentlyPlaying
    else { return }
    if curPlayable.uniqueID == downloadNotification.id {
      Task { @MainActor in
        // Refresh UI to update play type icon (shows green when cached)
        // Don't refresh background artwork here - it was already set when song started
        refresh()
      }
    }
    // Only refresh gradient if artwork itself was downloaded (not the song file)
    if let artwork = curPlayable.artwork,
       artwork.uniqueID == downloadNotification.id {
      Task { @MainActor in
        refreshBackgroundItemArtwork()
      }
    }
  }

  func adjustLayoutMargins() {
    view.layoutMargins = UIEdgeInsets(top: 0.0, left: 0.0, bottom: 0.0, right: 0.0)
  }
}
