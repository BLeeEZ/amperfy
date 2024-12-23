//
//  SongTableCell.swift
//  Amperfy
//
//  Created by Maximilian Bauer on 09.03.19.
//  Copyright (c) 2019 Maximilian Bauer. All rights reserved.
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

typealias GetPlayContextFromTableCellCallback = (UITableViewCell) -> PlayContext?
typealias GetPlayerIndexFromTableCellCallback = (PlayableTableCell) -> PlayerIndex?

enum DisplayMode {
    case normal
    case selection
    case reorder
    case add
}

class PlayableTableCell: BasicTableCell {
    
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var artistLabel: UILabel!
    @IBOutlet weak var durationLabel: UILabel!
    @IBOutlet weak var entityImage: EntityImageView!
    @IBOutlet weak var trackNumberLabel: UILabel!
    @IBOutlet weak var downloadProgress: UIProgressView! // depricated: replaced with a spinner in the accessoryView
    @IBOutlet weak private var cacheIconImage: UIImageView!
    @IBOutlet weak private var favoriteIconImage: UIImageView!
    
    @IBOutlet weak var titleContainerLeadingConstraint: NSLayoutConstraint!
    @IBOutlet weak var labelTrailingCellConstraint: NSLayoutConstraint!
    @IBOutlet weak var cacheTrailingCellConstaint: NSLayoutConstraint!
    @IBOutlet weak var durationTrailingCellConstraint: NSLayoutConstraint!
    @IBOutlet weak var optionsButton: UIButton!
    @IBOutlet weak var deleteButton: UIButton!
    
    static let rowHeight: CGFloat = 48 + margin.bottom + margin.top
    private static let touchAnimation = 0.4
    
    private var playerIndexCb: GetPlayerIndexFromTableCellCallback?
    private var playContextCb: GetPlayContextFromTableCellCallback?
    private var playable: AbstractPlayable?
    private var download: Download?
    private var rootView: UIViewController?
    private var playIndicator: PlayIndicator?
    private var isDislayAlbumTrackNumberStyle: Bool = false
    private var displayMode: DisplayMode = .normal
    private var hoverGestureRecognizer: UIHoverGestureRecognizer!
    
    public var isMarked = false
    private var isDeleteButtonAllowedToBeVisible: Bool {
        return (traitCollection.userInterfaceIdiom == .mac) && (playerIndexCb != nil)
    }

