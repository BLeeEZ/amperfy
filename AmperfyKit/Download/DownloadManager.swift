//
//  DownloadManager.swift
//  AmperfyKit
//
//  Created by Maximilian Bauer on 09.03.19.
//  Copyright (c) 2019 Maximilian Bauer. All rights reserved.
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

public typealias VoidAsyncClosure = @MainActor () async -> ()

// MARK: - DownloadOperation

class DownloadOperation: AsyncOperation, @unchecked Sendable {
  private let lock = NSLock()

  public init(completeBlock: @escaping VoidAsyncClosure) {
    self.completeBlock = completeBlock
  }

  override public func main() {
    Task { @MainActor in
      await withCheckedContinuation { conti in
        Task { @MainActor in
          var continueExecution = true
          lock.withLock {
            if isCancelled {
              continueExecution = false
              conti.resume()
            } else {
              continuation = conti
            }
          }
          guard continueExecution else { return }
          await self.completeBlock()
        }
      }
      finish()
    }
  }

  override open func cancel() {
    super.cancel()

    complete()
  }

  public func complete() {
    lock.withLock {
      continuation?.resume()
      continuation = nil
    }
  }

  private let completeBlock: VoidAsyncClosure
  private var continuation: CheckedContinuation<(), Never>?
}

// MARK: - DownloadManager

@MainActor
class DownloadManager: NSObject, DownloadManageable {
  let networkMonitor: NetworkMonitorFacade
  let storage: PersistentStorage
  let requestManager: DownloadRequestManager
  let downloadDelegate: DownloadManagerDelegate
  let notificationHandler: EventNotificationHandler
  var urlSession: URLSession!
  var backgroundFetchCompletionHandler: CompleteHandlerBlock?
  let log: OSLog
  var isFailWithPopupError: Bool = true
  var preDownloadIsValidCheck: ((_ object: Downloadable) -> Bool)?
  let fileManager = CacheFileManager.shared
  var cacheSizeLimitReachedCB: VoidFunctionCallback?

  internal var tasks = [URLSessionTask: DownloadTaskInfo]()
  internal var taskQueue: OperationQueue

  private let name: String
  private let eventLogger: EventLogger
  private let urlCleanser: URLCleanser
  private var isRunning = false
  private var taskOperations = [DownloadRequest: DownloadOperation]()

  init(
    name: String,
    networkMonitor: NetworkMonitorFacade,
    storage: PersistentStorage,
    requestManager: DownloadRequestManager,
    downloadDelegate: DownloadManagerDelegate,
    notificationHandler: EventNotificationHandler,
    eventLogger: EventLogger,
    urlCleanser: URLCleanser
  ) {
    self.name = name
    self.log = OSLog(subsystem: "Amperfy", category: name)
    self.networkMonitor = networkMonitor
    self.storage = storage
    self.requestManager = requestManager
    self.downloadDelegate = downloadDelegate
    self.notificationHandler = notificationHandler
    self.eventLogger = eventLogger
    self.urlCleanser = urlCleanser
    self.taskQueue = OperationQueue()
    taskQueue.maxConcurrentOperationCount = downloadDelegate.parallelDownloadsCount
    super.init()

    notificationHandler.register(
      self,
      selector: #selector(networkStatusChanged(notification:)),
      name: .offlineModeChanged,
      object: nil
    )
    notificationHandler.register(
      self,
      selector: #selector(networkStatusChanged(notification:)),
      name: .networkStatusChanged,
      object: nil
    )
  }

  @MainActor
  func download(object: Downloadable) {
    guard !object.isCached,
          cacheSizeLimitReachedCB == nil || !storageExceedsCacheLimit()
    else { return }

    Task { @MainActor in
      if let isValidCheck = preDownloadIsValidCheck, !isValidCheck(object) { return }
      guard let request = await self.requestManager.add(object: object) else { return }
      guard isAllowedToTriggerDownload else { return }
      addDownloadTaskOperation(downloadRequest: request)
    }
  }

