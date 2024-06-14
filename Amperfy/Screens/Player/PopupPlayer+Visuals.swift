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

import UIKit
import AmperfyKit

extension PopupPlayerVC {
    
    func refresh() {
        refreshContextQueueSectionHeader()
        refreshUserQueueSectionHeader()
        refreshCellMasks()
        refreshCurrentlyPlayingInfoView()
    }
    
    func refreshCurrentlyPlayingInfoView() {
        refreshCurrentlyPlayingPopupItem()
        self.largeCurrentlyPlayingView?.refresh()
        for visibleCell in self.tableView.visibleCells {
            if let currentlyPlayingCell = visibleCell as? CurrentlyPlayingTableCell {
                currentlyPlayingCell.refresh()
                break
            }
        }
    }
    
    func refreshCurrentlyPlayingArtworks() {
        refreshBackgroundAndPopupItemArtwork()
        self.largeCurrentlyPlayingView?.refreshArtwork()
        for visibleCell in self.tableView.visibleCells {
            if let currentlyPlayingCell = visibleCell as? CurrentlyPlayingTableCell {
                currentlyPlayingCell.refreshArtwork()
                break
            }
        }
    }
    
    func refreshOptionButton(button: UIButton, rootView: UIViewController?) {
        var config = getPlayerRoundButtonConfiguration()
        config.image = .ellipsis
        config.baseForegroundColor = .label
        button.isEnabled = true
        button.configuration = config
        
        if let currentlyPlaying = appDelegate.player.currentlyPlaying,
           let rootView = rootView {
            button.showsMenuAsPrimaryAction = true
            button.menu = UIMenu.lazyMenu {
                return EntityPreviewActionBuilder(container: currentlyPlaying, on: rootView).createMenu()
            }
            button.isEnabled = true
        } else {
            button.isEnabled = false
        }
    }
    
    func refreshFavoriteButton(button: UIButton) {
        var config = getPlayerRoundButtonConfiguration()
        switch player.playerMode {
        case .music:
            if let playableInfo = player.currentlyPlaying {
                config.image = playableInfo.isFavorite ? .heartFill : .heartEmpty
                config.baseForegroundColor = appDelegate.storage.settings.isOnlineMode ? .redHeart : .label
                button.isEnabled = appDelegate.storage.settings.isOnlineMode
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
        if #available(iOS 17.0, *) {
            button.isSymbolAnimationEnabled = true
        }
        button.configuration = config
    }
    
    func refreshCurrentlyPlayingPopupItem() {
        refreshBackgroundAndPopupItemArtwork()
        if let playableInfo = player.currentlyPlaying {
            popupItem.title = playableInfo.title
            popupItem.subtitle = playableInfo.creatorName
        } else {
            switch player.playerMode {
            case .music:
                popupItem.title = "No music playing"
            case .podcast:
                popupItem.title = "No podcast playing"
            }
            popupItem.subtitle = ""
        }
    }
    
    func refreshCurrentlyPlayingInfo(
        artworkImage: LibraryEntityImage,
        titleLabel: UILabel,
        artistLabel: UILabel,
        albumLabel: UILabel? = nil,
        albumButton: UIButton? = nil,
        albumContainerView: UIView? = nil
    ) {
        refreshArtwork(artworkImage: artworkImage)
        if let playableInfo = player.currentlyPlaying {
            titleLabel.text = playableInfo.title
            albumLabel?.text = playableInfo.asSong?.album?.name ?? ""
            albumButton?.isEnabled = playableInfo.asSong != nil
            albumContainerView?.isHidden = playableInfo.asSong == nil
            artistLabel.text = playableInfo.creatorName
        } else {
            switch player.playerMode {
            case .music:
                titleLabel.text = "No music playing"
            case .podcast:
                titleLabel.text = "No podcast playing"
            }
            albumLabel?.text = ""
            albumButton?.isEnabled = false
            albumContainerView?.isHidden = true
            artistLabel.text = ""
        }
    }
    
    func refreshBackgroundAndPopupItemArtwork() {
        var artwork: UIImage?
        if let playableInfo = player.currentlyPlaying {
            artwork = playableInfo.image(themeColor: appDelegate.storage.settings.themePreference.asColor, setting: appDelegate.storage.settings.artworkDisplayPreference)
        } else {
            switch player.playerMode {
            case .music:
                artwork = .getGeneratedArtwork(themeColor: appDelegate.storage.settings.themePreference.asColor, artworkType: .song)
            case .podcast:
                artwork = .getGeneratedArtwork(themeColor: appDelegate.storage.settings.themePreference.asColor, artworkType: .podcastEpisode)
            }
        }
        guard let artwork = artwork else { return }
        popupItem.image = artwork
        backgroundImage.image = artwork
    }
    
    func refreshArtwork(artworkImage: LibraryEntityImage) {
        if let playableInfo = player.currentlyPlaying {
            artworkImage.display(entity: playableInfo)
        } else {
            switch player.playerMode {
            case .music:
                artworkImage.display(image: .getGeneratedArtwork(themeColor: appDelegate.storage.settings.themePreference.asColor, artworkType: .song))
            case .podcast:
                artworkImage.display(image: .getGeneratedArtwork(themeColor: appDelegate.storage.settings.themePreference.asColor, artworkType: .podcastEpisode))
            }
        }
    }
    
    func getPlayerRoundButtonConfiguration() -> UIButton.Configuration {
        var config = UIButton.Configuration.gray()
        config.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(scale: .medium)
        config.buttonSize = .small
        return config
    }
    
    func getPlayerButtonConfiguration(isSelected: Bool) -> UIButton.Configuration {
        var config = UIButton.Configuration.tinted()
        if isSelected {
            config.background.strokeColor = .label
            config.background.strokeWidth = 1.0
            config.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(scale: .medium)
        }
        config.buttonSize = .small
        config.baseForegroundColor = !isSelected ? .label : .systemBackground
        config.baseBackgroundColor = !isSelected ? .clear : .label
        config.cornerStyle = .medium
        return config
    }
    
    // handle dark/light mode change
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        refresh()
    }
    
    func adjustLaoutMargins() {
        if self.traitCollection.userInterfaceIdiom == .phone {
            self.view.layoutMargins = UIEdgeInsets(top: 0.0, left: 0.0, bottom: 0.0, right: 0.0)
        } else if self.traitCollection.horizontalSizeClass == .compact {
            self.view.layoutMargins = UIEdgeInsets(top: 10.0, left: 0.0, bottom: 0.0, right: 0.0)
        } else {
            self.view.layoutMargins = UIEdgeInsets(top: 10.0, left: 30.0, bottom: 10.0, right: 30.0)
        }
    }
    
}
