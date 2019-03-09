import Foundation

class RequestManager {

    private var requests = SynchronizedArray<DownloadRequest<Song>>()
    var queuedRequests: [DownloadRequest<Song>] {
        return requests.asBaseType.reversed()
    }
    private let queuePushPopSemaphore = DispatchSemaphore(value: 1)
    
    func add(request: DownloadRequest<Song>, completion: (_ addedRequest: DownloadRequest<Song>, _ removedRequest: DownloadRequest<Song>?) -> ()) {
        self.queuePushPopSemaphore.wait()
        if request.priority == .low {
            if !isAlreadyInQueue(song: request.element) {
                addLowPrio(request: request)
                completion(request, nil)
            }
        } else {
            addHighPrioRequestIfNotStartedAndRemoveOtherRequestToSameSong(request: request, completion: completion)
        }
        self.queuePushPopSemaphore.signal()
    }

    private func addLowPrio(request: DownloadRequest<Song>) {
        requests.insert(request, at: 0)
    }

    private func addHighPrioRequestIfNotStartedAndRemoveOtherRequestToSameSong(request: DownloadRequest<Song>, completion: (_ addedRequest: DownloadRequest<Song>, _ removedRequest: DownloadRequest<Song>?) -> ()) {
        let sameRequest = requests.enumerated().filter {
            return $0.element.element == request.element
        }.first
        if sameRequest == nil {
            requests.append(request)
            completion(request, nil)
        } else if !hasStartedToDownload(song: request.element) {
            requests.append(request)
            if let removedRequest = sameRequest {
                requests.remove(at: removedRequest.offset)
                completion(request, removedRequest.element)
            } else {
                completion(request, nil)
            }
        }
    }

    func isAlreadyInQueue(song: Song) -> Bool {
        var isInQueue = false
        requests.forEach { request in
            if request.element == song {
                isInQueue = true
                return
            }
        }
        return isInQueue
    }

    func hasStartedToDownload(song: Song) -> Bool {
        return !requests.filter {
            return ($0.element == song) && ($0.download != nil)
        }.isEmpty
    }

    func getAndMarkNextRequestToDownload() -> DownloadRequest<Song>? {
        self.queuePushPopSemaphore.wait()
        let nextRequest = requests.filter {
            return $0.markedToStart == false
        }.last
        nextRequest?.markedToStart = true
        self.queuePushPopSemaphore.signal()
        return nextRequest
    }

    func getRequest(by url: URL) -> DownloadRequest<Song>? {
        return requests.filter {
            return $0.url == url
        }.first
    }

    func cancelDownloads() {
        requests.forEach{ request in
            request.cancelDownload()
        }
    }

}
