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

import CoreData
import Foundation
import os.log

extension DownloadManager: URLSessionDelegate, URLSessionDownloadDelegate {
  func fetch(downloadTaskInfo: DownloadTaskInfo) {
    let task = urlSession?.downloadTask(with: downloadTaskInfo.url)
    guard let task else { return }
    tasks[task] = downloadTaskInfo
    task.resume()
  }

  nonisolated func urlSession(
    _ session: URLSession,
    downloadTask: URLSessionDownloadTask,
    didFinishDownloadingTo location: URL
  ) {
    let filePath = try? fileManager.moveItemToTempDirectoryWithUniqueName(at: location)
    let fileMimeType = downloadTask.response?.mimeType

    // didFinishDownloadingTo location
    // A file URL for the temporary file. Because the file is temporary, you must either open the file for
    // reading or move it to a permanent location in your app’s sandbox container directory before returning from this delegate method.
    // If you choose to open the file for reading, you should do the actual reading in another thread to avoid blocking the delegate queue.
    Task {
      guard let taskInfo = await tasks[downloadTask] else { return }

      var downloadError: DownloadError?
      if let filePath = filePath,
         let fileSize = self.fileManager.getFileSize(url: filePath) {
        if fileSize > 0 {
          // download seems fine for now
        } else {
          downloadError = .emptyFile
        }
      } else {
        downloadError = .fileManagerError
        os_log("Could not move download to tmp directory", log: self.log, type: .error)
      }

      if let activeError = downloadError {
        await self.finishDownload(
          downloadRequest: taskInfo.request,
          task: downloadTask,
          error: activeError
        )
      } else if let filePath = filePath {
        await self.finishDownload(
          downloadRequest: taskInfo.request, task: downloadTask,
          fileURL: filePath,
          fileMimeType: fileMimeType
        )
      } else {
        await self.finishDownload(
          downloadRequest: taskInfo.request,
          task: downloadTask,
          error: .emptyFile
        )
      }
    }
  }

  nonisolated func urlSession(
    _ session: URLSession,
    task: URLSessionTask,
    didCompleteWithError error: Error?
  ) {
    guard error != nil else { return }
    Task {
      guard let taskInfo = await tasks[task] else { return }
      await self.finishDownload(downloadRequest: taskInfo.request, task: task, error: .fetchFailed)
    }
  }

//  nonisolated func urlSession(
//    _ session: URLSession,
//    downloadTask: URLSessionDownloadTask,
//    didWriteData bytesWritten: Int64,
//    totalBytesWritten: Int64,
//    totalBytesExpectedToWrite: Int64
//  ) {
//    // ignore progress: don't save progress in CoreData -> huge CPU load
//  }

  nonisolated func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
    os_log("URLSession urlSessionDidFinishEvents", log: self.log, type: .info)
    Task { @MainActor in
      guard let completionHandler = await getBackgroundFetchCompletionHandler() else { return }
      os_log("Calling application backgroundFetchCompletionHandler", log: self.log, type: .info)
      completionHandler()
      setBackgroundFetchCompletionHandler(nil)
    }
  }
}
