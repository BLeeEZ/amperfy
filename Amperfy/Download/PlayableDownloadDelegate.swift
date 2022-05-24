import Foundation
import CoreData

class PlayableDownloadDelegate: DownloadManagerDelegate {

    private let backendApi: BackendApi
    private let artworkExtractor: EmbeddedArtworkExtractor

    init(backendApi: BackendApi, artworkExtractor: EmbeddedArtworkExtractor) {
        self.backendApi = backendApi
        self.artworkExtractor = artworkExtractor
    }
    
    var requestPredicate: NSPredicate {
        return DownloadMO.onlyPlayablesPredicate
    }

    func prepareDownload(download: Download, context: NSManagedObjectContext) throws -> URL {
        let playableMO = try context.existingObject(with: download.element.objectID) as! AbstractPlayableMO
        let playable = AbstractPlayable(managedObject: playableMO)
        guard !playable.isCached else {
            throw DownloadError.alreadyDownloaded 
        }
        return try updateDownloadUrl(forPlayable: playable)
    }

    private func updateDownloadUrl(forPlayable playable: AbstractPlayable) throws -> URL {
        guard Reachability.isConnectedToNetwork() else {
            throw DownloadError.noConnectivity
        }
        guard let url = backendApi.generateUrl(forDownloadingPlayable: playable) else {
            throw DownloadError.urlInvalid
        }
        return url
    }
    
    func validateDownloadedData(download: Download) -> ResponseError? {
        guard let data = download.resumeData else {
            return ResponseError(statusCode: 0, message: "Invalid download")
        }
        return backendApi.checkForErrorResponse(inData: data)
    }

    func completedDownload(download: Download, context: NSManagedObjectContext) {
        guard let data = download.resumeData else { return }
		let library = LibraryStorage(context: context)
        if let playableMO = try? context.existingObject(with: download.element.objectID) as? AbstractPlayableMO {
            let playableFile = library.createPlayableFile()
            let owner = AbstractPlayable(managedObject: playableMO)
            playableFile.info = owner
            playableFile.data = data
            artworkExtractor.extractEmbeddedArtwork(library: library, playable: owner, fileData: data)
            library.saveContext()
        }
    }
    
    func failedDownload(download: Download, context: NSManagedObjectContext) {
    }
    
}
