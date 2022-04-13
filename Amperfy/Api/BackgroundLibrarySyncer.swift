import Foundation
import os.log

class BackgroundLibrarySyncer: AbstractBackgroundLibrarySyncer {
    
    private let persistentStorage: PersistentStorage
    private let backendApi: BackendApi
    private let playableDownloadManager: DownloadManageable
    
    private let log = OSLog(subsystem: AppDelegate.name, category: "BackgroundLibrarySyncer")
    private let activeDispatchGroup = DispatchGroup()
    private let syncSemaphore = DispatchSemaphore(value: 0)
    private var isRunning = false
    private var isCurrentlyActive = false
    
    init(persistentStorage: PersistentStorage, backendApi: BackendApi, playableDownloadManager: DownloadManageable) {
        self.persistentStorage = persistentStorage
        self.backendApi = backendApi
        self.playableDownloadManager = playableDownloadManager
    }
    
    var isActive: Bool { return isCurrentlyActive }
    
    func start() {
        isRunning = true
        if !isCurrentlyActive {
            isCurrentlyActive = true
            syncAlbumSongsInBackground()
        }
    }
    
    func stop() {
        isRunning = false
    }

    func stopAndWait() {
        isRunning = false
        activeDispatchGroup.wait()
    }
    
    private func syncAlbumSongsInBackground() {
        DispatchQueue.global().async {
            self.activeDispatchGroup.enter()
            os_log("start", log: self.log, type: .info)
            
            if self.isRunning, self.persistentStorage.settings.isOnlineMode, Reachability.isConnectedToNetwork() {
                self.persistentStorage.persistentContainer.performBackgroundTask() { (context) in
                    defer { self.syncSemaphore.signal() }
                    let autoDownloadSyncer = AutoDownloadLibrarySyncer(settings: self.persistentStorage.settings, backendApi: self.backendApi, playableDownloadManager: self.playableDownloadManager)
                    autoDownloadSyncer.syncLatestLibraryElements(context: context)
                }
                self.syncSemaphore.wait()
            }

            while self.isRunning, self.persistentStorage.settings.isOnlineMode, Reachability.isConnectedToNetwork() {
                self.persistentStorage.persistentContainer.performBackgroundTask() { (context) in
                    defer { self.syncSemaphore.signal() }
                    let library = LibraryStorage(context: context)
                    let albumToSync = library.getAlbumWithoutSyncedSongs()
                    guard let albumToSync = albumToSync else {
                        self.isRunning = false
                        return
                    }
                    albumToSync.fetchFromServer(inContext: context, backendApi: self.backendApi, settings: self.persistentStorage.settings, playableDownloadManager: self.playableDownloadManager)
                }
                self.syncSemaphore.wait()
            }
            
            os_log("stopped", log: self.log, type: .info)
            self.isCurrentlyActive = false
            self.activeDispatchGroup.leave()
        }
    }

}
