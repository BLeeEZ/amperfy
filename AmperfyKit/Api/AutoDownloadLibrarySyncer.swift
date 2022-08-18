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

public class AutoDownloadLibrarySyncer {
    
    private let settings: PersistentStorage.Settings
    private let backendApi: BackendApi
    private let playableDownloadManager: DownloadManageable
    
    public init(settings: PersistentStorage.Settings, backendApi: BackendApi, playableDownloadManager: DownloadManageable) {
        self.settings = settings
        self.backendApi = backendApi
        self.playableDownloadManager = playableDownloadManager
    }
    
    public func syncLatestLibraryElements(context: NSManagedObjectContext) {
        let library = LibraryStorage(context: context)
        let syncer = self.backendApi.createLibrarySyncer()
        let oldRecentSongs = Set(library.getRecentSongs())
        syncer.syncLatestLibraryElements(library: library)
        if settings.isAutoDownloadLatestSongsActive {
            let updatedRecentSongs = Set(library.getRecentSongs())
            let newAddedRecentSongs = updatedRecentSongs.subtracting(oldRecentSongs)
            playableDownloadManager.download(objects: Array(newAddedRecentSongs))
        }
    }
    
    public func syncLatestPodcastEpisodes(podcast: Podcast, context: NSManagedObjectContext) -> [PodcastEpisode]{
        let library = LibraryStorage(context: context)
        let syncer = self.backendApi.createLibrarySyncer()
        let oldRecentEpisodes = Set(podcast.episodes)
        syncer.sync(podcast: podcast, library: library)
        let updatedEpisodes = Set(podcast.episodes)
        let newAddedRecentEpisodes = updatedEpisodes.subtracting(oldRecentEpisodes)
        if settings.isAutoDownloadLatestSongsActive {
            playableDownloadManager.download(objects: Array(newAddedRecentEpisodes))
        }
        return Array(newAddedRecentEpisodes)
    }
    
}
