import Foundation
import os.log

class BackgroundSyncer {
    
    private let log = OSLog(subsystem: AppDelegate.name, category: "backgroundSyncer")
    private let storage : PersistentStorage
    private let ampacheApi: AmpacheApi
    private let artworkSyncer: ArtworkSyncer
    private let libSyncer: LibrarySyncer
    private let semaphore = DispatchSemaphore(value: 1)
    private var isRunning = false
    var isActive: Bool {
        return artworkSyncer.isActive || libSyncer.isActive
    }

    init(storage: PersistentStorage, ampacheApi: AmpacheApi) {
        self.storage = storage
        self.ampacheApi = ampacheApi
        self.artworkSyncer = ArtworkSyncer(ampacheApi: self.ampacheApi)
        self.libSyncer = LibrarySyncer(ampacheApi: self.ampacheApi)
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
    }
    
    func stopAndWait() {
        isRunning = false
        artworkSyncer.stopAndWait()
        libSyncer.stopAndWait()
    }
    
    private func syncInBackground() {
        os_log("BackgroundSyncer start syncInBackground", log: log, type: .info)
        storage.persistentContainer.performBackgroundTask() { (context) in
            let backgroundLibrary = LibraryStorage(context: context)
            self.artworkSyncer.syncInBackground(libraryStorage: backgroundLibrary)
        }
        storage.persistentContainer.performBackgroundTask() { (context) in
            let backgroundLibrary = LibraryStorage(context: context)
            self.libSyncer.syncInBackground(libraryStorage: backgroundLibrary)
        }
    }
    
}
