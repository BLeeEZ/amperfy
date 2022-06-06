import Foundation
import os.log

public class DuplicateEntitiesResolver {
    
    private let log = OSLog(subsystem: "Amperfy", category: "DuplicateEntitiesResolver")
    private let persistentStorage: PersistentStorage
    private let activeDispatchGroup = DispatchGroup()
    private let mainFlowSemaphore = DispatchSemaphore(value: 1)
    private var isRunning = false
    private var isActive = false
    
    init(persistentStorage: PersistentStorage) {
        self.persistentStorage = persistentStorage
    }
    
    public func start() {
        isRunning = true
        if !isActive {
            isActive = true
            resolveDuplicatesInBackground()
        }
    }
    
    public func stopAndWait() {
        isRunning = false
        activeDispatchGroup.wait()
    }
    
    private func resolveDuplicatesInBackground() {
        DispatchQueue.global().async {
            self.activeDispatchGroup.enter()
            os_log("start", log: self.log, type: .info)
            
            if self.isRunning {
                self.mainFlowSemaphore.wait()
                self.persistentStorage.persistentContainer.performBackgroundTask() { (context) in
                    defer { self.mainFlowSemaphore.signal() }
                    let library = LibraryStorage(context: context)
                    let duplicates = library.findDuplicates(for: Genre.typeName)
                    library.resolveGenresDuplicates(duplicates: duplicates)
                    library.saveContext()
                 }
            }
            
            if self.isRunning {
                self.mainFlowSemaphore.wait()
                self.persistentStorage.persistentContainer.performBackgroundTask() { (context) in
                    defer { self.mainFlowSemaphore.signal() }
                    let library = LibraryStorage(context: context)
                    let duplicates = library.findDuplicates(for: Artist.typeName)
                    library.resolveArtistsDuplicates(duplicates: duplicates)
                    library.saveContext()
                 }
            }
            
            if self.isRunning {
                self.mainFlowSemaphore.wait()
                self.persistentStorage.persistentContainer.performBackgroundTask() { (context) in
                    defer { self.mainFlowSemaphore.signal() }
                    let library = LibraryStorage(context: context)
                    let duplicates = library.findDuplicates(for: Album.typeName)
                    library.resolveAlbumsDuplicates(duplicates: duplicates)
                    library.saveContext()
                 }
            }
            
            if self.isRunning {
                self.mainFlowSemaphore.wait()
                self.persistentStorage.persistentContainer.performBackgroundTask() { (context) in
                    defer { self.mainFlowSemaphore.signal() }
                    let library = LibraryStorage(context: context)
                    let duplicates = library.findDuplicates(for: Song.typeName)
                    library.resolveSongsDuplicates(duplicates: duplicates)
                    library.saveContext()
                 }
            }
            
            if self.isRunning {
                self.mainFlowSemaphore.wait()
                self.persistentStorage.persistentContainer.performBackgroundTask() { (context) in
                    defer { self.mainFlowSemaphore.signal() }
                    let library = LibraryStorage(context: context)
                    let duplicates = library.findDuplicates(for: PodcastEpisode.typeName)
                    library.resolvePodcastEpisodesDuplicates(duplicates: duplicates)
                    library.saveContext()
                 }
            }
            
            if self.isRunning {
                self.mainFlowSemaphore.wait()
                self.persistentStorage.persistentContainer.performBackgroundTask() { (context) in
                    defer { self.mainFlowSemaphore.signal() }
                    let library = LibraryStorage(context: context)
                    let duplicates = library.findDuplicates(for: Podcast.typeName)
                    library.resolvePodcastsDuplicates(duplicates: duplicates)
                    library.saveContext()
                 }
            }
            
            if self.isRunning {
                self.mainFlowSemaphore.wait()
                self.persistentStorage.persistentContainer.performBackgroundTask() { (context) in
                    defer { self.mainFlowSemaphore.signal() }
                    let library = LibraryStorage(context: context)
                    let duplicates = library.findDuplicates(for: Playlist.typeName).filter{ $0.id != "" }
                    library.resolvePlaylistsDuplicates(duplicates: duplicates)
                    library.saveContext()
                 }
            }
            
            os_log("stopped", log: self.log, type: .info)
            self.isActive = false
            self.activeDispatchGroup.leave()
        }
    }
    
}
