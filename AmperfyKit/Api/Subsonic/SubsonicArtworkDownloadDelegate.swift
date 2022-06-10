import Foundation
import CoreData
import UIKit
import os.log

class SubsonicArtworkDownloadDelegate: DownloadManagerDelegate {
        
    private let subsonicServerApi: SubsonicServerApi

    init(subsonicServerApi: SubsonicServerApi) {
        self.subsonicServerApi = subsonicServerApi
    }
    
    var requestPredicate: NSPredicate {
        return DownloadMO.onlyArtworksPredicate
    }
    
    var parallelDownloadsCount: Int {
        return 2
    }

    func prepareDownload(download: Download, context: NSManagedObjectContext) throws -> URL {
        guard let downloadElement = download.element else {
            throw DownloadError.fetchFailed
        }
        let artworkMO = try context.existingObject(with: downloadElement.objectID) as! ArtworkMO
        let artwork = Artwork(managedObject: artworkMO)
        guard Reachability.isConnectedToNetwork() else { throw DownloadError.noConnectivity }
        guard let url = subsonicServerApi.generateUrl(forArtwork: artwork) else { throw DownloadError.urlInvalid }
        return url
    }
    
    func validateDownloadedData(download: Download) -> ResponseError? {
        guard let data = download.resumeData else {
            return ResponseError(statusCode: 0, message: "Invalid download")
        }
        return subsonicServerApi.checkForErrorResponse(inData: data)
    }
    
    func completedDownload(download: Download, context: NSManagedObjectContext) {
        guard let data = download.resumeData,
              let downloadElement = download.element,
              let artworkMO = try? context.existingObject(with: downloadElement.objectID) as? ArtworkMO else {
            return
        }
        let library = LibraryStorage(context: context)
        let artwork = Artwork(managedObject: artworkMO)
        artwork.status = .CustomImage
        artwork.setImage(fromData: data)
        library.saveContext()
    }
    
    func failedDownload(download: Download, context: NSManagedObjectContext) {
        guard let downloadElement = download.element,
              let artworkMO = try? context.existingObject(with: downloadElement.objectID) as? ArtworkMO else {
            return
        }
        let artwork = Artwork(managedObject: artworkMO)
        artwork.status = .FetchError
        let library = LibraryStorage(context: context)
        library.saveContext()
    }

}
