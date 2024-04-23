//
//  ScrobbleSyncer.swift
//  AmperfyKit
//
//  Created by Maximilian Bauer on 05.03.22.
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

import Foundation
import os.log
import PromiseKit

public class ScrobbleSyncer {
    
    private static let maximumWaitDurationInSec = 20

    private let log = OSLog(subsystem: "Amperfy", category: "ScrobbleSyncer")
    private let musicPlayer: AudioPlayer
    private let backendAudioPlayer: BackendAudioPlayer
    private let networkMonitor: NetworkMonitorFacade
    private let storage: PersistentStorage
    private let librarySyncer: LibrarySyncer
    private let eventLogger: EventLogger
    private let activeDispatchGroup = DispatchGroup()
    private let uploadSemaphore = DispatchSemaphore(value: 1)
    private var isRunning = false
    private var isActive = false
    private var scrobbleTimer: Timer?
    
    private var songToBeScrobbled: Song?
    private var songHasBeenListendEnough = false
    
    init(musicPlayer: AudioPlayer, backendAudioPlayer: BackendAudioPlayer, networkMonitor: NetworkMonitorFacade, storage: PersistentStorage, librarySyncer: LibrarySyncer, eventLogger: EventLogger) {
        self.musicPlayer = musicPlayer
        self.backendAudioPlayer = backendAudioPlayer
        self.networkMonitor = networkMonitor
        self.storage = storage
        self.librarySyncer = librarySyncer
        self.eventLogger = eventLogger
    }
    
    public func start() {
        guard storage.main.library.uploadableScrobbleEntryCount > 0 else { return }
        isRunning = true
        if !isActive {
            isActive = true
            uploadInBackground()
        }
    }
    
    public func stopAndWait() {
        isRunning = false
        activeDispatchGroup.wait()
    }
    
    func scrobble(playedSong: Song, songPosition: NowPlayingSongPosition) {
        func nowPlayingToServerAsync(playedSong: Song, songPosition: NowPlayingSongPosition) {
             firstly {
                self.librarySyncer.syncNowPlaying(song: playedSong, songPosition: songPosition)
            }.catch { error in
                self.eventLogger.report(topic: "Scrobble Sync", error: error, displayPopup: false)
            }
        }
        
        switch songPosition {
        case .start:
            if self.storage.settings.isOnlineMode, networkMonitor.isConnectedToNetwork {
                nowPlayingToServerAsync(playedSong: playedSong, songPosition: .start)
            }
        case .end:
            if self.storage.settings.isOnlineMode, networkMonitor.isConnectedToNetwork {
                cacheScrobbleRequest(playedSong: playedSong, isUploaded: true)
                nowPlayingToServerAsync(playedSong: playedSong, songPosition: .end)
                start() // send cached request to server
            } else {
                os_log("Scrobble cache: %s", log: self.log, type: .info, playedSong.displayString)
                cacheScrobbleRequest(playedSong: playedSong, isUploaded: false)
            }
        }
    }
    
    private func uploadInBackground() {
        DispatchQueue.global().async {
            self.activeDispatchGroup.enter()
            os_log("start", log: self.log, type: .info)
            
            while self.isRunning, self.storage.settings.isOnlineMode, self.networkMonitor.isConnectedToNetwork {
                self.uploadSemaphore.wait()
                firstlyOnMain {
                    self.getNextScrobbleEntry()
                }.then { scobbleEntry -> Promise<Void> in
                    guard let entry = scobbleEntry else {
                        self.isRunning = false
                        return Promise.value
                    }
                    defer {
                        entry.isUploaded = true;
                        self.storage.main.saveContext()
                    }
                    guard let song = entry.playable?.asSong, let date = entry.date else {
                        return Promise.value
                    }
                    return self.librarySyncer.scrobble(song: song, date: date)
                }.catch { error in
                    self.eventLogger.report(topic: "Scrobble Sync", error: error, displayPopup: false)
                }.finally {
                    self.uploadSemaphore.signal()
                }
            }
            
            os_log("stopped", log: self.log, type: .info)
            self.isActive = false
            self.activeDispatchGroup.leave()
        }
    }
    
    private func getNextScrobbleEntry() -> Promise<ScrobbleEntry?> {
        return Promise<ScrobbleEntry?> { seal in
            _ = self.storage.async.perform { asyncCompanion in
                guard let scobbleEntry = asyncCompanion.library.getFirstUploadableScrobbleEntry() else {
                    return seal.fulfill(nil)
                }
                let scobbleEntryMain = ScrobbleEntry(managedObject: try! self.storage.main.context.existingObject(with: scobbleEntry.managedObject.objectID) as! ScrobbleEntryMO)
                return seal.fulfill(scobbleEntryMain)
            }
        }
    }
    
    private func cacheScrobbleRequest(playedSong: Song, isUploaded: Bool) {
        let scrobbleEntry = storage.main.library.createScrobbleEntry()
        scrobbleEntry.date = Date()
        scrobbleEntry.playable = playedSong
        scrobbleEntry.isUploaded = isUploaded
        storage.main.saveContext()
    }
    
    private func startSongPlayed() {
        syncSongStopped(clearCurPlaying: true)
        
        guard let curPlaying = musicPlayer.currentlyPlaying,
              let curPlayingSong = curPlaying.asSong
        else { return }
        
        self.songToBeScrobbled = curPlayingSong
        
        var waitDuration = curPlayingSong.duration / 2
        if waitDuration > Self.maximumWaitDurationInSec {
            waitDuration = Self.maximumWaitDurationInSec
        }
        
        scrobbleTimer?.invalidate()
        scrobbleTimer = Timer.scheduledTimer(withTimeInterval: TimeInterval(waitDuration), repeats: false) { (t) in
            guard curPlaying == self.musicPlayer.currentlyPlaying,
                  self.backendAudioPlayer.playType == .cache || self.storage.settings.isScrobbleStreamedItems
            else { return }
            self.songHasBeenListendEnough = true
        }
    }
    
    private func syncSongStopped(clearCurPlaying: Bool) {
        func clearingCurPlaying() {
            self.songHasBeenListendEnough = false
            self.songToBeScrobbled = nil
        }
        
        if let oldSong = self.songToBeScrobbled,
           self.songHasBeenListendEnough {
            self.scrobble(playedSong: oldSong, songPosition: .end)
            clearingCurPlaying()
        } else if clearCurPlaying {
            clearingCurPlaying()
        }
    }
    
}

extension ScrobbleSyncer: MusicPlayable {
    public func didStartPlayingFromBeginning() {
        startSongPlayed()
    }
    public func didStartPlaying() {
        guard let curPlaying = musicPlayer.currentlyPlaying,
              let curPlayingSong = curPlaying.asSong
        else { return }
        scrobble(playedSong: curPlayingSong, songPosition: .start)
    }
    public func didPause() {
        syncSongStopped(clearCurPlaying: false)
    }
    public func didStopPlaying() {
        syncSongStopped(clearCurPlaying: true)
    }
    public func didElapsedTimeChange() { }
    public func didPlaylistChange() { }
    public func didArtworkChange() { }
    public func didShuffleChange() { }
    public func didRepeatChange() { }
    public func didPlaybackRateChange() { }
}
