//
//  LyricsVC.swift
//  Amperfy
//
//  Created by David Klopp on 31.08.24.
//  Copyright © 2024 Maximilian Bauer. All rights reserved.
//

import Foundation
import UIKit
import MediaPlayer
import AmperfyKit
import PromiseKit

#if targetEnvironment(macCatalyst)

class LyricsVC: SliderOverItemVC {
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
    func didStartPlaying() {
        self.refreshLyrics()
    }
    
    func didLyricsTimeChange(time: CMTime) {
        self.refreshLyricsTime(time: time)
    }

    func didPause() {}
    func didStopPlaying() {}
    func didElapsedTimeChange() {}
    func didStartPlayingFromBeginning() {}
    func didPlaylistChange() {}
    func didArtworkChange() {}
    func didShuffleChange() {}
    func didRepeatChange() {}
    func didPlaybackRateChange() {}
}
#endif
