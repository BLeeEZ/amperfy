//
//  PlayableTableCell.swift
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

class PlayableTableCell: BasicTableCell {
    
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var artistLabel: UILabel!
    @IBOutlet weak var durationLabel: UILabel!
    @IBOutlet weak var entityImage: EntityImageView!
    @IBOutlet weak var downloadProgress: UIProgressView!
    @IBOutlet weak var reorderImage: UIImageView?
    @IBOutlet weak var cacheIconImage: UIImageView!
    @IBOutlet weak var artistLabelLeadingConstraint: NSLayoutConstraint!
    
    @IBOutlet weak var titleLabelTrailingConstraint: NSLayoutConstraint!
    
    @IBOutlet weak var artistLabelTrailingConstraint: NSLayoutConstraint!
    
    
    static let rowHeight: CGFloat = 48 + margin.bottom + margin.top
    
    private var playerIndexCb: GetPlayerIndexFromTableCellCallback?
    private var playContextCb: GetPlayContextFromTableCellCallback?
    private var playable: AbstractPlayable?
    private var download: Download?
    private var rootView: UIViewController?
    private var isAlertPresented = false
    private var subtitleColor: UIColor?

    override func awakeFromNib() {
        super.awakeFromNib()
        let longPressGesture = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPressGesture))
        self.addGestureRecognizer(longPressGesture)
    }
    
    func display(playable: AbstractPlayable, playContextCb: @escaping GetPlayContextFromTableCellCallback, rootView: UIViewController, playerIndexCb: GetPlayerIndexFromTableCellCallback? = nil, download: Download? = nil, subtitleColor: UIColor? = nil) {
        self.playable = playable
        self.playContextCb = playContextCb
        self.playerIndexCb = playerIndexCb
        self.rootView = rootView
        self.download = download
        self.subtitleColor = subtitleColor
        refresh()
    }
    
    func refresh() {
        guard let playable = playable else { return }
        titleLabel.attributedText = NSMutableAttributedString(string: playable.title, attributes: [NSAttributedString.Key.font: UIFont.systemFont(ofSize: 17)])
        
        artistLabel.text = playable.creatorName
        entityImage.display(container: playable)
        
        if playerIndexCb != nil {
            self.reorderImage?.isHidden = false
            self.reorderImage?.image = .bars
        } else if download?.error != nil {
            self.reorderImage?.isHidden = false
            self.reorderImage?.image = .exclamation
        } else if download?.isFinishedSuccessfully ?? false {
            self.reorderImage?.isHidden = false
            self.reorderImage?.image = .check
        } else {
            self.reorderImage?.isHidden = true
        }
        
        refreshSubtitleColor()
        refreshCacheAndDuration()
        
        if let download = download, download.isDownloading {
            downloadProgress.isHidden = false
            downloadProgress.progress = download.progress
        } else {
            downloadProgress.isHidden = true
        }
    }
    
    func refreshCacheAndDuration() {
        guard let playable = playable else { return }

        if playable.isCached {
            cacheIconImage.isHidden = false
            artistLabelLeadingConstraint.constant = 20
        } else {
            cacheIconImage.isHidden = true
            artistLabelLeadingConstraint.constant = 0
        }
        
        let isDurationVisible = appDelegate.storage.settings.isShowSongDuration && (playable.duration > 0)
        durationLabel.isHidden = !isDurationVisible
        if isDurationVisible {
            durationLabel.text = playable.duration.asColonDurationString
            durationLabel.layoutIfNeeded()
            artistLabelTrailingConstraint.constant = durationLabel.frame.width + 16
            titleLabelTrailingConstraint.constant = durationLabel.frame.width + 16
        } else {
            artistLabelTrailingConstraint.constant = 8
            titleLabelTrailingConstraint.constant = 8
        }
    }
    
    func updateSubtitleColor(color: UIColor?) {
        self.subtitleColor = color
        refreshSubtitleColor()
    }
    
    private func refreshSubtitleColor() {
        if playerIndexCb != nil {
            if let subtitleColor = self.subtitleColor {
                cacheIconImage.tintColor = subtitleColor
                artistLabel.textColor = subtitleColor
                durationLabel.textColor = subtitleColor
            } else {
                cacheIconImage.tintColor = UIColor.labelColor
                artistLabel.textColor = UIColor.labelColor
                durationLabel.textColor = UIColor.labelColor
            }
        } else {
            cacheIconImage.tintColor = UIColor.secondaryLabelColor
            artistLabel.textColor = UIColor.secondaryLabelColor
            durationLabel.textColor = UIColor.secondaryLabelColor
        }
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        if let playerIndex = playerIndexCb?(self), !isAlertPresented {
            appDelegate.player.play(playerIndex: playerIndex)
        }
        isAlertPresented = false
    }
    
    private func hideSearchBarKeyboardInRootView() {
        if let basicRootView = rootView as? BasicTableViewController {
            basicRootView.searchController.searchBar.endEditing(true)
        }
    }
    
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        isAlertPresented = false
    }
    
    @objc func handleLongPressGesture(gesture: UILongPressGestureRecognizer) -> Void {
        if gesture.state == .began {
            displayMenu()
        }
    }
     
    func displayMenu() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
        guard let playable = playable, let rootView = rootView else { return }
        isAlertPresented = true
        let detailVC = LibraryEntityDetailVC()
        let playContextLambda = {() in self.playContextCb?(self)}
        let playerIndexLambda = playerIndexCb != nil ? {() in self.playerIndexCb?(self)} : nil
        detailVC.display(
            container: playable,
            on: rootView,
            playContextCb: playContextLambda,
            playerIndexCb: playerIndexLambda)
        rootView.present(detailVC, animated: true)
    }

}
