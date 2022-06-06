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
