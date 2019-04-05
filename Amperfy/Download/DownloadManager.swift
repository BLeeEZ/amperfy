import Foundation
import CoreData
import os.log

enum DownloadError: Error {
    case urlInvalid
    case noConnectivity
    case alreadyDownloaded
    case fetchFailed
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

class DownloadManager {
    
    private let log = OSLog(subsystem: AppDelegate.name, category: "DownloadManager")
    private let storage: PersistentStorage
    private let requestManager: RequestManager
    private let urlDownloader: UrlDownloader
    private let downloadDelegate: DownloadManagerDelegate
    
    private static let parallelDownloadCount = 4
    private let parallelDlSemaphore = DispatchSemaphore(value: parallelDownloadCount)
    private let parallelDlDispatchGroup = DispatchGroup()
    private let startStopSemaphore = DispatchSemaphore(value: 1)
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
        start()
    }

    private func start() {
        startStopSemaphore.wait()
        isRunning = true
        if !isActive {
            isActive = true
            downloadInBackground()
        }
        startStopSemaphore.signal()
    }

    func stop() {
        startStopSemaphore.wait()
        isRunning = false
        requestManager.cancelDownloads()
        startStopSemaphore.signal()
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
                
                self.parallelDlSemaphore.wait()
                self.parallelDlDispatchGroup.enter()
                guard let request = self.requestManager.getAndMarkNextRequestToDownload() else {
                    self.parallelDlSemaphore.signal()
                    self.parallelDlDispatchGroup.leave()
                    break
                }
                self.notifyViewRequestChange(request, updateReason: .started)

                self.storage.persistentContainer.performBackgroundTask() { (context) in
                    self.manageDownload(request: request, context: context)
                    self.notifyViewRequestChange(request, updateReason: .finished)
                    self.parallelDlSemaphore.signal()
                    self.parallelDlDispatchGroup.leave()
                }
            }
            self.parallelDlDispatchGroup.wait()
            os_log("DownloadManager done", log: self.log, type: .info)
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
