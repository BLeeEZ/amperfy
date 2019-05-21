import Foundation
import CoreData

class DownloadDelegate: DownloadManagerDelegate {

    private let backendApi: BackendApi

    init(backendApi: BackendApi) {
        self.backendApi = backendApi
    }

    func prepareDownload(forRequest request: DownloadRequest<Song>, context: NSManagedObjectContext) throws -> URL {
        let song = try context.existingObject(with: request.element.objectID) as! Song
        guard song.data == nil else { 
            throw DownloadError.alreadyDownloaded 
        }
        return try updateDownloadUrl(forSong: song)
    }

    private func updateDownloadUrl(forSong song: Song) throws -> URL {
        guard Reachability.isConnectedToNetwork() else {
            throw DownloadError.noConnectivity
        }
        guard let url = backendApi.generateUrl(forSong: song) else {
            throw DownloadError.urlInvalid
        }
        return url
    }

    func completedDownload(request: DownloadRequest<Song>, context: NSManagedObjectContext) {
        guard let download = request.download, let data = download.resumeData else { return }
		let libraryStorage = LibraryStorage(context: context)
        if let song = try? context.existingObject(with: request.element.objectID) as? Song {
            song.dataMO = libraryStorage.createSongData()
            song.dataMO?.id = song.id
            song.dataMO?.data = NSData(data: data)
            libraryStorage.saveContext()
        }
    }

}
