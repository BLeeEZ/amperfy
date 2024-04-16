//
//  SongPlayedSyncer.swift
//  AmperfyKit
//
//  Created by Maximilian Bauer on 27.11.21.
//  Copyright (c) 2021 Maximilian Bauer. All rights reserved.
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

class SongPlayedSyncer  {
    
    private static let maximumWaitDurationInSec = 20
    
    private let musicPlayer: AudioPlayer
    private let backendAudioPlayer: BackendAudioPlayer
    private let storage: PersistentStorage
    private let scrobbleSyncer: ScrobbleSyncer
    private var scrobbleTimer: Timer?

    init(musicPlayer: AudioPlayer, backendAudioPlayer: BackendAudioPlayer, storage: PersistentStorage, scrobbleSyncer: ScrobbleSyncer) {
        self.musicPlayer = musicPlayer
        self.backendAudioPlayer = backendAudioPlayer
        self.storage = storage
        self.scrobbleSyncer = scrobbleSyncer
    }
    
    private func syncSongPlayed() {
        guard let curPlaying = musicPlayer.currentlyPlaying, let curPlayingSong = curPlaying.asSong else { return }
        var waitDuration = curPlayingSong.duration / 2
        if waitDuration > Self.maximumWaitDurationInSec {
            waitDuration = Self.maximumWaitDurationInSec
        }
        
        scrobbleTimer?.invalidate()
        scrobbleTimer = Timer.scheduledTimer(withTimeInterval: TimeInterval(waitDuration), repeats: false) { (t) in
            guard curPlaying == self.musicPlayer.currentlyPlaying,
                  self.backendAudioPlayer.playType == .cache || self.storage.settings.isScrobbleStreamedItems
            else { return }
            self.scrobbleSyncer.scrobble(playedSong: curPlayingSong)
        }
    }

}

extension SongPlayedSyncer: MusicPlayable {
    func didStartPlayingFromBeginning() {
        syncSongPlayed()
    }
    
    func didStartPlaying() { }
    func didPause() { }
    func didStopPlaying() { }
    func didElapsedTimeChange() { }
    func didPlaylistChange() { }
    func didArtworkChange() { }
}
