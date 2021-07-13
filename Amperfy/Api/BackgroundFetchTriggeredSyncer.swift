import Foundation
import UIKit
import os.log

class BackgroundFetchTriggeredSyncer {
    
    private let library: LibraryStorage
    private let backendApi: BackendApi
    private let notificationManager: LocalNotificationManager
    private let log = OSLog(subsystem: AppDelegate.name, category: "BackgroundFetchTriggeredSyncer")
    
    init(library: LibraryStorage, backendApi: BackendApi, notificationManager: LocalNotificationManager) {
        self.library = library
        self.backendApi = backendApi
        self.notificationManager = notificationManager
    }
    
    func syncAndNotifyPodcastEpisodes() -> UIBackgroundFetchResult {
        os_log("Perform podcast episode sync", log: self.log, type: .info)
        let syncer = backendApi.createLibrarySyncer()
        syncer.syncDownPodcastsWithoutEpisodes(library: library)
        
        var backgroundFetchResult = UIBackgroundFetchResult.noData
        for podcast in library.getPodcasts() {
            let oldEpisodes = Set(podcast.episodes)
            syncer.sync(podcast: podcast, library: library)
            let currentEpisodes = Set(podcast.episodes)
            if oldEpisodes.count > 0 {
                let newEpisodes = currentEpisodes.subtracting(oldEpisodes)
                newEpisodes.forEach {
                    notificationManager.notify(podcastEpisode: $0)
                    os_log("Podcast: %s, New Episode: %s", log: self.log, type: .info, podcast.title, $0.title)
                    backgroundFetchResult = .newData
                }
            } else {
                os_log("Podcast: %s, Inital episode sync", log: self.log, type: .info, podcast.title)
                backgroundFetchResult = .newData
            }
        }
        return backgroundFetchResult
    }

}
