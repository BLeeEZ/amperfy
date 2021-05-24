import Foundation
import os.log

protocol UrlDownloadNotifiable {
    func notifyDownloadProgressChange(request: DownloadRequest<Song>)
}

class UrlDownloader: NSObject, URLSessionDownloadDelegate {
    
    private let log = OSLog(subsystem: AppDelegate.name, category: "UrlDownloader")
    let requestManager: RequestManager
    var urlDownloadNotifier: UrlDownloadNotifiable?
    lazy var downloadsSession: URLSession = {
        let configuration = URLSessionConfiguration.default
        return URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
    }()
    
    init(requestManager: RequestManager) {
        self.requestManager = requestManager
    }
    
    func fetch(url: URL, request: DownloadRequest<Song>) throws {
        request.started()
        let download = Download(url: url)
        download.task = downloadsSession.downloadTask(with: url)
        download.isDownloading = true
        request.url = url
        request.download = download
        download.task!.resume()
        request.waitTillFinished()
        
        if let error = download.error {
            throw error
        }
        guard download.resumeData != nil else {
            throw DownloadError.fetchFailed
        }
    }
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        guard let url = downloadTask.originalRequest?.url, let request = requestManager.getRequest(by: url), let download = request.download else { return }
        
        do {
            download.isDownloading = false
            let data = try Data(contentsOf: location)
            if data.count > 0 {
                download.resumeData = data
            } else {
                download.error = .fetchFailed
            }
            
        } catch let error {
            download.error = .fetchFailed
            os_log("Could not get downloaded file from disk: %s", log: log, type: .error, error.localizedDescription)
        }
        request.finished()
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard error != nil, let url = task.originalRequest?.url, let request = requestManager.getRequest(by: url), let download = request.download else { return }
        download.error = .fetchFailed
        request.finished()
    }
    
    func urlSession(_ session: URLSession,
                    downloadTask: URLSessionDownloadTask,
                    didWriteData bytesWritten: Int64, totalBytesWritten: Int64,
                    totalBytesExpectedToWrite: Int64) {
        guard let url = downloadTask.originalRequest?.url, let request = requestManager.getRequest(by: url), let download = request.download else { return }
        download.progress = Float(totalBytesWritten) / Float(totalBytesExpectedToWrite)
        download.totalSize = ByteCountFormatter.string(fromByteCount: totalBytesExpectedToWrite, countStyle: .file)
        urlDownloadNotifier?.notifyDownloadProgressChange(request: request)
    }
    
}
