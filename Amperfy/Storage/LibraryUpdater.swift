import Foundation
import os.log

class LibraryUpdater {
    
    private let log = OSLog(subsystem: AppDelegate.name, category: "BackgroundSyncer")
    private let persistentStorage : PersistentStorage
    private let backendApi: BackendApi

    init(persistentStorage: PersistentStorage, backendApi: BackendApi) {
        self.persistentStorage = persistentStorage
        self.backendApi = backendApi
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
    
}
