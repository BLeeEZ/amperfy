//
//  DownloadManagerSessionExtension.swift
//  AmperfyKit
//
//  Created by Maximilian Bauer on 21.07.21.
//  Copyright (c) 2021 Maximilian Bauer. All rights reserved.
//
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program.  If not, see <http://www.gnu.org/licenses/>.
//

import Foundation
import CoreData
import os.log

extension DownloadManager: URLSessionDelegate, URLSessionDownloadDelegate {
        
    func fetch(url: URL) {
        let task = urlSession.downloadTask(with: url)
        task.resume()
    }
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        guard let requestUrl = downloadTask.originalRequest?.url?.absoluteString else { return }
        var filePath: URL?
        do {
            filePath = try fileManager.moveItemToTempDirectoryWithUniqueName(at: location)
        } catch {
            os_log("Could not move download to tmp directory", log: self.log, type: .error)
        }
        guard let filePath = filePath else { return }
        // didFinishDownloadingTo location
        // A file URL for the temporary file. Because the file is temporary, you must either open the file for
        // reading or move it to a permanent location in your app’s sandbox container directory before returning from this delegate method.
        // If you choose to open the file for reading, you should do the actual reading in another thread to avoid blocking the delegate queue.
        DispatchQueue.global().async {
            var downloadError: DownloadError?
            var downloadedData: Data?
            do {
                let data = try Data(contentsOf: filePath)
                if data.count > 0 {
                    downloadedData = data
                } else {
                    downloadError = .emptyFile
                }
            } catch let error {
                downloadError = .fetchFailed
                os_log("Could not get downloaded file from disk: %s", log: self.log, type: .error, error.localizedDescription)
            }
            
            self.storage.main.context.performAndWait {
                let library = LibraryStorage(context: self.storage.main.context)
                guard let download = library.getDownload(url: requestUrl) else { return }
                if let activeError = downloadError {
                    self.finishDownload(download: download, error: activeError)
                } else if let data = downloadedData {
                    self.finishDownload(download: download, fileURL: filePath, data: data)
                } else {
                    self.finishDownload(download: download, error: .emptyFile)
                }
            }
        }
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard error != nil, let requestUrl = task.originalRequest?.url?.absoluteString else { return }
        self.storage.main.context.performAndWait {
            let library = LibraryStorage(context: self.storage.main.context)
            guard let download = library.getDownload(url: requestUrl) else { return }
            self.finishDownload(download: download, error: .fetchFailed)
        }
    }
    
    func urlSession(_ session: URLSession,
                    downloadTask: URLSessionDownloadTask,
                    didWriteData bytesWritten: Int64, totalBytesWritten: Int64,
                    totalBytesExpectedToWrite: Int64) {
        guard let requestUrl = downloadTask.originalRequest?.url?.absoluteString else { return }
        
        self.storage.async.perform { asyncCompanion in
            guard let download = asyncCompanion.library.getDownload(url: requestUrl) else { return }
            let progress = Float(totalBytesWritten) / Float(totalBytesExpectedToWrite)
            guard progress > download.progress, (download.progress == 0.0) || (progress > download.progress + 0.1) else { return }
            download.progress = Float(totalBytesWritten) / Float(totalBytesExpectedToWrite)
            download.totalSize = ByteCountFormatter.string(fromByteCount: totalBytesExpectedToWrite, countStyle: .file)
            asyncCompanion.saveContext()
        }.catch { error in }
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
