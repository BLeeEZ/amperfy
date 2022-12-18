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
    
    private static let minimumPlaytimeForNoAvailableDuration = 30
    private static let minimumPlaytimeForLongSongs = 60*4
    
    private let musicPlayer: AudioPlayer
    private let backendAudioPlayer: BackendAudioPlayer
    private let scrobbleSyncer: ScrobbleSyncer

    init(musicPlayer: AudioPlayer, backendAudioPlayer: BackendAudioPlayer, scrobbleSyncer: ScrobbleSyncer) {
        self.musicPlayer = musicPlayer
        self.backendAudioPlayer = backendAudioPlayer
        self.scrobbleSyncer = scrobbleSyncer
    }
    
    private func syncSongPlayed() {
        guard let curPlaying = musicPlayer.currentlyPlaying, let curPlayingSong = curPlaying.asSong else { return }
        var waitDuration = curPlayingSong.duration
        if waitDuration > 0 {
            waitDuration = curPlayingSong.duration / 2
            if waitDuration > Self.minimumPlaytimeForLongSongs {
                waitDuration = Self.minimumPlaytimeForLongSongs
            }
        } else {
            waitDuration = Self.minimumPlaytimeForNoAvailableDuration
        }
        
        DispatchQueue.global().async {
            sleep(UInt32(waitDuration))
            DispatchQueue.main.async {
                guard self.backendAudioPlayer.isPlaying, curPlaying == self.musicPlayer.currentlyPlaying, self.backendAudioPlayer.playType == .cache else { return }
                self.scrobbleSyncer.scrobble(playedSong: curPlayingSong)
            }
        }
    }

}

extension SongPlayedSyncer: MusicPlayable {
    func didStartPlaying() {
        syncSongPlayed()
    }
    
    func didPause() { }
    func didStopPlaying() { }
    func didElapsedTimeChange() { }
    func didPlaylistChange() { }
    func didArtworkChange() { }
}
