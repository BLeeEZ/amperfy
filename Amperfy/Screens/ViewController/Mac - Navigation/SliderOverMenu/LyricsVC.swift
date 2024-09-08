//
//  LyricsVC.swift
//  Amperfy
//
//  Created by David Klopp on 31.08.24.
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

import Foundation
import UIKit
import MediaPlayer
import AmperfyKit
import PromiseKit

#if targetEnvironment(macCatalyst)

class LyricsVC: SlideOverItemVC {
    override var title: String? {
        get { return "Lyrics" }
        set {}
    }

    var player: PlayerFacade {
        return self.appDelegate.player
    }

    var lyricsView: LyricsView?

    override func viewDidLoad() {
        super.viewDidLoad()
        
        let lyricsView = LyricsView()
        lyricsView.translatesAutoresizingMaskIntoConstraints = false

        self.view.addSubview(lyricsView)

        NSLayoutConstraint.activate([
            lyricsView.topAnchor.constraint(equalTo: self.view.topAnchor),
            lyricsView.bottomAnchor.constraint(equalTo: self.view.bottomAnchor),
            lyricsView.leadingAnchor.constraint(equalTo: self.view.leadingAnchor),
            lyricsView.trailingAnchor.constraint(equalTo: self.view.trailingAnchor)
        ])

        self.lyricsView = lyricsView

        self.player.addNotifier(notifier: self)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.refreshLyrics()
    }

    private func fetchSongInfoAndUpdateLyrics() {
        guard self.appDelegate.storage.settings.isOnlineMode,
              let song = player.currentlyPlaying?.asSong
        else { return }

        firstly {
            self.appDelegate.librarySyncer.sync(song: song)
        }.done {
            self.refreshLyrics()
        }.catch { error in
            self.appDelegate.eventLogger.report(topic: "Song Info", error: error)
        }
    }

    private func showLyrics(structuredLyrics: StructuredLyrics) {
        self.lyricsView?.display(lyrics: structuredLyrics, scrollAnimation: appDelegate.storage.settings.isLyricsSmoothScrolling)
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

    func refreshLyrics() {
        guard let playable = player.currentlyPlaying,
              let song = playable.asSong,
              let lyricsRelFilePath = song.lyricsRelFilePath else {
            self.showLyricsAreNotAvailable()
            return
        }

        firstly {
            appDelegate.librarySyncer.parseLyrics(relFilePath: lyricsRelFilePath)
        }.done { lyricsList in
            if song == self.player.currentlyPlaying?.asSong,
               let structuredLyrics = lyricsList.getFirstSyncedLyricsOrUnsyncedAsDefault() {
                self.showLyrics(structuredLyrics: structuredLyrics)
            } else {
                self.showLyricsAreNotAvailable()
            }
        }.catch { error in
            self.showLyricsAreNotAvailable()
        }
    }

    func refreshLyricsTime(time: CMTime) {
        self.lyricsView?.scroll(toTime: time)
    }
}


extension LyricsVC: MusicPlayable {
    func didStartPlayingFromBeginning() {
        self.fetchSongInfoAndUpdateLyrics()
    }

    func didStartPlaying() {
        self.refreshLyrics()
    }
    
    func didLyricsTimeChange(time: CMTime) {
        self.refreshLyricsTime(time: time)
    }

    func didPause() {}
    func didStopPlaying() {}
    func didElapsedTimeChange() {}
    func didPlaylistChange() {}
    func didArtworkChange() {}
    func didShuffleChange() {}
    func didRepeatChange() {}
    func didPlaybackRateChange() {}
}
#endif
