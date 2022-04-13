import Foundation
import CoreData

class AutoDownloadLibrarySyncer {
    
    private let persistentStorage: PersistentStorage
    private let backendApi: BackendApi
    private let playableDownloadManager: DownloadManageable
    
    init(persistentStorage: PersistentStorage, backendApi: BackendApi, playableDownloadManager: DownloadManageable) {
        self.persistentStorage = persistentStorage
        self.backendApi = backendApi
        self.playableDownloadManager = playableDownloadManager
    }
    
    func syncLatestLibraryElements(context: NSManagedObjectContext) {
        let library = LibraryStorage(context: context)
        let syncer = self.backendApi.createLibrarySyncer()
        let oldRecentSongs = Set(library.getRecentSongs())
        syncer.syncLatestLibraryElements(library: library)
        if persistentStorage.settings.isAutoDownloadLatestSongsActive {
            let updatedRecentSongs = Set(library.getRecentSongs())
            let newAddedRecentSongs = updatedRecentSongs.subtracting(oldRecentSongs)
            playableDownloadManager.download(objects: Array(newAddedRecentSongs))
        }
    }
}