    override func awakeFromNib() {
        super.awakeFromNib()
        playContextCb = nil
#if targetEnvironment(macCatalyst)
        hoverGestureRecognizer = UIHoverGestureRecognizer(target: self, action: #selector(hovering(_:)))
        self.addGestureRecognizer(hoverGestureRecognizer)
#endif
    }
    
    func display(playable: AbstractPlayable, displayMode: DisplayMode = .normal, playContextCb: GetPlayContextFromTableCellCallback?, rootView: UIViewController, playerIndexCb: GetPlayerIndexFromTableCellCallback? = nil, isDislayAlbumTrackNumberStyle: Bool = false, download: Download? = nil, isMarked: Bool = false) {
        if playIndicator == nil {
            playIndicator = PlayIndicator(rootViewTypeName: rootView.typeName)
        }
        
        self.deleteButton.isHidden = true
        self.deleteButton.tintColor = .red
        self.playable = playable
        self.displayMode = displayMode
        self.playContextCb = playContextCb
        self.playerIndexCb = playerIndexCb
        self.rootView = rootView
        self.isDislayAlbumTrackNumberStyle = isDislayAlbumTrackNumberStyle
        self.download = download
        self.selectionStyle = .default
        self.isMarked = isMarked
        refresh()
    }

    func refresh() {
        downloadProgress.isHidden = true
        guard let playable = playable else { return }
        titleLabel.text = playable.title
        artistLabel.text = playable.creatorName
        entityImage.display(theme: appDelegate.storage.settings.themePreference, container: playable)
        
        if self.isDislayAlbumTrackNumberStyle {
            configureTrackNumberLabel()
            playIndicator?.willDisplayIndicatorCB = { [weak self] () in
                guard let self = self else { return }
                self.trackNumberLabel.text = ""
            }
            playIndicator?.willHideIndicatorCB = { [weak self] () in
                guard let self = self else { return }
                self.configureTrackNumberLabel()
            }
            
            playIndicator?.display(playable: playable, rootView: self.trackNumberLabel)
            trackNumberLabel.isHidden = false
            entityImage.isHidden = true
            titleContainerLeadingConstraint.constant = 21 + 16 // track lable width + offset
        } else {
            playIndicator?.willDisplayIndicatorCB = nil
            playIndicator?.willHideIndicatorCB = nil
            if self.playerIndexCb == nil {
                playIndicator?.display(playable: playable, rootView: self.entityImage, isOnImage: true)
            } else {
                // don't show play indicator on PopupPlayer
                playIndicator?.reset()
            }
            trackNumberLabel.isHidden = true
            entityImage.isHidden = false
            titleContainerLeadingConstraint.constant = 48 + 8 // artwork width + offset
        }
        
        if displayMode == .selection {
            let img = UIImageView(image: isMarked ? .checkmark : .circle)
            img.tintColor = isMarked ? appDelegate.storage.settings.themePreference.asColor : .secondaryLabelColor
            accessoryView = img
        } else if displayMode == .add {
            let img = UIImageView(image: isMarked ? .checkmark : .plusCircle)
            img.tintColor = appDelegate.storage.settings.themePreference.asColor
            accessoryView = img
        } else if displayMode == .reorder || playerIndexCb != nil {
            let img = UIImageView(image: .bars)
            img.tintColor = .labelColor
            accessoryView = img
        } else if download?.error != nil {
            let img = UIImageView(image: .exclamation)
            img.tintColor = .labelColor
            accessoryView = img
        } else if download?.isFinishedSuccessfully ?? false {
            let img = UIImageView(image: .check)
            img.tintColor = .labelColor
            accessoryView = img
        } else if download?.isDownloading ?? false {
            let spinner = UIActivityIndicatorView(style: .medium)
            spinner.startAnimating()
            spinner.tintColor = .labelColor
            accessoryView = spinner
        } else {
            accessoryView = nil
        }
        
        refreshSubtitleColor()
        refreshCacheAndDuration()
    }
    
    private func configureTrackNumberLabel() {
        guard let playable = playable else { return }
        trackNumberLabel.text = playable.track > 0 ? "\(playable.track)" : ""
    }
    
    func refreshCacheAndDuration() {
        guard let playable = playable else { return }
        favoriteIconImage.isHidden = !playable.isFavorite
        favoriteIconImage.tintColor = .red
        
        let isDurationVisible = appDelegate.storage.settings.isShowSongDuration || (traitCollection.horizontalSizeClass == .regular)
        let cacheIconWidth = (traitCollection.horizontalSizeClass == .regular) ? 17.0 : 15.0
        let durationWidth = (traitCollection.horizontalSizeClass == .regular &&
                             traitCollection.userInterfaceIdiom != .mac) ? 49.0 : 40.0
        let isDisplayOptionButton = (playContextCb != nil) && (playerIndexCb == nil)
        let durationTrailing = isDisplayOptionButton ? ((traitCollection.horizontalSizeClass == .regular) ? 30 : 30.0) : 0.0
        
        optionsButton.isHidden = !isDisplayOptionButton
        if isDisplayOptionButton {
            optionsButton.showsMenuAsPrimaryAction = true
            optionsButton.imageView?.tintColor = .label
            if let rootView = rootView {
                let playContext = playContextCb != nil ? { self.playContextCb?(self) } : nil
                let playIndex = playerIndexCb != nil ? { self.playerIndexCb?(self) } : nil
                optionsButton.menu = UIMenu.lazyMenu {
                    EntityPreviewActionBuilder(container: playable, on: rootView, playContextCb: playContext, playerIndexCb: playIndex).createMenu()
                }
            }
        }
        
        // macOS & iPadOS regular
        //|title|x|Cache|4|Duration| ... |
        //|title|        80        | 30  |
        // compact
        //|title|4|Cache|4|Duration| ... |
        //|title|4|  15 |4|   40   | 30  |
        //|title|4|  15 |-|   --   | 30  |
        //|title|8|  -- |-|   40   | 30  |
        if traitCollection.horizontalSizeClass == .regular {
            labelTrailingCellConstraint.constant = 80 + durationTrailing
        } else {
            var lableTrailing = durationTrailing
            if playable.isCached, isDurationVisible {
                lableTrailing += 4 + cacheIconWidth + 4 + durationWidth
            } else if playable.isCached {
                lableTrailing += 4 + cacheIconWidth
            } else if isDurationVisible {
                lableTrailing += 8 + durationWidth
            }
            labelTrailingCellConstraint.constant = lableTrailing
        }
        
        durationTrailingCellConstraint.constant = durationTrailing
        cacheIconImage.isHidden = !playable.isCached
        cacheTrailingCellConstaint.constant = durationTrailing + (isDurationVisible ? (4.0 + durationWidth) : 0.0)
        durationLabel.isHidden = !isDurationVisible
        if isDurationVisible {
            durationLabel.text = playable.duration.asColonDurationString
        }
    }
    
    private func refreshSubtitleColor() {
        if playerIndexCb != nil {
            cacheIconImage.tintColor = UIColor.labelColor
            artistLabel.textColor = UIColor.labelColor
            durationLabel.textColor = UIColor.labelColor
        } else {
            cacheIconImage.tintColor = UIColor.secondaryLabelColor
            artistLabel.textColor = UIColor.secondaryLabelColor
            durationLabel.textColor = UIColor.secondaryLabelColor
        }
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        playIndicator?.reset()
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesEnded(touches, with: event)
        if displayMode == .normal {
           playThisSong()
        }
    }
    
    func playThisSong() {
        guard let playable = playable else { return }
        if let playerIndex = playerIndexCb?(self) {
            appDelegate.player.play(playerIndex: playerIndex)
        } else if let context = playContextCb?(self),
            playable.isCached || appDelegate.storage.settings.isOnlineMode {
             animateActivation()
             hideSearchBarKeyboardInRootView()
             Haptics.success.vibrate(isHapticsEnabled: appDelegate.storage.settings.isHapticsEnabled)
             appDelegate.player.play(context: context)
         }
    }
    
    private func hideSearchBarKeyboardInRootView() {
        if let basicRootView = rootView as? BasicTableViewController {
            basicRootView.searchController.searchBar.endEditing(true)
        }
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        playIndicator?.applyStyle()
    }
    
#if targetEnvironment(macCatalyst)
    @IBAction func deleteButtonPressed(_ sender: Any) {
        if let playerIndexCb = playerIndexCb,
           let playerIndex = playerIndexCb(self),
           let queueVC = rootView as? QueueVC,
           let tableView = queueVC.tableView {
            queueVC.tableView(tableView, commit: .delete, forRowAt: playerIndex.asIndexPath)
        }
    }
    
    @objc func hovering(_ recognizer: UIHoverGestureRecognizer) {
        switch recognizer.state {
        case .began:
            self.deleteButton.isHidden = !isDeleteButtonAllowedToBeVisible
        case .ended:
            self.deleteButton.isHidden = true
        default:
            break
        }
    }
#endif

}
