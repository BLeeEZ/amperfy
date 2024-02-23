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

import UIKit
import MediaPlayer
import MarqueeLabel
import AmperfyKit
import PromiseKit

class LargeCurrentlyPlayingPlayerView: UIView {
    
    static let rowHeight: CGFloat = 94.0
    static private let margin = UIEdgeInsets(top: 0, left: UIView.defaultMarginX, bottom: 20, right: UIView.defaultMarginX)
    
    private var rootView: PopupPlayerVC?
    
    @IBOutlet weak var artworkImage: LibraryEntityImage!
    @IBOutlet weak var detailsContainer: UIView!
    @IBOutlet weak var titleLabel: MarqueeLabel!
    @IBOutlet weak var albumLabel: MarqueeLabel!
    @IBOutlet weak var albumButton: UIButton!
    @IBOutlet weak var albumContainerView: UIView!
    @IBOutlet weak var artistLabel: MarqueeLabel!
    @IBOutlet weak var favoriteButton: UIButton!
    @IBOutlet weak var optionsButton: UIButton!
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        self.layoutMargins = Self.margin
    }
    
    func prepare(toWorkOnRootView: PopupPlayerVC? ) {
        self.rootView = toWorkOnRootView
        titleLabel.applyAmperfyStyle()
        albumLabel.applyAmperfyStyle()
        artistLabel.applyAmperfyStyle()
        refresh()
    }
    
    func refresh() {
        rootView?.refreshCurrentlyPlayingInfo(
            artworkImage: artworkImage,
            titleLabel: titleLabel,
            artistLabel: artistLabel,
            albumLabel: albumLabel,
            albumButton: albumButton,
            albumContainerView: albumContainerView)
        rootView?.refreshFavoriteButton(button: favoriteButton)
        rootView?.refreshOptionButton(button: optionsButton, rootView: rootView)
    }
    
    func refreshArtwork() {
        rootView?.refreshArtwork(artworkImage: artworkImage)
    }

    @IBAction func titlePressed(_ sender: Any) {
        rootView?.displayAlbumDetail()
        rootView?.displayPodcastDetail()
    }
    @IBAction func albumPressed(_ sender: Any) {
        rootView?.displayAlbumDetail()
        rootView?.displayPodcastDetail()
    }
    @IBAction func artistNamePressed(_ sender: Any) {
        rootView?.displayArtistDetail()
        rootView?.displayPodcastDetail()
    }

    @IBAction func favoritePressed(_ sender: Any) {
        rootView?.favoritePressed()
        rootView?.refreshFavoriteButton(button: favoriteButton)
    }
    
}
