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
    
    private let persistentStorage: PersistentStorage
    private let backendApi: BackendApi
    private let playableDownloadManager: DownloadManageable
    
    public init(persistentStorage: PersistentStorage, backendApi: BackendApi, playableDownloadManager: DownloadManageable) {
        self.persistentStorage = persistentStorage
        self.backendApi = backendApi
        self.playableDownloadManager = playableDownloadManager
    }
    
    public func syncLatestLibraryElements() -> Promise<Void> {
        let library = LibraryStorage(context: persistentStorage.context)
        let oldRecentSongs = Set(library.getRecentSongs())
        
        return firstly {
            self.backendApi.createLibrarySyncer().syncLatestLibraryElements(persistentStorage: persistentStorage)
        }.get {
            if self.persistentStorage.settings.isAutoDownloadLatestSongsActive {
                let updatedRecentSongs = Set(library.getRecentSongs())
                let newAddedRecentSongs = updatedRecentSongs.subtracting(oldRecentSongs)
                self.playableDownloadManager.download(objects: Array(newAddedRecentSongs))
            }
        }
    }
    
    /// return: new synced podcast episodes if an initial sync already occued. If this is the initial sync no episods are returned
    public func syncLatestPodcastEpisodes(podcast: Podcast) -> Promise<[PodcastEpisode]> {
        let oldRecentEpisodes = Set(podcast.episodes)
        return firstly {
            self.backendApi.createLibrarySyncer().sync(podcast: podcast, persistentContainer: persistentStorage.persistentContainer)
        }.then {
            return Guarantee<[PodcastEpisode]> { seal in
                let updatedEpisodes = Set(podcast.episodes)
                let newAddedRecentEpisodes = updatedEpisodes.subtracting(oldRecentEpisodes)
                if self.persistentStorage.settings.isAutoDownloadLatestSongsActive {
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
