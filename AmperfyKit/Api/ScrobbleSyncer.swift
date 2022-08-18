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

public class ScrobbleSyncer {
    
    private let log = OSLog(subsystem: "Amperfy", category: "ScrobbleSyncer")
    private let persistentStorage: PersistentStorage
    private let backendApi: BackendApi
    private let activeDispatchGroup = DispatchGroup()
    private let uploadSemaphore = DispatchSemaphore(value: 1)
    private var isRunning = false
    private var isActive = false
    
    init(persistentStorage: PersistentStorage, backendApi: BackendApi) {
        self.persistentStorage = persistentStorage
        self.backendApi = backendApi
    }
    
    public func start() {
        let library = LibraryStorage(context: persistentStorage.context)
        guard library.uploadableScrobbleEntryCount > 0 else { return }
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
        if self.persistentStorage.settings.isOnlineMode, Reachability.isConnectedToNetwork() {
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
            
            while self.isRunning, self.persistentStorage.settings.isOnlineMode, Reachability.isConnectedToNetwork() {
                self.uploadSemaphore.wait()
                self.persistentStorage.persistentContainer.performBackgroundTask() { (context) in
                    defer { self.uploadSemaphore.signal() }
                    let library = LibraryStorage(context: context)
                    let scobbleEntry = library.getFirstUploadableScrobbleEntry()
                    defer { scobbleEntry?.isUploaded = true; library.saveContext() }
                    guard let entry = scobbleEntry, let song = entry.playable?.asSong, let date = entry.date else {
                        self.isRunning = false
                        return
                    }
                    let syncer = self.backendApi.createLibrarySyncer()
                    syncer.scrobble(song: song, date: date)
                 }
            }
            
            os_log("stopped", log: self.log, type: .info)
            self.isActive = false
            self.activeDispatchGroup.leave()
        }
    }
    
    private func scrobbleToServerAsync(playedSong: Song) {
        persistentStorage.persistentContainer.performBackgroundTask() { (context) in
            let syncer = self.backendApi.createLibrarySyncer()
            let songMO = try! context.existingObject(with: playedSong.managedObject.objectID) as! SongMO
            let song = Song(managedObject: songMO)
            syncer.scrobble(song: song, date: nil)
        }
    }
    
    private func cacheScrobbleRequest(playedSong: Song, isUploaded: Bool) {
        let library = LibraryStorage(context: persistentStorage.context)
        let scrobbleEntry = library.createScrobbleEntry()
        scrobbleEntry.date = Date()
        scrobbleEntry.playable = playedSong
        scrobbleEntry.isUploaded = isUploaded
        library.saveContext()
    }
    
}
