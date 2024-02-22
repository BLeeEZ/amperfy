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

class SongTableCell: BasicTableCell {
    
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var artistLabel: UILabel!
    @IBOutlet weak var durationLabel: UILabel!
    @IBOutlet weak var entityImage: EntityImageView!
    @IBOutlet weak private var cacheIconImage: UIImageView!
    @IBOutlet weak private var favoriteIconImage: UIImageView!
    @IBOutlet weak private var artistLabelLeadingConstraint: NSLayoutConstraint!
    @IBOutlet weak var artistLabelTrailingConstraint: NSLayoutConstraint!
    @IBOutlet weak var titleLabelTrailingConstraint: NSLayoutConstraint!
    
    static let rowHeight: CGFloat = 48 + margin.bottom + margin.top
    private static let touchAnimation = 0.4
    
    var song: Song?
    var rootView: UITableViewController?
    var playContextCb: GetPlayContextFromTableCellCallback?
    var playIndicator: PlayIndicator!

    override func awakeFromNib() {
        super.awakeFromNib()
        playContextCb = nil
    }
    
    func display(song: Song, playContextCb: @escaping GetPlayContextFromTableCellCallback, rootView: UITableViewController) {
        if playIndicator == nil {
            playIndicator = PlayIndicator(rootViewTypeName: rootView.typeName)
        }
        self.song = song
        self.playContextCb = playContextCb
        self.rootView = rootView
        self.selectionStyle = .none
        refresh()
    }
    
    func refresh() {
        guard let song = song else { return }
        playIndicator.display(playable: song, rootView: self.entityImage, isOnImage: true)
        titleLabel.attributedText = NSMutableAttributedString(string: song.title, attributes: [NSAttributedString.Key.font: UIFont.systemFont(ofSize: 17)])
        artistLabel.text = song.creatorName
        entityImage.display(container: song)
        refreshCacheAndDuration()
    }
    
    func refreshCacheAndDuration() {
        guard let song = song else { return }

        if song.isCached {
            cacheIconImage.isHidden = false
            artistLabelLeadingConstraint.constant = 20
        } else {
            cacheIconImage.isHidden = true
            artistLabelLeadingConstraint.constant = 0
        }
        
        favoriteIconImage.isHidden = !song.isFavorite
        
        let isDurationVisible = appDelegate.storage.settings.isShowSongDuration && (song.duration > 0)
        durationLabel.isHidden = !isDurationVisible
        if isDurationVisible {
            durationLabel.text = song.duration.asColonDurationString
            durationLabel.layoutIfNeeded()
            artistLabelTrailingConstraint.constant = durationLabel.frame.width + 8
            titleLabelTrailingConstraint.constant = durationLabel.frame.width + 8
        } else {
            artistLabelTrailingConstraint.constant = 0
            titleLabelTrailingConstraint.constant = 0
        }
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        playIndicator.reset()
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesEnded(touches, with: event)
        
        self.selectionStyle = .default
        UIView.animate(withDuration: Self.touchAnimation, delay: 0, animations: {
            self.selectionStyle = .none
        }, completion: { _ in
            self.selectionStyle = .none
        })
        
        playThisSong()
    }
    
    private func playThisSong() {
        guard let song = song,
              let context = playContextCb?(self),
              song.isCached || appDelegate.storage.settings.isOnlineMode
        else { return }

        hideSearchBarKeyboardInRootView()
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        appDelegate.player.play(context: context)
    }
    
    private func hideSearchBarKeyboardInRootView() {
        if let basicRootView = rootView as? BasicTableViewController {
            basicRootView.searchController.searchBar.endEditing(true)
        }
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        playIndicator.applyStyle()
    }

}
