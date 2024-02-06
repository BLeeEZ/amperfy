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
import OSLog

public class AutoDownloadLibrarySyncer {
    
    private let log = OSLog(subsystem: "Amperfy", category: "AutoDownloadLibrarySyncer")
    private let storage: PersistentStorage
    private let librarySyncer: LibrarySyncer
    private let playableDownloadManager: DownloadManageable
    
    public init(storage: PersistentStorage, librarySyncer: LibrarySyncer, playableDownloadManager: DownloadManageable) {
        self.storage = storage
        self.librarySyncer = librarySyncer
        self.playableDownloadManager = playableDownloadManager
    }
    
    public func syncNewestLibraryElements(offset: Int = 0, count: Int = AmperKit.newestElementsFetchCount) -> Promise<Void> {
        let oldNewestAlbums = Set(storage.main.library.getNewestAlbums(offset: 0, count: count))
        var newNewestAlbums = Set<Album>()
        var fetchNeededNewestAlbums = Set<Album>()
        
        return firstly {
            self.librarySyncer.syncNewestAlbums(offset: offset, count: count)
        }.get {
            let updatedNewestAlbums = Set(self.storage.main.library.getNewestAlbums(offset: 0, count: count))
            newNewestAlbums = updatedNewestAlbums.subtracting(oldNewestAlbums)
            if offset == 0 {
                if newNewestAlbums.isEmpty {
                    os_log("No new albums", log: self.log, type: .info)
                } else {
                    os_log("%i new albums", log: self.log, type: .info, newNewestAlbums.count)
                }
            }
            fetchNeededNewestAlbums = newNewestAlbums.filter { !$0.isSongsMetaDataSynced }
        }.then { () -> Promise<Void> in
            let albumPromises = fetchNeededNewestAlbums.compactMap { album -> (() ->Promise<Void>) in return {
                return firstly {
                    self.librarySyncer.sync(album: album)
                }
            }}
            return albumPromises.resolveSequentially()
        }.get {
            if offset == 0, !oldNewestAlbums.isEmpty, !newNewestAlbums.isEmpty, self.storage.settings.isAutoDownloadLatestSongsActive {
                var newestSongs = [AbstractPlayable]()
                for album in newNewestAlbums {
                    newestSongs.append(contentsOf: album.songs)
                }
                self.playableDownloadManager.download(objects: newestSongs)
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
