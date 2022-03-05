import Foundation
import os.log

class ScrobbleSyncer {
    
    private let log = OSLog(subsystem: AppDelegate.name, category: "ScrobbleSyncer")
    private let persistentStorage: PersistentStorage
    private let backendApi: BackendApi
    private let activeDispatchGroup = DispatchGroup()
    private let uploadSemaphore = DispatchSemaphore(value: 1)
    private var isRunning = false
    private var isActive = false
    
    init(persistentStorage: PersistentStorage, backendApi: BackendApi) {
        self.persistentStorage = persistentStorage
        self.backendApi = backendApi
    }
    
    func start() {
        let library = LibraryStorage(context: persistentStorage.context)
        guard library.uploadableScrobbleEntryCount > 0 else { return }
        isRunning = true
        if !isActive {
            isActive = true
            uploadInBackground()
        }
    }
    
    func stopAndWait() {
        isRunning = false
        activeDispatchGroup.wait()
    }
    
    func scrobble(playedSong: Song) {
        if self.persistentStorage.settings.isOnlineMode, Reachability.isConnectedToNetwork() {
            cacheScrobbleRequest(playedSong: playedSong, isUploaded: true)
            scrobbleToServerAsync(playedSong: playedSong)
            start() // send cached request to server
        } else {
            os_log("Scrobble cache: %s", log: self.log, type: .info, playedSong.displayString)
            cacheScrobbleRequest(playedSong: playedSong, isUploaded: false)
        }
    }
    
    private func uploadInBackground() {
        DispatchQueue.global().async {
            self.activeDispatchGroup.enter()
            os_log("start", log: self.log, type: .info)
            
            while self.isRunning, self.persistentStorage.settings.isOnlineMode, Reachability.isConnectedToNetwork() {
                self.uploadSemaphore.wait()
                self.persistentStorage.persistentContainer.performBackgroundTask() { (context) in
                    defer { self.uploadSemaphore.signal() }
                    let library = LibraryStorage(context: context)
                    let scobbleEntry = library.getFirstUploadableScrobbleEntry()
                    defer { scobbleEntry?.isUploaded = true; library.saveContext() }
                    guard let entry = scobbleEntry, let song = entry.playable?.asSong, let date = entry.date else {
                        self.isRunning = false
                        return
                    }
                    let syncer = self.backendApi.createLibrarySyncer()
                    syncer.scrobble(song: song, date: date)
                 }
            }
            
            os_log("stopped", log: self.log, type: .info)
            self.isActive = false
            self.activeDispatchGroup.leave()
        }
    }
    
    private func scrobbleToServerAsync(playedSong: Song) {
        persistentStorage.persistentContainer.performBackgroundTask() { (context) in
            let syncer = self.backendApi.createLibrarySyncer()
            let songMO = try! context.existingObject(with: playedSong.managedObject.objectID) as! SongMO
            let song = Song(managedObject: songMO)
            syncer.scrobble(song: song, date: nil)
        }
    }
    
    private func cacheScrobbleRequest(playedSong: Song, isUploaded: Bool) {
        let library = LibraryStorage(context: persistentStorage.context)
        let scrobbleEntry = library.createScrobbleEntry()
        scrobbleEntry.date = Date()
        scrobbleEntry.playable = playedSong
        scrobbleEntry.isUploaded = isUploaded
        library.saveContext()
    }
    
}
