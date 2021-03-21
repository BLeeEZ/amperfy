import Foundation
import CoreData

class DownloadDelegate: DownloadManagerDelegate {

    private let backendApi: BackendApi

    init(backendApi: BackendApi) {
        self.backendApi = backendApi
    }

    func prepareDownload(forRequest request: DownloadRequest<Song>, context: NSManagedObjectContext) throws -> URL {
        let songMO = try context.existingObject(with: request.element.objectID) as! SongMO
        let song = Song(managedObject: songMO)
        guard !song.isCached else {
            throw DownloadError.alreadyDownloaded 
        }
        return try updateDownloadUrl(forSong: song)
    }
    
    func updateStreamingUrl(forSong song: Song) -> URL? {
        return backendApi.generateUrl(forStreamingSong: song)
    }

    private func updateDownloadUrl(forSong song: Song) throws -> URL {
        guard Reachability.isConnectedToNetwork() else {
            throw DownloadError.noConnectivity
        }
        guard let url = backendApi.generateUrl(forDownloadingSong: song) else {
            throw DownloadError.urlInvalid
        }
        return url
    }
    
    func validateDownloadedData(request: DownloadRequest<Song>) -> ResponseError? {
        guard let download = request.download, let data = download.resumeData else {
            return ResponseError(statusCode: 0, message: "Invalid download")
        }
        return backendApi.checkForErrorResponse(inData: data)
    }

    func completedDownload(request: DownloadRequest<Song>, context: NSManagedObjectContext) {
        guard let download = request.download, let data = download.resumeData else { return }
		let libraryStorage = LibraryStorage(context: context)
        if let songMO = try? context.existingObject(with: request.element.objectID) as? SongMO {
            let songFile = libraryStorage.createSongFile()
            songFile.info = Song(managedObject: songMO)
            songFile.data = data
            libraryStorage.saveContext()
        }
    }

}
