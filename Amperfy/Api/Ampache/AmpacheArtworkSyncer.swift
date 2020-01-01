import Foundation
import UIKit
import os.log

class AmpacheArtworkSyncer: GenericLibraryBackgroundSyncer, BackgroundLibrarySyncer {
    
    private let ampacheXmlServerApi: AmpacheXmlServerApi
    private var imageDefaultData: Data?

    init(ampacheXmlServerApi: AmpacheXmlServerApi) {
        self.ampacheXmlServerApi = ampacheXmlServerApi
    }
    
    func syncInBackground(libraryStorage: LibraryStorage) {
        isRunning = true
        semaphoreGroup.enter()
        isActive = true
        
        let defaultArtwork = libraryStorage.createArtwork()
        defaultArtwork.url = ampacheXmlServerApi.defaultArtworkUrl
        imageDefaultData = fetchImageData(artwork: defaultArtwork)
        libraryStorage.deleteArtwork(artwork: defaultArtwork)
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
    
    private func fetchImageData(artwork: Artwork) -> Data? {
        guard let url = ampacheXmlServerApi.generateUrl(forArtwork: artwork) else { return nil }
        do {
            return try Data(contentsOf: url)
        } catch {
            return nil
        }
    }
    
    private func fetchArtwork(artwork: Artwork) {
        guard let imageData = fetchImageData(artwork: artwork) else {
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
            artwork.setImage(fromData: NSData(data: imageData))
        }
    }
}