  @MainActor
  func download(objects: [Downloadable]) {
    Task { @MainActor in
      guard cacheSizeLimitReachedCB == nil || !storageExceedsCacheLimit()
      else { return }

      let downloadObjects = objects.filter { !$0.isCached }
        .filter { preDownloadIsValidCheck?($0) ?? true }
      guard !downloadObjects.isEmpty else { return }
      let requests = await self.requestManager.add(objects: downloadObjects)
      guard isAllowedToTriggerDownload else { return }
      for request in requests {
        addDownloadTaskOperation(downloadRequest: request)
      }
    }
  }

  @MainActor
  func removeFinishedDownload(for object: Downloadable) {
    requestManager.removeFinishedDownload(for: object)
  }

  @MainActor
  func removeFinishedDownload(for objects: [Downloadable]) {
    requestManager.removeFinishedDownload(for: objects)
  }

  func start() {
    isRunning = true
    Task { @MainActor in
      await self.setupDownloadQueue()
    }
  }

  func stop() {
    isRunning = false
    cancelDownloads()
  }

  func cancelDownloads() {
    Task { @MainActor in
      tasks.removeAll()
      taskQueue.cancelAllOperations()
      taskOperations.removeAll()
      requestManager.cancelDownloads()
      let urlSessionTasks = await urlSession.allTasks
      for task in urlSessionTasks {
        task.cancel()
      }
    }
  }

  func suspendDownloads() {
    Task { @MainActor in
      os_log("Suspend active downloads", log: self.log, type: .info)
      tasks.removeAll()
      for operation in taskOperations {
        let download = Download(
          managedObject: storage.main.context
            .object(with: operation.key.objectID) as! DownloadMO
        )
        download.suspend()
      }
      storage.main.saveContext()
      taskOperations.removeAll()
      taskQueue.cancelAllOperations()
      let urlSessionTasks = await urlSession.allTasks
      for task in urlSessionTasks {
        task.cancel()
      }
    }
  }

  func clearFinishedDownloads() {
    requestManager.clearFinishedDownloads()
  }

  func resetFailedDownloads() {
    Task {
      let failedRequests = await requestManager.getAndResetFailedDownloads()
      guard isAllowedToTriggerDownload else { return }
      for failedRequest in failedRequests {
        addDownloadTaskOperation(downloadRequest: failedRequest)
      }
    }
  }

  func storageExceedsCacheLimit() -> Bool {
    guard storage.settings.cacheLimit != 0 else { return false }
    return fileManager.playableCacheSize > storage.settings.cacheLimit
  }

  private func setupDownloadQueue() async {
    guard isAllowedToTriggerDownload else { return }
    let downloadRequests = await requestManager.getRequestedDownloads()
    for downloadRequest in downloadRequests {
      addDownloadTaskOperation(downloadRequest: downloadRequest)
    }
  }

  @MainActor
  private func addDownloadTaskOperation(downloadRequest: DownloadRequest) {
    let existingOperation = taskOperations[downloadRequest]
    // the operation must be unique
    guard existingOperation == nil else { return }
    let asyncOperation = DownloadOperation {
      await self.manageDownload(downloadRequest: downloadRequest)
    }
    taskOperations[downloadRequest] = asyncOperation
    taskQueue.addOperation(asyncOperation)
  }

  @MainActor
  private func manageDownload(downloadRequest: DownloadRequest) async {
    guard isAllowedToTriggerDownload else {
      taskOperations[downloadRequest]?.complete()
      taskOperations.removeValue(forKey: downloadRequest)
      return
    }
    let download = Download(
      managedObject: storage.main.context
        .object(with: downloadRequest.objectID) as! DownloadMO
    )
    os_log("Fetching %s ...", log: self.log, type: .info, download.title)
    download.reset()
    download.isDownloading = true
    storage.main.saveContext()
    do {
      let url = try await downloadDelegate.prepareDownload(download: download)
      let downloadTaskInfo = DownloadTaskInfo(request: downloadRequest, url: url)
      fetch(downloadTaskInfo: downloadTaskInfo)
    } catch {
      if let fetchError = error as? DownloadError {
        finishDownload(downloadRequest: downloadRequest, task: nil, error: fetchError)
      } else {
        finishDownload(downloadRequest: downloadRequest, task: nil, error: .fetchFailed)
      }
    }
  }

