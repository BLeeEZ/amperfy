import Foundation

struct DownloadRequestQueues {
    var waitingRequests = [DownloadRequest<Song>]()
    var activeRequests = [DownloadRequest<Song>]()
    var completedRequests = [DownloadRequest<Song>]()
}

class RequestManager {

    private let queuePushPopSemaphore = DispatchSemaphore(value: 1)
    // song.id : DownloadRequestForThisSongId
    private var requests = Dictionary<String, DownloadRequest<Song>>()
    private var waitingRequests = [DownloadRequest<Song>]()
    private var activeRequests = [DownloadRequest<Song>]()
    private var completedRequests = [DownloadRequest<Song>]()
    
    var requestQueues: DownloadRequestQueues {
        self.queuePushPopSemaphore.wait()
        let queues = DownloadRequestQueues(waitingRequests: waitingRequests, activeRequests: activeRequests, completedRequests: completedRequests)
        self.queuePushPopSemaphore.signal()
        return queues
    }
    
    func add(request: DownloadRequest<Song>, completion: @escaping (_ addedRequest: DownloadRequest<Song>, _ removedRequest: DownloadRequest<Song>?) -> ()) {
        self.queuePushPopSemaphore.wait()
        if request.priority == .low {
            if !isAlreadyInQueue(song: request.element) {
                addLowPrio(request: request)
                completion(request, nil)
            }
        } else {
            addHighPrio(request: request, completion: completion)
        }
        self.queuePushPopSemaphore.signal()
    }
    
    func add(requests: [DownloadRequest<Song>]) {
        self.queuePushPopSemaphore.wait()
        for request in requests {
            if !isAlreadyInQueue(song: request.element) {
                addLowPrio(request: request)
            }
        }
        self.queuePushPopSemaphore.signal()
    }

    private func addLowPrio(request: DownloadRequest<Song>) {
        requests[request.element.id] = request
        waitingRequests.insert(request, at: 0)
    }

    private func addHighPrio(request: DownloadRequest<Song>, completion: (_ addedRequest: DownloadRequest<Song>, _ removedRequest: DownloadRequest<Song>?) -> ()) {
        let sameRequest = requests[request.element.id]
        if sameRequest == nil {
            requests[request.element.id] = request
            waitingRequests.append(request)
            completion(request, nil)
        } else if !hasStartedToDownload(song: request.element) {
            let removedRequest = waitingRequests.lazy.enumerated().filter {
                return $0.element.element == request.element
            }.first
            if let removedRequest = removedRequest {
                waitingRequests.remove(at: removedRequest.offset)
                waitingRequests.append(request)
                completion(request, removedRequest.element)
            } else {
                waitingRequests.append(request)
                completion(request, nil)
            }
        }
    }

    private func isAlreadyInQueue(song: Song) -> Bool {
        return requests[song.id] != nil
    }

    private func hasStartedToDownload(song: Song) -> Bool {
        var isStarted = false
        if let request = requests[song.id] {
            isStarted = request.phase == .activeDownloading || request.phase == .preparedToDownloading
        }
        return isStarted
    }

    func getNextRequestToDownload() -> DownloadRequest<Song>? {
        self.queuePushPopSemaphore.wait()
        let nextRequest = waitingRequests.popLast()
        if let nextRequest = nextRequest {
            activeRequests.append(nextRequest)
        }
        nextRequest?.preparedToDownload()
        self.queuePushPopSemaphore.signal()
        return nextRequest
    }

    func getRequest(by url: URL) -> DownloadRequest<Song>? {
        self.queuePushPopSemaphore.wait()
        let foundRequest = activeRequests.lazy.filter {
            return $0.url == url
        }.first
        self.queuePushPopSemaphore.signal()
        return foundRequest
    }
    
    func informDownloadCompleted(request: DownloadRequest<Song>) {
        self.queuePushPopSemaphore.wait()
        let completedRequest = activeRequests.lazy.enumerated().filter {
            return $0.element.element == request.element
        }.first
        if let completedRequest = completedRequest {
            activeRequests.remove(at: completedRequest.offset)
            completedRequests.append(request)
        }
        self.queuePushPopSemaphore.signal()
    }

    func cancelDownloads() {
        self.queuePushPopSemaphore.wait()
        activeRequests.forEach{ request in
            request.cancelDownload()
        }
        waitingRequests.forEach{ request in
            request.cancelDownload()
        }
        completedRequests.append(contentsOf: activeRequests)
        activeRequests = [DownloadRequest<Song>]()
        completedRequests.append(contentsOf: waitingRequests)
        waitingRequests = [DownloadRequest<Song>]()
        self.queuePushPopSemaphore.signal()
    }

}
