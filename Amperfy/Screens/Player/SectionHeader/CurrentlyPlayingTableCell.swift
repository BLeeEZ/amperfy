//
//  CurrentlyPlayingTableCell.swift
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
import AmperfyKit
import PromiseKit
import MarqueeLabel

class CurrentlyPlayingTableCell: BasicTableCell {
    
    static let rowHeight: CGFloat = 94.0
    
    private var player: PlayerFacade!
    private var rootView: PopupPlayerVC?
    
    var lastDisplayedPlayable: AbstractPlayable?
    
    @IBOutlet weak var artworkImage: LibraryEntityImage!
    @IBOutlet weak var titleLabel: MarqueeLabel!
    @IBOutlet weak var artistLabel: MarqueeLabel!
    @IBOutlet weak var favoriteButton: UIButton!
    @IBOutlet weak var optionsButton: UIButton!
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        player = appDelegate.player
        player.addNotifier(notifier: self)
    }
    
    func prepare(toWorkOnRootView: PopupPlayerVC? ) {
        self.rootView = toWorkOnRootView
        titleLabel.applyAmperfyStyle()
        artistLabel.applyAmperfyStyle()
        refresh()
    }
    
    func refresh() {
        fetchSongInfoAndUpdateViews()
        refreshCurrentlyPlayingInfo()
        refreshFavoriteButton()
    }
    
    func fetchSongInfoAndUpdateViews() {
        guard self.appDelegate.storage.settings.isOnlineMode,
              let song = player.currentlyPlaying?.asSong
        else { return }

        firstly {
            self.appDelegate.librarySyncer.sync(song: song)
        }.done {
            self.refresh()
        }.catch { error in
            self.appDelegate.eventLogger.report(topic: "Song Info", error: error)
        }
    }
    
    func refreshCurrentlyPlayingInfo() {
        refreshArtwork()
        refreshLabelColor()
        if let playableInfo = player.currentlyPlaying {
            titleLabel.text = playableInfo.title
            artistLabel.text = playableInfo.creatorName
            rootView?.popupItem.title = playableInfo.title
            rootView?.popupItem.subtitle = playableInfo.creatorName
            rootView?.changeBackgroundGradient(forPlayable: playableInfo)
            lastDisplayedPlayable = playableInfo
        } else {
            switch player.playerMode {
            case .music:
                titleLabel.text = "No music playing"
                rootView?.popupItem.title = "No music playing"
            case .podcast:
                titleLabel.text = "No podcast playing"
                rootView?.popupItem.title = "No podcast playing"
            }
            artistLabel.text = ""
            rootView?.popupItem.subtitle = ""
            lastDisplayedPlayable = nil
        }
    }
    
    func refreshFavoriteButton() {
        switch player.playerMode {
        case .music:
            if let playableInfo = player.currentlyPlaying {
                favoriteButton.setImage(playableInfo.isFavorite ? .heartFill : .heartEmpty, for: .normal)
                favoriteButton.isEnabled = appDelegate.storage.settings.isOnlineMode
                favoriteButton.tintColor = appDelegate.storage.settings.isOnlineMode ? .red : .label
            } else {
                favoriteButton.setImage(.heartEmpty, for: .normal)
                favoriteButton.isEnabled = false
                favoriteButton.tintColor = .red
            }
            
        case .podcast:
            favoriteButton.setImage(.info, for: .normal)
            favoriteButton.isEnabled = true
            favoriteButton.tintColor = .label
        }
    }
    
    func refreshArtwork() {
        if let playableInfo = player.currentlyPlaying {
            artworkImage.display(entity: playableInfo)
            rootView?.popupItem.image = playableInfo.image(setting: appDelegate.storage.settings.artworkDisplayPreference)
        } else {
            switch player.playerMode {
            case .music:
                artworkImage.display(image: UIImage.songArtwork)
                rootView?.popupItem.image = UIImage.songArtwork
            case .podcast:
                artworkImage.display(image: UIImage.podcastArtwork)
                rootView?.popupItem.image = UIImage.podcastArtwork
            }
        }
    }
    
    func refreshLabelColor() {
        artistLabel.textColor = rootView?.subtitleColor(style: traitCollection.userInterfaceStyle)
    }

    @IBAction func titlePressed(_ sender: Any) {
        displayAlbumDetail()
        displayPodcastDetail()
    }
    @IBAction func albumPressed(_ sender: Any) {
        displayAlbumDetail()
        displayPodcastDetail()
    }
    @IBAction func artistNamePressed(_ sender: Any) {
        displayArtistDetail()
        displayPodcastDetail()
    }

    @IBAction func favoritePressed(_ sender: Any) {
        switch player.playerMode {
        case .music:
            guard let playableInfo = player.currentlyPlaying else { return }
            firstly {
                playableInfo.remoteToggleFavorite(syncer: self.appDelegate.librarySyncer)
            }.catch { error in
                self.appDelegate.eventLogger.report(topic: "Toggle Favorite", error: error)
            }.finally {
                self.refresh()
            }
        case .podcast:
            guard let rootView = rootView,
                  let podcastEpisode = player.currentlyPlaying?.asPodcastEpisode
            else { return }
            let descriptionVC = PodcastDescriptionVC()
            descriptionVC.display(podcastEpisode: podcastEpisode, on: rootView)
            rootView.present(descriptionVC, animated: true)
        }
        
    }
    
    @IBAction func optionsPressed(_ sender: Any) {
        rootView?.displayCurrentlyPlayingDetailInfo()
    }
    
    
    private func displayArtistDetail() {
        if let song = lastDisplayedPlayable?.asSong, let artist = song.artist {
            let artistDetailVC = ArtistDetailVC.instantiateFromAppStoryboard()
            artistDetailVC.artist = artist
            rootView?.closePopupPlayerAndDisplayInLibraryTab(vc: artistDetailVC)
        }
    }
    
    private func displayAlbumDetail() {
        if let song = lastDisplayedPlayable?.asSong, let album = song.album {
            let albumDetailVC = AlbumDetailVC.instantiateFromAppStoryboard()
            albumDetailVC.album = album
            albumDetailVC.songToScrollTo = song
            rootView?.closePopupPlayerAndDisplayInLibraryTab(vc: albumDetailVC)
        }
    }
    
    private func displayPodcastDetail() {
        if let podcastEpisode = lastDisplayedPlayable?.asPodcastEpisode, let podcast = podcastEpisode.podcast {
            let podcastDetailVC = PodcastDetailVC.instantiateFromAppStoryboard()
            podcastDetailVC.podcast = podcast
            podcastDetailVC.episodeToScrollTo = podcastEpisode
            rootView?.closePopupPlayerAndDisplayInLibraryTab(vc: podcastDetailVC)
        }
    }
    
}

extension CurrentlyPlayingTableCell: MusicPlayable {
    func didStartPlaying() {
        self.refresh()
    }
    
    func didStopPlaying() {
        self.refresh()
    }
    
    func didPlaylistChange() {}
    func didPause() {}
    func didElapsedTimeChange() {}
    func didArtworkChange() {}
    func didShuffleChange() {}
    func didRepeatChange() {}
    func didPlaybackRateChange() {}
}
