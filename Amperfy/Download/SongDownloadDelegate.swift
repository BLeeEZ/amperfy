import Foundation
import CoreData

class SongDownloadDelegate: DownloadManagerDelegate {

    private let backendApi: BackendApi

    init(backendApi: BackendApi) {
        self.backendApi = backendApi
    }

    func prepareDownload(forRequest request: DownloadRequest, context: NSManagedObjectContext) throws -> URL {
        let songMO = try context.existingObject(with: request.element.objectID) as! SongMO
        let song = Song(managedObject: songMO)
        guard !song.isCached else {
            throw DownloadError.alreadyDownloaded 
        }
        return try updateDownloadUrl(forSong: song)
    }

    private func updateDownloadUrl(forSong song: Downloadable) throws -> URL {
        guard Reachability.isConnectedToNetwork() else {
            throw DownloadError.noConnectivity
        }
        guard let url = backendApi.generateUrl(forDownloadingSong: song as! Song) else {
            throw DownloadError.urlInvalid
        }
        return url
    }
    
    func validateDownloadedData(request: DownloadRequest) -> ResponseError? {
        guard let download = request.download, let data = download.resumeData else {
            return ResponseError(statusCode: 0, message: "Invalid download")
        }
        return backendApi.checkForErrorResponse(inData: data)
    }

    func completedDownload(request: DownloadRequest, context: NSManagedObjectContext) {
        guard let download = request.download, let data = download.resumeData else { return }
		let library = LibraryStorage(context: context)
        if let songMO = try? context.existingObject(with: request.element.objectID) as? SongMO {
            let songFile = library.createSongFile()
            songFile.info = Song(managedObject: songMO)
            songFile.data = data
            library.saveContext()
        }
    }

}
