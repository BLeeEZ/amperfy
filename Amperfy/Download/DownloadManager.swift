import Foundation
import CoreData
import os.log

class DownloadManager: NSObject, DownloadManageable {
    
    let persistentStorage: PersistentStorage
    let requestManager: DownloadRequestManager
    let downloadDelegate: DownloadManagerDelegate
    let notificationHandler: EventNotificationHandler
    var urlSession: URLSession!
    var backgroundFetchCompletionHandler: CompleteHandlerBlock?
    let log: OSLog
    var isFailWithPopupError: Bool = true
    
    
    private let eventLogger: EventLogger
    private let downloadSlotCount = 4
    private let activeDispatchGroup = DispatchGroup()
    private let downloadPreperationSemaphore = DispatchSemaphore(value: 1)
    private var isRunning = false
    private var isActive = false
    
    init(name: String, persistentStorage: PersistentStorage, requestManager: DownloadRequestManager, downloadDelegate: DownloadManagerDelegate, notificationHandler: EventNotificationHandler, eventLogger: EventLogger) {
        log = OSLog(subsystem: AppDelegate.name, category: name)
        self.persistentStorage = persistentStorage
        self.requestManager = requestManager
        self.downloadDelegate = downloadDelegate
        self.notificationHandler = notificationHandler
        self.eventLogger = eventLogger
    }
    
    func download(object: Downloadable) {
        guard !object.isCached, persistentStorage.settings.isOnlineMode else { return }
        self.requestManager.add(object: object)
    }
    
    func download(objects: [Downloadable]) {
        guard persistentStorage.settings.isOnlineMode else { return }
        let downloadObjects = objects.filter{ !$0.isCached }
        if !downloadObjects.isEmpty {
            self.requestManager.add(objects: downloadObjects)
        }
    }
    
    func removeFinishedDownload(for object: Downloadable) {
        requestManager.removeFinishedDownload(for: object)
    }
    
    func removeFinishedDownload(for objects: [Downloadable]) {
        requestManager.removeFinishedDownload(for: objects)
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
        let sync = DispatchGroup()
        sync.enter()
        requestManager.cancelDownloads()
        urlSession.getAllTasks { tasks in
            tasks.forEach{ $0.cancel() }
            sync.leave()
        }
        sync.wait()
    }
    
    func clearFinishedDownloads() {
        requestManager.clearFinishedDownloads()
    }
    
    func resetFailedDownloads() {
        requestManager.resetFailedDownloads()
    }
    
    func isDownloadSlotAvailable() -> Bool {
        var isAvailable = false
        let sync = DispatchGroup()
        sync.enter()
        self.urlSession.getAllTasks { tasks in
            isAvailable = tasks.count < self.downloadSlotCount
            sync.leave()
        }
        sync.wait()
        return isAvailable
    }
    
    private func downloadInBackground() {
        DispatchQueue.global().async {
            self.activeDispatchGroup.enter()
            os_log("DownloadManager start", log: self.log, type: .info)
            
            while self.isRunning {
                self.downloadPreperationSemaphore.wait()
                guard self.isDownloadSlotAvailable(),
                      let nextDownload = self.requestManager.getNextRequestToDownload()
                else {
                    // wait some time, check if a download slot is available and poll for new requests
                    sleep(1)
                    self.downloadPreperationSemaphore.signal()
                    continue
                }

                self.persistentStorage.persistentContainer.performBackgroundTask() { (context) in
                    let download = Download(managedObject: context.object(with: nextDownload.managedObject.objectID) as! DownloadMO)
                    self.manageDownload(download: download, context: context)
                    self.downloadPreperationSemaphore.signal()
                }
            }
            os_log("DownloadManager stopped", log: self.log, type: .info)
            self.isActive = false
            self.activeDispatchGroup.leave()
        }
    }
    
    private func manageDownload(download: Download, context: NSManagedObjectContext) {
        do {
            os_log("Fetching %s ...", log: self.log, type: .info, download.title)
            let url = try downloadDelegate.prepareDownload(download: download, context: context)
            fetch(url: url, download: download, context: context)
        } catch let fetchError as DownloadError {
            finishDownload(download: download, context: context, error: fetchError)
        } catch {
            finishDownload(download: download, context: context, error: .fetchFailed)
        }
    }
    
    func finishDownload(download: Download, context: NSManagedObjectContext, error: DownloadError) {
        let library = LibraryStorage(context: context)
        
        if !download.isCanceled {
            download.error = error
            if error != .apiErrorResponse {
                os_log("Fetching %s FAILED: %s", log: self.log, type: .info, download.title, error.description)
                eventLogger.error(topic: "Download Error", statusCode: .downloadError, message: "Error \"\(error.description)\" occured while downloading object \"\(download.title)\".", displayPopup: isFailWithPopupError)
            }
        }
        download.isDownloading = false
        library.saveContext()
    }
    
    func finishDownload(download: Download, context: NSManagedObjectContext, data: Data) {
        let library = LibraryStorage(context: context)
        download.resumeData = data
        if let responseError = downloadDelegate.validateDownloadedData(download: download) {
            os_log("Fetching %s API-ERROR StatusCode: %d, Message: %s", log: log, type: .error, download.title, responseError.statusCode, responseError.message)
            eventLogger.report(error: responseError, displayPopup: isFailWithPopupError)
            finishDownload(download: download, context: context, error: .apiErrorResponse)
            return
        }
        os_log("Fetching %s SUCCESS (%{iec-bytes}d)", log: self.log, type: .info, download.title, data.count)
        downloadDelegate.completedDownload(download: download, context: context)
        download.resumeData = nil
        download.isDownloading = false
        library.saveContext()
        notificationHandler.post(name: .downloadFinishedSuccess, object: self, userInfo: DownloadNotification(id: download.element.uniqueID).asNotificationUserInfo)
    }
    
}
