import Foundation
import CoreData

protocol DownloadManageable {
    func download(object: Downloadable)
    func download(objects: [Downloadable])
    func clearFinishedDownloads()
    func cancelDownloads()
    func start()
    func stopAndWait()
}

protocol DownloadManagerDelegate {
    var requestPredicate: NSPredicate { get }
    func prepareDownload(download: Download, context: NSManagedObjectContext) throws -> URL
    func validateDownloadedData(download: Download) -> ResponseError?
    func completedDownload(download: Download, context: NSManagedObjectContext)
}

protocol Downloadable: CustomEquatable {
    var objectID: NSManagedObjectID { get }
    var isCached: Bool { get }
    var displayString: String { get }
}

extension Downloadable {
    var uniqueID: String { return objectID.uriRepresentation().absoluteString }
}
