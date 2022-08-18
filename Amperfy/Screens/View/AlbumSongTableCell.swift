//
//  AlbumSongTableCell.swift
//  Amperfy
//
//  Created by Maximilian Bauer on 21.01.22.
//  Copyright (c) 2022 Maximilian Bauer. All rights reserved.
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

class AlbumSongTableCell: SongTableCell {
    
    static let albumSongRowHeight: CGFloat = 55
    
    @IBOutlet weak var trackNumberLabel: UILabel!
    @IBOutlet weak var cacheIndicatorImage: UIImageView!
    @IBOutlet weak var artistLabelLeadConstraint: NSLayoutConstraint!
    
    override func refresh() {
        guard let song = song else { return }
        playIndicator.willDisplayIndicatorCB = { [weak self] () in
            guard let self = self else { return }
            self.trackNumberLabel.text = ""
        }
        playIndicator.willHideIndicatorCB = { [weak self] () in
            guard let self = self else { return }
            self.configureTrackNumberLabel()
        }
        playIndicator.display(playable: song, rootView: self.trackNumberLabel)
        titleLabel.attributedText = NSMutableAttributedString(string: song.title, attributes: [NSAttributedString.Key.font: UIFont.systemFont(ofSize: 17)])
        artistLabel.text = song.creatorName

        if song.isCached {
            cacheIndicatorImage.isHidden = false
            artistLabelLeadConstraint.constant = 20
        } else {
            cacheIndicatorImage.isHidden = true
            artistLabelLeadConstraint.constant = 0
        }
    }
    
    private func configureTrackNumberLabel() {
        guard let song = song else { return }
        trackNumberLabel.text = song.track > 0 ? "\(song.track)" : ""
    }
    
}
