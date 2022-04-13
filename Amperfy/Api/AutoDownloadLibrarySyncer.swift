import Foundation
import CoreData

class AutoDownloadLibrarySyncer {
    
    private let settings: PersistentStorage.Settings
    private let backendApi: BackendApi
    private let playableDownloadManager: DownloadManageable
    
    init(settings: PersistentStorage.Settings, backendApi: BackendApi, playableDownloadManager: DownloadManageable) {
        self.settings = settings
        self.backendApi = backendApi
        self.playableDownloadManager = playableDownloadManager
    }
    
    func syncLatestLibraryElements(context: NSManagedObjectContext) {
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
    
    func syncLatestPodcastEpisodes(podcast: Podcast, context: NSManagedObjectContext) -> [PodcastEpisode]{
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
