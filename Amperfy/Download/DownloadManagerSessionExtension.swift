import Foundation
import CoreData
import os.log

extension DownloadManager: URLSessionDelegate, URLSessionDownloadDelegate {
        
    func fetch(url: URL, download: Download, context: NSManagedObjectContext) {
        let library = LibraryStorage(context: context)
        let task = urlSession.downloadTask(with: url)
        download.url = url
        library.saveContext()
        task.resume()
    }
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        guard let requestUrl = downloadTask.originalRequest?.url?.absoluteString else { return }
        
        var downloadError: DownloadError?
        var downloadedData: Data?
        do {
            let data = try Data(contentsOf: location)
            if data.count > 0 {
                downloadedData = data
            } else {
                downloadError = .emptyFile
            }
        } catch let error {
            downloadError = .fetchFailed
            os_log("Could not get downloaded file from disk: %s", log: self.log, type: .error, error.localizedDescription)
        }
        
        self.persistentStorage.context.performAndWait {
            let library = LibraryStorage(context: self.persistentStorage.context)
            guard let download = library.getDownload(url: requestUrl) else { return }
            if let activeError = downloadError {
                self.finishDownload(download: download, context: self.persistentStorage.context, error: activeError)
            } else if let data = downloadedData {
                self.finishDownload(download: download, context: self.persistentStorage.context, data: data)
            } else {
                self.finishDownload(download: download, context: self.persistentStorage.context, error: .emptyFile)
            }
        }
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard error != nil, let requestUrl = task.originalRequest?.url?.absoluteString else { return }
        self.persistentStorage.context.performAndWait {
            let library = LibraryStorage(context: self.persistentStorage.context)
            guard let download = library.getDownload(url: requestUrl) else { return }
            self.finishDownload(download: download, context: self.persistentStorage.context, error: .fetchFailed)
        }
    }
    
    func urlSession(_ session: URLSession,
                    downloadTask: URLSessionDownloadTask,
                    didWriteData bytesWritten: Int64, totalBytesWritten: Int64,
                    totalBytesExpectedToWrite: Int64) {
        guard let requestUrl = downloadTask.originalRequest?.url?.absoluteString else { return }
        
        self.persistentStorage.context.performAndWait {
            let library = LibraryStorage(context: self.persistentStorage.context)
            guard let download = library.getDownload(url: requestUrl) else { return }
            download.progress = Float(totalBytesWritten) / Float(totalBytesExpectedToWrite)
            download.totalSize = ByteCountFormatter.string(fromByteCount: totalBytesExpectedToWrite, countStyle: .file)
            library.saveContext()
        }
    }
    
    func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        os_log("URLSession urlSessionDidFinishEvents", log: self.log, type: .info)
        if let completionHandler = backgroundFetchCompletionHandler {
            os_log("Calling application backgroundFetchCompletionHandler", log: self.log, type: .info)
            completionHandler()
            backgroundFetchCompletionHandler = nil
        }
    }
    
}
