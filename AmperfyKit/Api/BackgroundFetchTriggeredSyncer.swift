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
    
    public func syncAndNotifyPodcastEpisodes(completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        persistentStorage.persistentContainer.performBackgroundTask() { (context) in
            os_log("Perform podcast episode sync", log: self.log, type: .info)
            let syncLibrary = LibraryStorage(context: context)
            let syncer = self.backendApi.createLibrarySyncer()
            syncer.syncDownPodcastsWithoutEpisodes(library: syncLibrary)
            
            var backgroundFetchResult = UIBackgroundFetchResult.noData
            var episodesToNotify = [PodcastEpisode]()
            for podcast in syncLibrary.getPodcasts() {
                let oldEpisodes = Set(podcast.episodes)
                let autoDownloadSyncer = AutoDownloadLibrarySyncer(settings: self.persistentStorage.settings, backendApi: self.backendApi, playableDownloadManager: self.playableDownloadManager)
                let newAddedRecentEpisodes = autoDownloadSyncer.syncLatestPodcastEpisodes(podcast: podcast, context: context)
                if oldEpisodes.count > 0 {
                    for newEpisode in newAddedRecentEpisodes {
                        os_log("Podcast: %s, New Episode: %s", log: self.log, type: .info, podcast.title, newEpisode.title)
                        episodesToNotify.append(newEpisode)
                        backgroundFetchResult = .newData
                    }
                } else {
                    os_log("Podcast: %s, Inital episode sync", log: self.log, type: .info, podcast.title)
                    backgroundFetchResult = .newData
                }
            }
            DispatchQueue.main.async {
                for newEpisode in episodesToNotify {
                    let episodeMO = try! context.existingObject(with: newEpisode.managedObject.objectID) as! PodcastEpisodeMO
                    let episodeToNotify = PodcastEpisode(managedObject: episodeMO)
                    self.notificationManager.notify(podcastEpisode: episodeToNotify)
                }
                completionHandler(backgroundFetchResult)
            }
        }
    }

}
