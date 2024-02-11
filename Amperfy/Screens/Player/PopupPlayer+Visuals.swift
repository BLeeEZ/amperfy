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
        refreshUserQueueSectionHeader()
        refreshCellMasks()
        refreshVisibleCellsSubtitleColor()
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
    
    func subtitleColor(style: UIUserInterfaceStyle) -> UIColor {
        if let artwork = player.currentlyPlaying?.image(setting: appDelegate.storage.settings.artworkDisplayPreference), artwork != player.currentlyPlaying?.defaultImage {
            let customColor: UIColor!
            if traitCollection.userInterfaceStyle == .dark {
                customColor = artwork.averageColor().getWithLightness(of: 0.8)
            } else {
                customColor = artwork.averageColor().getWithLightness(of: 0.2)
            }
            return customColor
        } else {
            return .labelColor
        }
    }
    
    func refreshOptionButton(button: UIButton) {
        var config = getPlayerRoundButtonConfiguration()
        config.image = .ellipsis
        config.baseForegroundColor = .label
        button.isEnabled = true
        button.configuration = config
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
        refreshLabelColor(label: artistLabel)
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
            artwork = playableInfo.image(setting: appDelegate.storage.settings.artworkDisplayPreference)
        } else {
            switch player.playerMode {
            case .music:
                artwork = .songArtwork
            case .podcast:
                artwork = .podcastArtwork
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
                artworkImage.display(image: .songArtwork)
            case .podcast:
                artworkImage.display(image: .podcastArtwork)
            }
        }
    }
    
    func refreshLabelColor(label: UILabel) {
        label.textColor = subtitleColor(style: traitCollection.userInterfaceStyle)
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
    
    func refreshVisibleCellsSubtitleColor() {
        let subtitleColor = self.subtitleColor(style: traitCollection.userInterfaceStyle)
        tableView.visibleCells.forEach {
            ($0 as? PlayableTableCell)?.updateSubtitleColor(color: subtitleColor)
        }
    }
    
    // handle dark/light mode change
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        refresh()
    }
    
}
