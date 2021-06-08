import Foundation
import CoreData

enum DownloadRequestEvent {
    case added
    case removed
    case started
    case updateProgress
    case finished
}

enum Priority {
    case high
    case low
}

enum DownloadPhase {
    case waitingToStart
    case preparedToDownloading
    case activeDownloading
    case finished
}

protocol Downloadable: CustomEquatable {
    var objectID: NSManagedObjectID { get }
    var isCached: Bool { get }
    var displayString: String { get }
}

extension Downloadable {
    var uniqueID: String { return objectID.uriRepresentation().absoluteString }
}

class DownloadRequest: Equatable {
    
    let priority: Priority
    let title: String
    let element: Downloadable
    let notifier: DownloadNotifiable?
    var url: URL?
    var download: Download?
    private(set) var phase = DownloadPhase.waitingToStart
    private let finishSync = DispatchGroup()
    private var queue = DispatchQueue(label: "DownloadRequest")
    
    init(priority: Priority, element: Downloadable, title: String, notifier: DownloadNotifiable?) {
        self.priority = priority
        self.title = title
        self.element = element
        self.notifier = notifier
    }
    
    static func == (lhs: DownloadRequest, rhs: DownloadRequest) -> Bool {
        return lhs.element.isEqualTo(rhs.element)
    }
    
    func started() {
        queue.sync {
            if phase != .finished {
                phase = .activeDownloading
                finishSync.enter()
            }
        }
    }
    
    func preparedToDownload() {
        queue.sync {
            if phase != .finished {
                phase = .preparedToDownloading
            }
        }
    }
    
    func waitTillFinished() {
        finishSync.wait()
    }
    
    func cancelDownload() {
        download?.task?.cancel()
        markAsFinished()
    }
    
    func finished() {
        markAsFinished()
    }
    
    private func markAsFinished() {
        queue.sync {
            if phase == .activeDownloading {
                finishSync.leave()
            }
            phase = .finished
        }
    }
    
}
