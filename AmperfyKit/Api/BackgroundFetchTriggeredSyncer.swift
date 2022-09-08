//
//  BackgroundFetchTriggeredSyncer.swift
//  AmperfyKit
//
//  Created by Maximilian Bauer on 13.07.21.
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
import UIKit
import os.log
import CoreData
import PromiseKit

public class BackgroundFetchTriggeredSyncer {
    
    private let persistentStorage: PersistentStorage
    private let backendApi: BackendApi
    private let notificationManager: LocalNotificationManager
    private let playableDownloadManager: DownloadManageable
    private let log = OSLog(subsystem: "Amperfy", category: "BackgroundFetchTriggeredSyncer")
    
    init(persistentStorage: PersistentStorage, backendApi: BackendApi, notificationManager: LocalNotificationManager, playableDownloadManager: DownloadManageable) {
        self.persistentStorage = persistentStorage
        self.backendApi = backendApi
        self.notificationManager = notificationManager
        self.playableDownloadManager = playableDownloadManager
    }
    
    public func syncAndNotifyPodcastEpisodes() -> Promise<Void> {
        os_log("Perform podcast episode sync", log: self.log, type: .info)
        return firstly {
            self.backendApi.createLibrarySyncer().syncDownPodcastsWithoutEpisodes(persistentContainer: self.persistentStorage.persistentContainer)
        }.then { () -> Promise<Void> in
            let library = LibraryStorage(context: self.persistentStorage.context)
            let podcasts = library.getPodcasts()
            let podcastNotificationPromises = podcasts.compactMap { podcast in return {
                self.createPodcastNotificationPromise(podcast: podcast, persistentContainer: self.persistentStorage.persistentContainer)
            }}
            return podcastNotificationPromises.resolveSequentially()
        }
    }
    
    private func createPodcastNotificationPromise(podcast: Podcast, persistentContainer: NSPersistentContainer) -> Promise<Void> {
        return firstly {
            AutoDownloadLibrarySyncer(persistentStorage: self.persistentStorage,
                                      backendApi: self.backendApi,
                                      playableDownloadManager: self.playableDownloadManager)
            .syncLatestPodcastEpisodes(podcast: podcast)
        }.then { addedPodcasts -> Guarantee<Void> in
            for episodeToNotify in addedPodcasts {
                os_log("Podcast: %s, New Episode: %s", log: self.log, type: .info, podcast.title, episodeToNotify.title)
                self.notificationManager.notify(podcastEpisode: episodeToNotify)
            }
            return Guarantee<Void>.value
        }
    }

}
