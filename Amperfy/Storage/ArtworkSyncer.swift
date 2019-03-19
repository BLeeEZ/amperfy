import Foundation
import UIKit
import os.log

class ArtworkSyncer {
    
    private let log = OSLog(subsystem: AppDelegate.name, category: "artworkSyncer")
    private let backendApi: BackendApi
    private let semaphoreGroup = DispatchGroup()
    private var imageDefaultData: Data?
    private var isRunning = false
    public private(set) var isActive = false
    
    init(backendApi: BackendApi) {
        self.backendApi = backendApi
    }
    
    func stop() {
        isRunning = false
    }
    
    func stopAndWait() {
        stop()
        semaphoreGroup.wait()
    }
    
    func syncInBackground(libraryStorage: LibraryStorage) {
        isRunning = true
        semaphoreGroup.enter()
        isActive = true
        imageDefaultData = fetchImageData(urlString: backendApi.defaultArtworkUrl)
        guard imageDefaultData != nil else {
            os_log("Failed to fetch default image", log: log, type: .error)
            isActive = false
            semaphoreGroup.leave()
            return
        }
        while isRunning {
            let arts = libraryStorage.getArtworksThatAreNotChecked(fetchCount: 10)
            guard !arts.isEmpty else {
                os_log("All artworks are synced", log: log, type: .error)
                break
            }
            
            for art in arts {
                if !isRunning { break }
                fetchArtwork(artwork: art)
            }
        }
        libraryStorage.saveContext()
        isActive = false
        semaphoreGroup.leave()
    }
    
    private func fetchImageData(urlString: String) -> Data? {
        var updatedUrl = urlString
        backendApi.updateUrlToken(url: &updatedUrl)
        return Data.fetch(fromUrlString: updatedUrl)
    }
    
    private func fetchArtwork(artwork: Artwork) {
        guard let imageData = fetchImageData(urlString: artwork.url) else {
            os_log("Not able to fetch img", log: log, type: .error)
            artwork.status = .FetchError
            return
        }
        guard let defaultImageData = imageDefaultData else {
            os_log("No default image available", log: log, type: .error)
            return
        }

        if imageData == defaultImageData {
            artwork.status = .IsDefaultImage
        } else {
            artwork.status = .CustomImage
            artwork.imageData = NSData(data: imageData)
        }
    }
}
