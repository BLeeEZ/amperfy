import Foundation
import CoreData
import UIKit

class AmpacheArtworkDownloadDelegate: DownloadManagerDelegate {
    
    private let ampacheXmlServerApi: AmpacheXmlServerApi
    private var defaultImageData: Data?
    private var defaultImageFetchQueue = DispatchQueue(label: "DefaultImageFetchQueue")

    init(ampacheXmlServerApi: AmpacheXmlServerApi) {
        self.ampacheXmlServerApi = ampacheXmlServerApi
    }

    func getDefaultImageData() -> Data {
        if defaultImageData == nil, let url = URL(string: ampacheXmlServerApi.defaultArtworkUrl) {
            defaultImageFetchQueue.sync {
                guard defaultImageData == nil else { return }
                defaultImageData = try? Data(contentsOf: url)
            }
        }
        return defaultImageData ?? Data()
    }

    func prepareDownload(forRequest request: DownloadRequest, context: NSManagedObjectContext) throws -> URL {
        let artworkMO = try context.existingObject(with: request.element.objectID) as! ArtworkMO
        let artwork = Artwork(managedObject: artworkMO)
        guard Reachability.isConnectedToNetwork() else { throw DownloadError.noConnectivity }
        guard let url = ampacheXmlServerApi.generateUrl(forArtwork: artwork) else { throw DownloadError.urlInvalid }
        return url
    }
    
    func validateDownloadedData(request: DownloadRequest) -> ResponseError? {
        guard let download = request.download, let data = download.resumeData else {
            return ResponseError(statusCode: 0, message: "Invalid download")
        }
        return ampacheXmlServerApi.checkForErrorResponse(inData: data)
    }

    func completedDownload(request: DownloadRequest, context: NSManagedObjectContext) {
        guard let download = request.download, let data = download.resumeData else { return }
        let libraryStorage = LibraryStorage(context: context)
        if let artworkMO = try? context.existingObject(with: request.element.objectID) as? ArtworkMO {
            let artwork = Artwork(managedObject: artworkMO)
            if data == getDefaultImageData() {
                artwork.status = .IsDefaultImage
                artwork.setImage(fromData: nil)
            } else {
                artwork.status = .CustomImage
                artwork.setImage(fromData: data)
            }
            libraryStorage.saveContext()
        }
    }
    
}
