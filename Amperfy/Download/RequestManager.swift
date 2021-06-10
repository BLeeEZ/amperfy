import Foundation

struct DownloadRequestQueues {
    var waitingRequests = [DownloadRequest]()
    var activeRequests = [DownloadRequest]()
    var completedRequests = [DownloadRequest]()
}

class RequestManager {

    private let queuePushPopSemaphore = DispatchSemaphore(value: 1)
    // object.id : DownloadRequestForThisObject
    private var requests = Dictionary<String, DownloadRequest>()
    private var waitingRequests = [DownloadRequest]()
    private var activeRequests = [DownloadRequest]()
    private var completedRequests = [DownloadRequest]()
    
    var requestQueues: DownloadRequestQueues {
        self.queuePushPopSemaphore.wait()
        let queues = DownloadRequestQueues(waitingRequests: waitingRequests, activeRequests: activeRequests, completedRequests: completedRequests)
        self.queuePushPopSemaphore.signal()
        return queues
    }
    
    func add(request: DownloadRequest) {
        self.queuePushPopSemaphore.wait()
        if request.priority == .low {
            addLowPrio(request: request)
        } else {
            addHighPrio(request: request)
        }
        self.queuePushPopSemaphore.signal()
    }
    
    func add(requests: [DownloadRequest]) {
        self.queuePushPopSemaphore.wait()
        for request in requests {
            if request.priority == .low {
                addLowPrio(request: request)
            } else {
                addHighPrio(request: request)
            }
        }
        self.queuePushPopSemaphore.signal()
    }

    private func addLowPrio(request: DownloadRequest) {
        if let existingRequest = self.requests[request.element.uniqueID] {
            if existingRequest.phase == .finished {
                request.download = existingRequest.download
                request.queueAddResult = .alreadyfinished
            } else {
                existingRequest.addNotifiers(notifiers: request.notifiers)
                request.queueAddResult = .notifierAppendedToExistingRequest
            }
        } else {
            requests[request.element.uniqueID] = request
            waitingRequests.insert(request, at: 0)
            request.queueAddResult = .added
        }
    }

    private func addHighPrio(request: DownloadRequest) {
        if let existingRequest = requests[request.element.uniqueID] {
            if let exitingDownloadingRequest = activeRequests.lazy.first(where: { $0.element.isEqualTo(request.element) }) {
                exitingDownloadingRequest.addNotifiers(notifiers: request.notifiers)
                request.queueAddResult = .notifierAppendedToExistingRequest
            } else if existingRequest.phase == .finished {
                request.download = existingRequest.download
                request.queueAddResult = .alreadyfinished
            } else if let waitingRequestIndex = waitingRequests.firstIndex(of: existingRequest) {
                waitingRequests.remove(at: waitingRequestIndex)
                existingRequest.addNotifiers(notifiers: request.notifiers)
                waitingRequests.append(existingRequest)
                request.queueAddResult = .queuePlaceChanged
            } else {
                request.queueAddResult = .notSet
            }
        } else {
            requests[request.element.uniqueID] = request
            waitingRequests.append(request)
            request.queueAddResult = .added
        }
    }

    private func hasStartedToDownload(object: Downloadable) -> Bool {
        var isStarted = false
        if let request = requests[object.uniqueID] {
            isStarted = request.phase == .activeDownloading || request.phase == .preparedToDownloading
        }
        return isStarted
    }

    func getNextRequestToDownload() -> DownloadRequest? {
        self.queuePushPopSemaphore.wait()
        let nextRequest = waitingRequests.popLast()
        if let nextRequest = nextRequest {
            activeRequests.append(nextRequest)
        }
        nextRequest?.preparedToDownload()
        self.queuePushPopSemaphore.signal()
        return nextRequest
    }

    func getRequest(by url: URL) -> DownloadRequest? {
        self.queuePushPopSemaphore.wait()
        let foundRequest = activeRequests.lazy.filter {
            return $0.url == url
        }.first
        self.queuePushPopSemaphore.signal()
        return foundRequest
    }
    
    func informDownloadCompleted(request: DownloadRequest) {
        self.queuePushPopSemaphore.wait()
        let completedRequest = activeRequests.lazy.enumerated().filter {
            return $0.element.element.isEqualTo(request.element)
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
        activeRequests = [DownloadRequest]()
        completedRequests.append(contentsOf: waitingRequests)
        waitingRequests = [DownloadRequest]()
        self.queuePushPopSemaphore.signal()
    }

}
