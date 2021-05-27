import Foundation
import os.log

class BackgroundSyncerManager {
    
    private let log = OSLog(subsystem: AppDelegate.name, category: "BackgroundSyncer")
    private let storage : PersistentStorage
    private let backendApi: BackendApi
    private let artworkSyncer: BackgroundLibrarySyncer
    private let libSyncer: BackgroundLibrarySyncer
    private let libVersionResyncer: BackgroundLibraryVersionResyncer
    private let semaphore = DispatchSemaphore(value: 1)
    private var isRunning = false
    var isActive: Bool {
        return artworkSyncer.isActive || libSyncer.isActive || libVersionResyncer.isActive
    }

    init(storage: PersistentStorage, backendApi: BackendApi) {
        self.storage = storage
        self.backendApi = backendApi
        self.artworkSyncer = backendApi.createArtworkBackgroundSyncer()
        self.libSyncer = backendApi.createLibraryBackgroundSyncer()
        self.libVersionResyncer = backendApi.createLibraryVersionBackgroundResyncer()
    }
    
    func start() {
        semaphore.wait()
        if !isRunning, !isActive {
            isRunning = true
            syncInBackground()
        }
        semaphore.signal()
    }
    
    func stop() {
        isRunning = false
        artworkSyncer.stop()
        libSyncer.stop()
        libVersionResyncer.stop()
    }
    
    func stopAndWait() {
        isRunning = false
        artworkSyncer.stopAndWait()
        libSyncer.stopAndWait()
        libVersionResyncer.stopAndWait()
        os_log("SyncInBackground stopped", log: log, type: .info)
    }
    
    private func syncInBackground() {
        os_log("SyncInBackground start", log: log, type: .info)
        storage.persistentContainer.performBackgroundTask() { (context) in
            let backgroundLibrary = LibraryStorage(context: context)
            self.artworkSyncer.syncInBackground(libraryStorage: backgroundLibrary)
        }
        if storage.librarySyncVersion > .v6 {
            storage.persistentContainer.performBackgroundTask() { (context) in
                let backgroundLibrary = LibraryStorage(context: context)
                self.libSyncer.syncInBackground(libraryStorage: backgroundLibrary)
            }
        } else {
            storage.persistentContainer.performBackgroundTask() { (context) in
                let backgroundLibrary = LibraryStorage(context: context)
                self.libVersionResyncer.resyncDueToNewLibraryVersionInBackground(libraryStorage: backgroundLibrary, libraryVersion: self.storage.librarySyncVersion)
                if let latestSyncWave = backgroundLibrary.getLatestSyncWave(), latestSyncWave.isDone {
                    os_log("Lib version resync done (Set lib sync version to %s)", log: self.log, type: .info, LibrarySyncVersion.newestVersion.description)
                    self.storage.librarySyncVersion = .newestVersion
                }
            }
        }
    }
    
}
