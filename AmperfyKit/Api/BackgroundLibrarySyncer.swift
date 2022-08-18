//
//  BackgroundLibrarySyncer.swift
//  AmperfyKit
//
//  Created by Maximilian Bauer on 12.04.22.
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

public class BackgroundLibrarySyncer: AbstractBackgroundLibrarySyncer {
    
    private let persistentStorage: PersistentStorage
    private let backendApi: BackendApi
    private let playableDownloadManager: DownloadManageable
    
    private let log = OSLog(subsystem: "Amperfy", category: "BackgroundLibrarySyncer")
    private let activeDispatchGroup = DispatchGroup()
    private let syncSemaphore = DispatchSemaphore(value: 0)
    private var isRunning = false
    private var isCurrentlyActive = false
    
    init(persistentStorage: PersistentStorage, backendApi: BackendApi, playableDownloadManager: DownloadManageable) {
        self.persistentStorage = persistentStorage
        self.backendApi = backendApi
        self.playableDownloadManager = playableDownloadManager
    }
    
    var isActive: Bool { return isCurrentlyActive }
    
    public func start() {
        isRunning = true
        if !isCurrentlyActive {
            isCurrentlyActive = true
            syncAlbumSongsInBackground()
        }
    }
    
    public func stop() {
        isRunning = false
    }

    public func stopAndWait() {
        isRunning = false
        activeDispatchGroup.wait()
    }
    
    private func syncAlbumSongsInBackground() {
        DispatchQueue.global().async {
            self.activeDispatchGroup.enter()
            os_log("start", log: self.log, type: .info)
            
            if self.isRunning, self.persistentStorage.settings.isOnlineMode, Reachability.isConnectedToNetwork() {
                self.persistentStorage.persistentContainer.performBackgroundTask() { (context) in
                    defer { self.syncSemaphore.signal() }
                    let autoDownloadSyncer = AutoDownloadLibrarySyncer(settings: self.persistentStorage.settings, backendApi: self.backendApi, playableDownloadManager: self.playableDownloadManager)
                    autoDownloadSyncer.syncLatestLibraryElements(context: context)
                }
                self.syncSemaphore.wait()
            }

            while self.isRunning, self.persistentStorage.settings.isOnlineMode, Reachability.isConnectedToNetwork() {
                self.persistentStorage.persistentContainer.performBackgroundTask() { (context) in
                    defer { self.syncSemaphore.signal() }
                    let library = LibraryStorage(context: context)
                    let albumToSync = library.getAlbumWithoutSyncedSongs()
                    guard let albumToSync = albumToSync else {
                        self.isRunning = false
                        return
                    }
                    albumToSync.fetchFromServer(inContext: context, backendApi: self.backendApi, settings: self.persistentStorage.settings, playableDownloadManager: self.playableDownloadManager)
                }
                self.syncSemaphore.wait()
            }
            
            os_log("stopped", log: self.log, type: .info)
            self.isCurrentlyActive = false
            self.activeDispatchGroup.leave()
        }
    }

}
