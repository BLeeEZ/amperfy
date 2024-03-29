//
//  DuplicateEntitiesResolver.swift
//  AmperfyKit
//
//  Created by Maximilian Bauer on 30.05.22.
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

public class DuplicateEntitiesResolver {
    
    private let log = OSLog(subsystem: "Amperfy", category: "DuplicateEntitiesResolver")
    private let storage: PersistentStorage
    private let activeDispatchGroup = DispatchGroup()
    private let mainFlowSemaphore = DispatchSemaphore(value: 1)
    private var isRunning = false
    private var isActive = false
    
    init(storage: PersistentStorage) {
        self.storage = storage
    }
    
    public func start() {
        isRunning = true
        if !isActive {
            isActive = true
            resolveDuplicatesInBackground()
        }
    }
    
    public func stopAndWait() {
        isRunning = false
        activeDispatchGroup.wait()
    }
    
    private func resolveDuplicatesInBackground() {
        DispatchQueue.global().async {
            self.activeDispatchGroup.enter()
            os_log("start", log: self.log, type: .info)
            
            // only check for duplicates on Ampache API, Subsonic does not have genre ids
            if self.isRunning, self.storage.loginCredentials?.backendApi == .ampache {
                self.mainFlowSemaphore.wait()
                self.storage.async.perform { asyncCompanion in
                    defer { self.mainFlowSemaphore.signal() }
                    let duplicates = asyncCompanion.library.findDuplicates(for: Genre.typeName).filter{ $0.id != "" }
                    asyncCompanion.library.resolveGenresDuplicates(duplicates: duplicates)
                    asyncCompanion.saveContext()
                }.catch { error in }
            }
            
            if self.isRunning {
                self.mainFlowSemaphore.wait()
                self.storage.async.perform { asyncCompanion in
                    defer { self.mainFlowSemaphore.signal() }
                    let duplicates = asyncCompanion.library.findDuplicates(for: Artist.typeName).filter{ $0.id != "" }
                    asyncCompanion.library.resolveArtistsDuplicates(duplicates: duplicates)
                    asyncCompanion.saveContext()
                }.catch { error in }
            }
            
            if self.isRunning {
                self.mainFlowSemaphore.wait()
                self.storage.async.perform { asyncCompanion in
                    defer { self.mainFlowSemaphore.signal() }
                    let duplicates = asyncCompanion.library.findDuplicates(for: Album.typeName).filter{ $0.id != "" }
                    asyncCompanion.library.resolveAlbumsDuplicates(duplicates: duplicates)
                    asyncCompanion.saveContext()
                }.catch { error in }
            }
            
            if self.isRunning {
                self.mainFlowSemaphore.wait()
                self.storage.async.perform { asyncCompanion in
                    defer { self.mainFlowSemaphore.signal() }
                    let duplicates = asyncCompanion.library.findDuplicates(for: Song.typeName).filter{ $0.id != "" }
                    asyncCompanion.library.resolveSongsDuplicates(duplicates: duplicates)
                    asyncCompanion.saveContext()
                }.catch { error in }
            }
            
            if self.isRunning {
                self.mainFlowSemaphore.wait()
                self.storage.async.perform { asyncCompanion in
                    defer { self.mainFlowSemaphore.signal() }
                    let duplicates = asyncCompanion.library.findDuplicates(for: PodcastEpisode.typeName).filter{ $0.id != "" }
                    asyncCompanion.library.resolvePodcastEpisodesDuplicates(duplicates: duplicates)
                    asyncCompanion.saveContext()
                }.catch { error in }
            }
            
            if self.isRunning {
                self.mainFlowSemaphore.wait()
                self.storage.async.perform { asyncCompanion in
                    defer { self.mainFlowSemaphore.signal() }
                    let duplicates = asyncCompanion.library.findDuplicates(for: Podcast.typeName).filter{ $0.id != "" }
                    asyncCompanion.library.resolvePodcastsDuplicates(duplicates: duplicates)
                    asyncCompanion.saveContext()
                }.catch { error in }
            }
            
            if self.isRunning {
                self.mainFlowSemaphore.wait()
                self.storage.async.perform { asyncCompanion in
                    defer { self.mainFlowSemaphore.signal() }
                    let duplicates = asyncCompanion.library.findDuplicates(for: Playlist.typeName).filter{ $0.id != "" }
                    asyncCompanion.library.resolvePlaylistsDuplicates(duplicates: duplicates)
                    asyncCompanion.saveContext()
                }.catch { error in }
            }
            
            os_log("stopped", log: self.log, type: .info)
            self.isActive = false
            self.activeDispatchGroup.leave()
        }
    }
    
}
