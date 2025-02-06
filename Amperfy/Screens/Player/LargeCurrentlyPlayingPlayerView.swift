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
    private var lyricsView: LyricsView?
    
    @IBOutlet weak var upperContainerView: UIView!
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
    
    override func layoutSubviews() {
        super.layoutSubviews()
        // Force a layout to prevent wrong size on first appearance on macOS
        self.upperContainerView.layoutIfNeeded()

        lyricsView?.frame = upperContainerView.bounds
    }
    
    func prepare(toWorkOnRootView: PopupPlayerVC? ) {
        self.rootView = toWorkOnRootView
        titleLabel.applyAmperfyStyle()
        albumLabel.applyAmperfyStyle()
        artistLabel.applyAmperfyStyle()
        lyricsView = LyricsView()
        lyricsView!.frame = upperContainerView.bounds

        upperContainerView.addSubview(lyricsView!)

        refresh()
        initializeLyrics()
    }
    
    func refreshLyricsTime(time: CMTime) {
        self.lyricsView?.scroll(toTime: time)
    }
    
    func initializeLyrics() {
        guard isLyricsViewAllowedToDisplay else {
            hideLyrics()
            return
        }
        
        guard let playable = rootView?.player.currentlyPlaying,
              let song = playable.asSong,
              let lyricsRelFilePath = song.lyricsRelFilePath
        else {
            showLyricsAreNotAvailable()
            return
        }
        
        Task { @MainActor in do {
            let lyricsList = try await appDelegate.librarySyncer.parseLyrics(relFilePath: lyricsRelFilePath)
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
        return appDelegate.storage.settings.isPlayerLyricsDisplayed &&
            appDelegate.player.playerMode == .music &&
            appDelegate.backendApi.selectedApi != .ampache
    }
    
    var isLyricsButtonAllowedToDisplay: Bool {
        return  !appDelegate.storage.settings.isAlwaysHidePlayerLyricsButton &&
            appDelegate.player.playerMode == .music &&
            appDelegate.backendApi.selectedApi != .ampache
    }
    
    private func hideLyrics() {
        self.lyricsView?.clear()
        self.lyricsView?.isHidden = true
        self.artworkImage.alpha = 1
    }
    
    private func showLyricsAreNotAvailable() {
        var notAvailableLyrics = StructuredLyrics()
        notAvailableLyrics.synced = false
        var line = LyricsLine()
        line.value = "No Lyrics"
        notAvailableLyrics.line.append(line)
        showLyrics(structuredLyrics: notAvailableLyrics)
        self.lyricsView?.highlightAllLyrics()
    }
    
    private func showLyrics(structuredLyrics: StructuredLyrics) {
        self.lyricsView?.display(lyrics: structuredLyrics, scrollAnimation: appDelegate.storage.settings.isLyricsSmoothScrolling)
        self.lyricsView?.isHidden = false
        self.artworkImage.alpha = 0.1
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
        initializeLyrics()
    }
    
    func refreshArtwork() {
        rootView?.refreshArtwork(artworkImage: artworkImage)
    }

    @IBAction func artworkPressed(_ sender: Any) {
        rootView?.controlView?.displayPlaylistPressed()
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
