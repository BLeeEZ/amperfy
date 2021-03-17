import Foundation

enum SongDownloadRequestEvent {
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

class DownloadRequest<Element: NSObject>: Equatable {
    
    let priority: Priority
    let title: String
    let element: Element
    let notifier: SongDownloadNotifiable?
    var markedToStart = false
    var url: URL?
    var download: Download?
    private let finishSync = DispatchGroup()
    private var isFinished = false
    private var queue = DispatchQueue(label: "DownloadRequest")
    
    init(priority: Priority, element: Element, title: String, notifier: SongDownloadNotifiable?) {
        self.priority = priority
        self.title = title
        self.element = element
        self.notifier = notifier
    }
    
    static func == (lhs: DownloadRequest, rhs: DownloadRequest) -> Bool {
        return (lhs.element == rhs.element)
    }
    
    func started() {
        finishSync.enter()
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
            if !isFinished {
                isFinished = true
                finishSync.leave()
            }
        }
    }
    
}
