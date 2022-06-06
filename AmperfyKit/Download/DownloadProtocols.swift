import Foundation
import CoreData

public typealias CompleteHandlerBlock = () -> ()

public protocol DownloadManageable {
    var backgroundFetchCompletionHandler: CompleteHandlerBlock? { get set }
    func download(object: Downloadable)
    func download(objects: [Downloadable])
    func removeFinishedDownload(for object: Downloadable)
    func removeFinishedDownload(for objects: [Downloadable])
    func clearFinishedDownloads()
    func resetFailedDownloads()
    func cancelDownloads()
    func start()
    func stopAndWait()
}

public protocol DownloadManagerDelegate {
    var requestPredicate: NSPredicate { get }
    func prepareDownload(download: Download, context: NSManagedObjectContext) throws -> URL
    func validateDownloadedData(download: Download) -> ResponseError?
    func completedDownload(download: Download, context: NSManagedObjectContext)
    func failedDownload(download: Download, context: NSManagedObjectContext)
}

public protocol Downloadable: CustomEquatable {
    var objectID: NSManagedObjectID { get }
    var isCached: Bool { get }
    var displayString: String { get }
}

extension Downloadable {
    public var uniqueID: String { return objectID.uriRepresentation().absoluteString }
}
