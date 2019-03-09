import Foundation
import CoreData

class DownloadDelegate: DownloadManagerDelegate {

    private let ampacheApi: AmpacheApi

    init(ampacheApi: AmpacheApi) {
        self.ampacheApi = ampacheApi
    }

    func prepareDownload(forRequest request: DownloadRequest<Song>, context: NSManagedObjectContext) throws -> URL {
        let song = try context.existingObject(with: request.element.objectID) as! Song
        guard song.data == nil else { 
            throw DownloadError.alreadyDownloaded 
        }
        return try updateDownloadUrl(forSong: song)
    }

    private func updateDownloadUrl(forSong song: Song) throws -> URL {
        guard var urlString = song.url else {
            throw DownloadError.urlInvalid
        }
        
        guard Reachability.isConnectedToNetwork() else {
            throw DownloadError.noConnectivity
        }
        
        ampacheApi.updateUrlToken(url: &urlString)
        guard let url = URL(string: urlString) else {
            throw DownloadError.urlInvalid
        }
        return url
    }

    func completedDownload(request: DownloadRequest<Song>, context: NSManagedObjectContext) {
        guard let download = request.download, let data = download.resumeData else { return }
		let libraryStorage = LibraryStorage(context: context)
        if let song = try? context.existingObject(with: request.element.objectID) as! Song {
            song.dataMO = libraryStorage.createSongData()
            song.dataMO?.id = song.id
            song.dataMO?.data = NSData(data: data)
            libraryStorage.saveContext()
        }
    }

}
