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
    
    func add(request: DownloadRequest, completion: @escaping (_ addedRequest: DownloadRequest, _ removedRequest: DownloadRequest?) -> ()) {
        self.queuePushPopSemaphore.wait()
        if request.priority == .low {
            if !isAlreadyInQueue(object: request.element) {
                addLowPrio(request: request)
                completion(request, nil)
            }
        } else {
            addHighPrio(request: request, completion: completion)
        }
        self.queuePushPopSemaphore.signal()
    }
    
    func add(requests: [DownloadRequest]) {
        self.queuePushPopSemaphore.wait()
        for request in requests {
            if !isAlreadyInQueue(object: request.element) {
                addLowPrio(request: request)
            }
        }
        self.queuePushPopSemaphore.signal()
    }

    private func addLowPrio(request: DownloadRequest) {
        requests[request.element.uniqueID] = request
        waitingRequests.insert(request, at: 0)
    }

    private func addHighPrio(request: DownloadRequest, completion: (_ addedRequest: DownloadRequest, _ removedRequest: DownloadRequest?) -> ()) {
        let sameRequest = requests[request.element.uniqueID]
        if sameRequest == nil {
            requests[request.element.uniqueID] = request
            waitingRequests.append(request)
            completion(request, nil)
        } else if !hasStartedToDownload(object: request.element) {
            let removedRequest = waitingRequests.lazy.enumerated().filter {
                return $0.element.element.isEqualTo(request.element)
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

    private func isAlreadyInQueue(object: Downloadable) -> Bool {
        return requests[object.uniqueID] != nil
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
