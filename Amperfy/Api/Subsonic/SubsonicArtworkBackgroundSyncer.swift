import Foundation
import UIKit
import os.log

class SubsonicArtworkBackgroundSyncer: GenericLibraryBackgroundSyncer, BackgroundLibrarySyncer {
    
    private let subsonicServerApi: SubsonicServerApi
    private var imageDefaultData: Data?

    init(subsonicServerApi: SubsonicServerApi) {
        self.subsonicServerApi = subsonicServerApi
    }
    
    func syncInBackground(libraryStorage: LibraryStorage) {
        isRunning = true
        semaphoreGroup.enter()
        isActive = true
        
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
    
    private func fetchArtwork(artwork: Artwork) {
        guard let url = subsonicServerApi.generateUrl(forArtwork: artwork) else { return }
        do {
            let imageData = try Data(contentsOf: url)
            if imageData.count != 0 {
                artwork.status = .CustomImage
                artwork.setImage(fromData: imageData)
            } else {
                artwork.status = .IsDefaultImage
            }
        } catch {
            os_log("Not able to fetch img", log: log, type: .error)
            artwork.status = .FetchError
        }
    }

}
