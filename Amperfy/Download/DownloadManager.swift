import Foundation
import CoreData
import os.log

enum DownloadError: Error {
    case urlInvalid
    case noConnectivity
    case alreadyDownloaded
    case fetchFailed
}

protocol SongDownloadable {
    func download(song: Song, notifier: SongDownloadNotifiable?, priority: Priority)
}

protocol SongDownloadNotifiable {
    func finished(downloading: Song, error: DownloadError?)
}

protocol SongDownloadViewUpdatable {
    func downloadManager(_: DownloadManager, updatedRequest: DownloadRequest<Song>, updateReason: SongDownloadRequestEvent)
}

protocol DownloadManagerDelegate {
    func prepareDownload(forRequest request: DownloadRequest<Song>, context: NSManagedObjectContext) throws -> URL
    func completedDownload(request: DownloadRequest<Song>, context: NSManagedObjectContext)
}

class DownloadManager: SongDownloadable {
    
    private let log = OSLog(subsystem: AppDelegate.name, category: "DownloadManager")
    private let storage: PersistentStorage
    private let requestManager: RequestManager
    private let urlDownloader: UrlDownloader
    private let downloadDelegate: DownloadManagerDelegate
    

    private let downloadSlotCounter = DownloadSlotCounter(maximumActiveDownloads: 4)
    private let activeDispatchGroup = DispatchGroup()
    private var isRunning = false
    private var isActive = false
    private var viewNotifiers = [SongDownloadViewUpdatable]()
    
    var queuedRequests: [DownloadRequest<Song>] {
        return requestManager.queuedRequests
    }
    
    init(storage: PersistentStorage, requestManager: RequestManager, urlDownloader: UrlDownloader, downloadDelegate: DownloadManagerDelegate) {
        self.storage = storage
        self.requestManager = requestManager
        self.urlDownloader = urlDownloader
        self.downloadDelegate = downloadDelegate
    }
    
    func download(song: Song, notifier: SongDownloadNotifiable? = nil, priority: Priority = .low) {
        guard !song.isCached else { return }
        
        let newRequest = DownloadRequest(priority: priority, element: song, title: song.displayString, notifier: notifier)
        requestManager.add(request: newRequest) { addedRequest, removedRequest in
            if let removedRequest = removedRequest {
                self.notifyViewRequestChange(removedRequest, updateReason: .removed)
            }
            self.notifyViewRequestChange(addedRequest, updateReason: .added)
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
        requestManager.cancelDownloads()
    }

    func stopAndWait() {
        stop()
        activeDispatchGroup.wait()
    }
    
    private func downloadInBackground() {
        DispatchQueue.global().async {
            self.activeDispatchGroup.enter()
            os_log("DownloadManager start", log: self.log, type: .info)
            
            while self.isRunning {
                self.downloadSlotCounter.waitForDownloadSlot()
                
                guard let request = self.requestManager.getAndMarkNextRequestToDownload() else {
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
    
    private func manageDownload(request: DownloadRequest<Song>, context: NSManagedObjectContext) {
        var downloadError: DownloadError?
        do {
            os_log("Fetching %s ...", log: self.log, type: .info, request.title)
            let url = try downloadDelegate.prepareDownload(forRequest: request, context: context)
            try self.urlDownloader.fetch(url: url, request: request)
            os_log("Fetching %s SUCCESS (%{iec-bytes}d)", log: self.log, type: .info, request.title, request.download?.resumeData?.count ?? 0)
            downloadDelegate.completedDownload(request: request, context: context)
        } catch let fetchError as DownloadError {
            os_log("Fetching %s FAILED", log: self.log, type: .info, request.title)
            downloadError = fetchError
        } catch {
            os_log("Fetching %s FAILED", log: self.log, type: .info, request.title)
            downloadError = DownloadError.fetchFailed
        }
        DispatchQueue.main.async {
            request.notifier?.finished(downloading: request.element, error: downloadError)
        }
    }

    func addNotifier(_ notifier: SongDownloadViewUpdatable) {
        viewNotifiers.append(notifier)
    }  

    func notifyViewRequestChange(_ request: DownloadRequest<Song>, updateReason: SongDownloadRequestEvent) {
        DispatchQueue.main.async {
            for notifier in self.viewNotifiers {
                notifier.downloadManager(self, updatedRequest: request, updateReason: updateReason) 
            }
        }
    }
    
}

extension DownloadManager: UrlDownloadNotifiable {
    
    func notifyDownloadProgressChange(request: DownloadRequest<Song>) {
        notifyViewRequestChange(request, updateReason: .updateProgress)
    }
    
}
