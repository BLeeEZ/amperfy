//
//  AutoDownloadLibrarySyncer.swift
//  AmperfyKit
//
//  Created by Maximilian Bauer on 13.04.22.
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
import CoreData
import PromiseKit

public class AutoDownloadLibrarySyncer {
    
    private let storage: PersistentStorage
    private let librarySyncer: LibrarySyncer
    private let playableDownloadManager: DownloadManageable
    
    public init(storage: PersistentStorage, librarySyncer: LibrarySyncer, playableDownloadManager: DownloadManageable) {
        self.storage = storage
        self.librarySyncer = librarySyncer
        self.playableDownloadManager = playableDownloadManager
    }
    
    public func syncLatestLibraryElements() -> Promise<Void> {
        let oldRecentSongs = Set(storage.main.library.getRecentSongs())
        
        return firstly {
            self.librarySyncer.syncLatestLibraryElements()
        }.get {
            if self.storage.settings.isAutoDownloadLatestSongsActive {
                let updatedRecentSongs = Set(self.storage.main.library.getRecentSongs())
                let newAddedRecentSongs = updatedRecentSongs.subtracting(oldRecentSongs)
                self.playableDownloadManager.download(objects: Array(newAddedRecentSongs))
            }
        }
    }
    
    /// return: new synced podcast episodes if an initial sync already occued. If this is the initial sync no episods are returned
    public func syncLatestPodcastEpisodes(podcast: Podcast) -> Promise<[PodcastEpisode]> {
        let oldRecentEpisodes = Set(podcast.episodes)
        return firstly {
            self.librarySyncer.sync(podcast: podcast)
        }.then {
            return Guarantee<[PodcastEpisode]> { seal in
                let updatedEpisodes = Set(podcast.episodes)
                let newAddedRecentEpisodes = updatedEpisodes.subtracting(oldRecentEpisodes)
                if self.storage.settings.isAutoDownloadLatestSongsActive {
                    self.playableDownloadManager.download(objects: Array(newAddedRecentEpisodes))
                }
                if !oldRecentEpisodes.isEmpty {
                    seal(Array(newAddedRecentEpisodes))
                } else {
                    seal([PodcastEpisode]())
                }
                
            }
        }
    }
    
}
