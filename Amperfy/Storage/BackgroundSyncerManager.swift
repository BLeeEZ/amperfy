import Foundation
import os.log

class BackgroundSyncerManager {
    
    private let log = OSLog(subsystem: AppDelegate.name, category: "BackgroundSyncer")
    private let persistentStorage : PersistentStorage
    private let backendApi: BackendApi
    private let libSyncer: BackgroundLibrarySyncer
    private let libVersionResyncer: BackgroundLibraryVersionResyncer
    private let semaphore = DispatchSemaphore(value: 1)
    private var isRunning = false
    var isActive: Bool {
        return libSyncer.isActive || libVersionResyncer.isActive
    }

    init(persistentStorage: PersistentStorage, backendApi: BackendApi) {
        self.persistentStorage = persistentStorage
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
        if persistentStorage.librarySyncVersion < .v9 {
            os_log("Perform blocking library update (START): Artwork ids", log: log, type: .info)
            updateArtworkIdStructure()
            os_log("Perform blocking library update (DONE): Artwork ids", log: log, type: .info)
        }
    }
    
    private func updateArtworkIdStructure() {
        // Extract artwork info from URL
        let library = LibraryStorage(context: persistentStorage.context)
        var artworks = library.getArtworks()
        for artwork in artworks {
            if let artworkUrlInfo = self.backendApi.extractArtworkInfoFromURL(urlString: artwork.url) {
                artwork.type = artworkUrlInfo.type
                artwork.id = artworkUrlInfo.id
            } else {
                library.deleteArtwork(artwork: artwork)
            }
        }
        library.saveContext()

        // Delete duplicate artworks
        artworks = library.getArtworks()
        var uniqueArtworks: [String: Artwork] = [:]
        for artwork in artworks {
            if let existingArtwork = uniqueArtworks[artwork.uniqueID] {
                artwork.owners.forEach{ $0.artwork = existingArtwork }
                library.deleteArtwork(artwork: artwork)
            } else {
                uniqueArtworks[artwork.uniqueID] = artwork
            }
        }
        library.saveContext()
    }
    
    private func syncInBackground() {
        os_log("SyncInBackground start", log: log, type: .info)
        if persistentStorage.librarySyncVersion <= .v6 {
            persistentStorage.persistentContainer.performBackgroundTask() { (context) in
                let syncLibrary = LibraryStorage(context: context)
                self.libVersionResyncer.resyncDueToNewLibraryVersionInBackground(library: syncLibrary, libraryVersion: self.persistentStorage.librarySyncVersion)
                if let latestSyncWave = syncLibrary.getLatestSyncWave(), latestSyncWave.isDone {
                    os_log("Lib version resync done (Set lib sync version to %s)", log: self.log, type: .info, LibrarySyncVersion.newestVersion.description)
                    self.persistentStorage.librarySyncVersion = .newestVersion
                }
            }
        } else if persistentStorage.librarySyncVersion < .v9 {
            // Arwork ids library updates have been performed blocking before background sync started
            self.persistentStorage.librarySyncVersion = .v9
            syncLibrary()
        } else {
            syncLibrary()
        }
    }
    
    private func syncLibrary() {
        persistentStorage.persistentContainer.performBackgroundTask() { (context) in
            let syncLibrary = LibraryStorage(context: context)
            self.libSyncer.syncInBackground(library: syncLibrary)
        }
    }
    
}
