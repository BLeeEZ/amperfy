import Foundation
import CoreData
import UIKit
import os.log

class SubsonicArtworkDownloadDelegate: DownloadManagerDelegate {
        
    private let subsonicServerApi: SubsonicServerApi

    init(subsonicServerApi: SubsonicServerApi) {
        self.subsonicServerApi = subsonicServerApi
    }

    func prepareDownload(forRequest request: DownloadRequest, context: NSManagedObjectContext) throws -> URL {
        let artworkMO = try context.existingObject(with: request.element.objectID) as! ArtworkMO
        let artwork = Artwork(managedObject: artworkMO)
        guard Reachability.isConnectedToNetwork() else { throw DownloadError.noConnectivity }
        guard let url = subsonicServerApi.generateUrl(forArtwork: artwork) else { throw DownloadError.urlInvalid }
        return url
    }
    
    func validateDownloadedData(request: DownloadRequest) -> ResponseError? {
        guard let download = request.download, download.resumeData != nil else {
            return ResponseError(statusCode: 0, message: "Invalid download")
        }
        return nil
    }
    
    func completedDownload(request: DownloadRequest, context: NSManagedObjectContext) {
        guard let download = request.download, let data = download.resumeData else { return }
        let libraryStorage = LibraryStorage(context: context)
        if let artworkMO = try? context.existingObject(with: request.element.objectID) as? ArtworkMO {
            let artwork = Artwork(managedObject: artworkMO)
            artwork.status = .CustomImage
            artwork.setImage(fromData: data)
            libraryStorage.saveContext()
        }
    }

}
