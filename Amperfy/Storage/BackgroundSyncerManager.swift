import Foundation
import os.log

class BackgroundSyncerManager {
    
    private let log = OSLog(subsystem: AppDelegate.name, category: "BackgroundSyncer")
    private let storage : PersistentStorage
    private let backendApi: BackendApi
    private let libSyncer: BackgroundLibrarySyncer
    private let libVersionResyncer: BackgroundLibraryVersionResyncer
    private let semaphore = DispatchSemaphore(value: 1)
    private var isRunning = false
    var isActive: Bool {
        return libSyncer.isActive || libVersionResyncer.isActive
    }

    init(storage: PersistentStorage, backendApi: BackendApi) {
        self.storage = storage
        self.backendApi = backendApi
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
        libSyncer.stop()
        libVersionResyncer.stop()
    }
    
    func stopAndWait() {
        isRunning = false
        libSyncer.stopAndWait()
        libVersionResyncer.stopAndWait()
        os_log("SyncInBackground stopped", log: log, type: .info)
    }
    
    func performBlockingLibraryUpdatesIfNeeded() {
        if storage.librarySyncVersion < .v9 {
            os_log("Perform blocking library update (START): Artwork ids", log: log, type: .info)
            updateArtworkIdStructure()
            os_log("Perform blocking library update (DONE): Artwork ids", log: log, type: .info)
        }
    }
    
    private func updateArtworkIdStructure() {
        // Extract artwork info from URL
        let libraryStorage = LibraryStorage(context: storage.context)
        var artworks = libraryStorage.getArtworks()
        for artwork in artworks {
            if let artworkUrlInfo = self.backendApi.extractArtworkInfoFromURL(urlString: artwork.url) {
                artwork.type = artworkUrlInfo.type
                artwork.id = artworkUrlInfo.id
            } else {
                libraryStorage.deleteArtwork(artwork: artwork)
            }
        }
        libraryStorage.saveContext()

        // Delete duplicate artworks
        artworks = libraryStorage.getArtworks()
        var uniqueArtworks: [String: Artwork] = [:]
        for artwork in artworks {
            if let existingArtwork = uniqueArtworks[artwork.uniqueID] {
                artwork.owners.forEach{ $0.artwork = existingArtwork }
                libraryStorage.deleteArtwork(artwork: artwork)
            } else {
                uniqueArtworks[artwork.uniqueID] = artwork
            }
        }
        libraryStorage.saveContext()
    }
    
    private func syncInBackground() {
        os_log("SyncInBackground start", log: log, type: .info)
        if storage.librarySyncVersion <= .v6 {
            storage.persistentContainer.performBackgroundTask() { (context) in
                let backgroundLibrary = LibraryStorage(context: context)
                self.libVersionResyncer.resyncDueToNewLibraryVersionInBackground(libraryStorage: backgroundLibrary, libraryVersion: self.storage.librarySyncVersion)
                if let latestSyncWave = backgroundLibrary.getLatestSyncWave(), latestSyncWave.isDone {
                    os_log("Lib version resync done (Set lib sync version to %s)", log: self.log, type: .info, LibrarySyncVersion.newestVersion.description)
                    self.storage.librarySyncVersion = .newestVersion
                }
            }
        } else if storage.librarySyncVersion < .v9 {
            // Arwork ids library updates have been performed blocking before background sync started
            self.storage.librarySyncVersion = .v9
            syncLibrary()
        } else {
            syncLibrary()
        }
    }
    
    private func syncLibrary() {
        storage.persistentContainer.performBackgroundTask() { (context) in
            let backgroundLibrary = LibraryStorage(context: context)
            self.libSyncer.syncInBackground(libraryStorage: backgroundLibrary)
        }
    }
    
}
