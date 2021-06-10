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

enum DownloadRequestQueueAddResult {
    case notSet
    case added
    case notifierAppendedToExistingRequest
    case alreadyfinished
    case queuePlaceChanged
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
    var url: URL?
    var download: Download?
    var queueAddResult = DownloadRequestQueueAddResult.notSet
    private(set) var notifiers = [DownloadNotifiable]()
    private(set) var phase = DownloadPhase.waitingToStart
    private let finishSync = DispatchGroup()
    private var queue = DispatchQueue(label: "DownloadRequest")
    
    init(priority: Priority, element: Downloadable, title: String, notifier: DownloadNotifiable?) {
        self.priority = priority
        self.title = title
        self.element = element
        if let notifier = notifier { self.notifiers.append(notifier) }
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
    
    func addNotifiers(notifiers: [DownloadNotifiable]) {
        self.notifiers.append(contentsOf: notifiers)
    }
    
    func notifyDownloadFinishedInMainQueue() {
        DispatchQueue.main.async {
            self.notifiers.forEach{ $0.finished(downloading: self.element, error: self.download?.error) }
        }
    }
    
}
