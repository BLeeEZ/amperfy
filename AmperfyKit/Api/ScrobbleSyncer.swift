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
    
    private let log = OSLog(subsystem: "Amperfy", category: "ScrobbleSyncer")
    private let storage: PersistentStorage
    private let librarySyncer: LibrarySyncer
    private let eventLogger: EventLogger
    private let activeDispatchGroup = DispatchGroup()
    private let uploadSemaphore = DispatchSemaphore(value: 1)
    private var isRunning = false
    private var isActive = false
    
    init(storage: PersistentStorage, librarySyncer: LibrarySyncer, eventLogger: EventLogger) {
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
    
    func scrobble(playedSong: Song) {
        if self.storage.settings.isOnlineMode, Reachability.isConnectedToNetwork() {
            cacheScrobbleRequest(playedSong: playedSong, isUploaded: true)
            scrobbleToServerAsync(playedSong: playedSong)
            start() // send cached request to server
        } else {
            os_log("Scrobble cache: %s", log: self.log, type: .info, playedSong.displayString)
            cacheScrobbleRequest(playedSong: playedSong, isUploaded: false)
        }
    }
    
    private func uploadInBackground() {
        DispatchQueue.global().async {
            self.activeDispatchGroup.enter()
            os_log("start", log: self.log, type: .info)
            
            while self.isRunning, self.storage.settings.isOnlineMode, Reachability.isConnectedToNetwork() {
                self.uploadSemaphore.wait()
                firstly {
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
    
    private func scrobbleToServerAsync(playedSong: Song) {
        firstly {
            self.librarySyncer.scrobble(song: playedSong, date: nil)
        }.catch { error in
            self.eventLogger.report(topic: "Scrobble Sync", error: error, displayPopup: false)
        }
    }
    
    private func cacheScrobbleRequest(playedSong: Song, isUploaded: Bool) {
        let scrobbleEntry = storage.main.library.createScrobbleEntry()
        scrobbleEntry.date = Date()
        scrobbleEntry.playable = playedSong
        scrobbleEntry.isUploaded = isUploaded
        storage.main.saveContext()
    }
    
}
