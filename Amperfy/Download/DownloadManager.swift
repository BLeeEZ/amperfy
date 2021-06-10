import Foundation
import CoreData
import os.log

enum DownloadError: Error {
    case urlInvalid
    case noConnectivity
    case alreadyDownloaded
    case fetchFailed
    case emptyFile
    case apiErrorResponse
    
    var description : String {
        switch self {
        case .urlInvalid: return "Invalid URL"
        case .noConnectivity: return "No Connectivity"
        case .alreadyDownloaded: return "Already Downloaded"
        case .fetchFailed: return "Fetch Failed"
        case .emptyFile: return "File is empty"
        case .apiErrorResponse: return "API Error"
        }
    }
}

protocol DownloadManageable {
    func download(object: Downloadable, notifier: DownloadNotifiable?, priority: Priority)
}

protocol DownloadNotifiable {
    func finished(downloading: Downloadable, error: DownloadError?)
}

protocol DownloadViewUpdatable {
    func downloadManager(_: DownloadManager, updatedRequest: DownloadRequest, updateReason: DownloadRequestEvent)
}

protocol DownloadManagerDelegate {
    func prepareDownload(forRequest request: DownloadRequest, context: NSManagedObjectContext) throws -> URL
    func validateDownloadedData(request: DownloadRequest) -> ResponseError?
    func completedDownload(request: DownloadRequest, context: NSManagedObjectContext)
}

class DownloadManager: DownloadManageable {
    
    private let log = OSLog(subsystem: AppDelegate.name, category: "DownloadManager")
    private let storage: PersistentStorage
    private let requestManager: RequestManager
    private let urlDownloader: UrlDownloader
    private let downloadDelegate: DownloadManagerDelegate
    private let eventLogger: EventLogger
    

    private let downloadSlotCounter = DownloadSlotCounter(maximumActiveDownloads: 4)
    private let activeDispatchGroup = DispatchGroup()
    private var isRunning = false
    private var isActive = false
    private var viewNotifiers = [DownloadViewUpdatable]()
    
    var requestQueues: DownloadRequestQueues {
        return requestManager.requestQueues
    }
    
    init(storage: PersistentStorage, requestManager: RequestManager, urlDownloader: UrlDownloader, downloadDelegate: DownloadManagerDelegate, eventLogger: EventLogger) {
        self.storage = storage
        self.requestManager = requestManager
        self.urlDownloader = urlDownloader
        self.downloadDelegate = downloadDelegate
        self.eventLogger = eventLogger
    }
    
    func download(object: Downloadable, notifier: DownloadNotifiable? = nil, priority: Priority = .low) {
        guard !object.isCached else { return }
        let newRequest = DownloadRequest(priority: priority, element: object, title: object.displayString, notifier: notifier)
        self.requestManager.add(request: newRequest)
        notifyRequestQueueAddResult(request: newRequest)
    }
    
    func download(objects: [Downloadable]) {
        var requests = [DownloadRequest]()
        for object in objects {
            guard !object.isCached else { continue }
            requests.append(DownloadRequest(priority: .low, element: object, title: object.displayString, notifier: nil))
        }
        if requests.count > 0 {
            self.requestManager.add(requests: requests)
            for request in requests {
                notifyRequestQueueAddResult(request: request)
            }
        }
    }
    
    func notifyRequestQueueAddResult(request: DownloadRequest) {
        switch request.queueAddResult {
        case .notSet:
            break
        case .added:
            self.notifyViewRequestChange(request, updateReason: .added)
        case .notifierAppendedToExistingRequest:
            break
        case .alreadyfinished:
            request.notifyDownloadFinishedInMainQueue()
        case .queuePlaceChanged:
            self.notifyViewRequestChange(request, updateReason: .removed)
            self.notifyViewRequestChange(request, updateReason: .added)
        }
    }

    func start() {
        isRunning = true
        if !isActive {
            isActive = true
            downloadInBackground()
        }
    }

    private func stop() {
        isRunning = false
        cancelDownloads()
    }

    func stopAndWait() {
        stop()
        activeDispatchGroup.wait()
    }
    
    func cancelDownloads() {
        requestManager.cancelDownloads()
    }
    
    private func downloadInBackground() {
        DispatchQueue.global().async {
            self.activeDispatchGroup.enter()
            os_log("DownloadManager start", log: self.log, type: .info)
            
            while self.isRunning {
                self.downloadSlotCounter.waitForDownloadSlot()
                
                guard let request = self.requestManager.getNextRequestToDownload() else {
                    self.downloadSlotCounter.downloadFinished()
                    // wait some time and poll for new requests
                    sleep(1)
                    continue
                }
                self.notifyViewRequestChange(request, updateReason: .started)

                self.storage.persistentContainer.performBackgroundTask() { (context) in
                    self.manageDownload(request: request, context: context)
                    self.notifyViewRequestChange(request, updateReason: .finished)
                    self.downloadSlotCounter.downloadFinished()
                }
            }
            os_log("DownloadManager wait till all active downloads finished", log: self.log, type: .info)
            self.downloadSlotCounter.waitTillAllDownloadsFinished()
            os_log("DownloadManager stopped", log: self.log, type: .info)
            self.isActive = false
            self.activeDispatchGroup.leave()
        }
    }
    
    private func manageDownload(request: DownloadRequest, context: NSManagedObjectContext) {
        var downloadError: DownloadError?
        do {
            os_log("Fetching %s ...", log: self.log, type: .info, request.title)
            let url = try downloadDelegate.prepareDownload(forRequest: request, context: context)
            try self.urlDownloader.fetch(url: url, request: request)
            if let responseError = downloadDelegate.validateDownloadedData(request: request) {
                os_log("Fetching %s API-ERROR StatusCode: %d, Message: %s", log: log, type: .error, request.title, responseError.statusCode, responseError.message)
                throw DownloadError.apiErrorResponse
            }
            os_log("Fetching %s SUCCESS (%{iec-bytes}d)", log: self.log, type: .info, request.title, request.download?.resumeData?.count ?? 0)
            downloadDelegate.completedDownload(request: request, context: context)
        } catch let fetchError as DownloadError {
            downloadError = fetchError
        } catch {
            downloadError = DownloadError.fetchFailed
        }
        if let error = downloadError, error != .apiErrorResponse {
            os_log("Fetching %s FAILED: %s", log: self.log, type: .info, request.title, error.description)
            eventLogger.error(topic: "Download Error", statusCode: .downloadError, message: "Error \"\(error.description)\" occured while downloading object \"\(request.title)\".")
        }
        // remove data from request to free memory
        request.download?.resumeData = nil
        request.download?.error = downloadError
        self.requestManager.informDownloadCompleted(request: request)
        request.notifyDownloadFinishedInMainQueue()
    }

    func addNotifier(_ notifier: DownloadViewUpdatable) {
        viewNotifiers.append(notifier)
    }  

    func notifyViewRequestChange(_ request: DownloadRequest, updateReason: DownloadRequestEvent) {
        DispatchQueue.main.async {
            for notifier in self.viewNotifiers {
                notifier.downloadManager(self, updatedRequest: request, updateReason: updateReason) 
            }
        }
    }
    
}

extension DownloadManager: UrlDownloadNotifiable {
    
    func notifyDownloadProgressChange(request: DownloadRequest) {
        notifyViewRequestChange(request, updateReason: .updateProgress)
    }
    
}