  @MainActor
  func finishDownload(
    downloadRequest: DownloadRequest,
    task: URLSessionTask?,
    error: DownloadError
  ) {
    let download = Download(
      managedObject: storage.main.context
        .object(with: downloadRequest.objectID) as! DownloadMO
    )
    if !download.isCanceled {
      download.error = error
      if error != .apiErrorResponse, error != .alreadyDownloaded {
        os_log(
          "Fetching %s FAILED: %s",
          log: self.log,
          type: .info,
          download.title,
          error.description
        )
        let shortMessage =
          "Error \"\(error.description)\" occured while downloading object \"\(download.title)\"."
        let responseError = ResponseError(
          type: .api,
          message: shortMessage,
          cleansedURL: task?.originalRequest?.url?.asCleansedURL(cleanser: urlCleanser)
        )
        eventLogger.report(
          topic: "Download Error",
          error: responseError,
          displayPopup: isFailWithPopupError
        )
      }
      downloadDelegate.failedDownload(download: download, storage: storage)
    }
    download.isDownloading = false
    storage.main.library.saveContext()
    if let task { tasks.removeValue(forKey: task) }
    taskOperations[downloadRequest]?.complete()
    taskOperations.removeValue(forKey: downloadRequest)
  }

  @MainActor
  func finishDownload(
    downloadRequest: DownloadRequest,
    task: URLSessionTask,
    fileURL: URL,
    fileMimeType: String?
  ) async {
    let download = Download(
      managedObject: storage.main.context
        .object(with: downloadRequest.objectID) as! DownloadMO
    )
    download.fileURL = fileURL
    download.mimeType = fileMimeType
    if let responseError = downloadDelegate.validateDownloadedData(
      fileURL: fileURL,
      downloadURL: task.originalRequest?.url
    ) {
      os_log(
        "Fetching %s API-ERROR StatusCode: %d, Message: %s",
        log: log,
        type: .error,
        download.title,
        responseError.statusCode,
        responseError.message
      )
      eventLogger.report(
        topic: "Download",
        error: responseError,
        displayPopup: isFailWithPopupError
      )
      finishDownload(downloadRequest: downloadRequest, task: task, error: .apiErrorResponse)
      return
    }
    os_log(
      "Fetching %s SUCCESS (%{iec-bytes}d) (%s)",
      log: self.log,
      type: .info,
      download.title,
      fileManager.getFileSize(url: fileURL) ?? 0,
      fileMimeType ?? "no MIME type"
    )
    await downloadDelegate.completedDownload(download: download, storage: storage)
    download.fileURL = nil
    download.isDownloading = false
    storage.main.saveContext()
    if let downloadElement = download.element {
      notificationHandler.post(
        name: .downloadFinishedSuccess,
        object: self,
        userInfo: DownloadNotification(id: downloadElement.uniqueID).asNotificationUserInfo
      )

      if let cacheSizeLimitReachedCB, storageExceedsCacheLimit() {
        cacheSizeLimitReachedCB()
      }
    }
    tasks.removeValue(forKey: task)
    taskOperations[downloadRequest]?.complete()
    taskOperations.removeValue(forKey: downloadRequest)
  }

  @MainActor
  private var isAllowedToTriggerDownload: Bool {
    isRunning &&
      storage.settings.isOnlineMode &&
      networkMonitor.isConnectedToNetwork &&
      (cacheSizeLimitReachedCB == nil || !storageExceedsCacheLimit())
  }

  @objc
  private func networkStatusChanged(notification: Notification) {
    Task {
      guard isRunning else { return }
      if isAllowedToTriggerDownload {
        os_log(
          "Download Manager (%s): Online Mode | Internet; setup download queue",
          log: self.log,
          type: .info,
          self.name
        )
        await setupDownloadQueue()
      } else {
        os_log(
          "Download Manager (%s): Offline Mode | No Internet; suspend downloads",
          log: self.log,
          type: .info,
          self.name
        )
        suspendDownloads()
      }
    }
  }
}
