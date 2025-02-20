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
public typealias PreDownloadIsValidCB = @MainActor (_ downloadInfos: [DownloadElementInfo]) async
  -> [DownloadElementInfo]

// MARK: - DownloadOperation

class DownloadOperation: AsyncOperation, @unchecked Sendable {
  private let lock = NSLock()

  public init(completeBlock: @escaping VoidAsyncClosure) {
    self.completeBlock = completeBlock
  }

  override public func main() {
    Task {
      await withCheckedContinuation { conti in
        Task {
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

actor DownloadManager: NSObject, DownloadManageable {
  @MainActor
  var networkMonitor: NetworkMonitorFacade!
  let storage: AsyncCoreDataAccessWrapper
  let requestManager: DownloadRequestManager
  @MainActor
  var downloadDelegate: DownloadManagerDelegate!
  var notificationHandler: EventNotificationHandler!
  var urlSession: URLSession!

  let log: OSLog
  var isFailWithPopupError: Bool = true
  var preDownloadIsValidCheck: PreDownloadIsValidCB?
  let fileManager = CacheFileManager.shared
  var isCacheSizeLimited: Bool

  internal var tasks = [URLSessionTask: DownloadTaskInfo]()
  internal var taskQueue: OperationQueue

  private let name: String
  private let eventLogger: EventLogger
  private let settings: PersistentStorage.Settings
  @MainActor
  private var urlCleanser: URLCleanser!
  private var isRunning = false
  private var taskOperations = [DownloadRequest: DownloadOperation]()
  private var backgroundFetchCompletionHandler: CompleteHandlerBlock?

  init(
    name: String,
    storage: AsyncCoreDataAccessWrapper,
    requestManager: DownloadRequestManager,
    eventLogger: EventLogger,
    settings: PersistentStorage.Settings,
    notificationHandler: EventNotificationHandler,
    limitCacheSize: Bool,
    isFailWithPopupError: Bool
  ) {
    self.name = name
    self.log = OSLog(subsystem: "Amperfy", category: name)
    self.storage = storage
    self.requestManager = requestManager
    self.eventLogger = eventLogger
    self.settings = settings
    self.isCacheSizeLimited = limitCacheSize
    self.isFailWithPopupError = isFailWithPopupError
    self.taskQueue = OperationQueue()

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
  public func initialize(
    networkMonitor: NetworkMonitorFacade,
    downloadDelegate: DownloadManagerDelegate,
    urlSession: URLSession,
    validationCB: PreDownloadIsValidCB?,
    urlCleanser: URLCleanser
  ) {
    self.networkMonitor = networkMonitor
    self.downloadDelegate = downloadDelegate
    self.urlCleanser = urlCleanser

    Task {
      await taskQueue.maxConcurrentOperationCount = downloadDelegate.parallelDownloadsCount
      await _initialize(urlSession: urlSession, validationCB: validationCB)
    }
  }

  private func _initialize(urlSession: URLSession, validationCB: PreDownloadIsValidCB?) {
    self.urlSession = urlSession
    preDownloadIsValidCheck = validationCB
  }

  nonisolated func getBackgroundFetchCompletionHandler() async -> CompleteHandlerBlock? {
    await Task {
      await backgroundFetchCompletionHandler
    }.value
  }

  nonisolated func setBackgroundFetchCompletionHandler(_ newValue: CompleteHandlerBlock?) {
    Task {
      await _setBackgroundFetchCompletionHandler(newValue)
    }
  }

  private func _setBackgroundFetchCompletionHandler(_ newValue: CompleteHandlerBlock?) {
    backgroundFetchCompletionHandler = newValue
  }

  @MainActor
  func download(object: Downloadable) {
    guard !object.isCached,
          let downloadInfo = object.threadSafeInfo
    else { return }

    Task.detached {
      let isStorageExceeded = await self.storageExceedsCacheLimit()
      guard await !self.isCacheSizeLimited || !isStorageExceeded
      else { return }

      var validDls = [downloadInfo]
      if let isValidCheck = await self.preDownloadIsValidCheck {
        validDls = await isValidCheck(validDls)
        guard !validDls.isEmpty else { return }
      }

      guard let request = await self.requestManager.add(downloadInfo: downloadInfo) else { return }
      guard await self.isAllowedToTriggerDownload else { return }
      await self.addDownloadTaskOperation(downloadRequest: request)
    }
  }

  @MainActor
  func download(objects: [Downloadable]) {
    let downloadObjects = objects.filter { !$0.isCached }
      .compactMap { $0.threadSafeInfo }
    guard !downloadObjects.isEmpty else { return }

    Task.detached {
      let isStorageExceeded = await self.storageExceedsCacheLimit()
      guard await !self.isCacheSizeLimited || !isStorageExceeded
      else { return }

      var validDls = downloadObjects
      if let isValidCheck = await self.preDownloadIsValidCheck {
        validDls = await isValidCheck(validDls)
      }

      guard !validDls.isEmpty else { return }
      let requests = await self.requestManager.add(downloadInfos: validDls)
      guard await self.isAllowedToTriggerDownload else { return }
      for request in requests {
        await self.addDownloadTaskOperation(downloadRequest: request)
      }
    }
  }

  @MainActor
  func removeFinishedDownload(for object: Downloadable) {
    Task {
      await requestManager.removeFinishedDownload(for: object.uniqueID)
    }
  }

  @MainActor
  func removeFinishedDownload(for objects: [Downloadable]) {
    Task {
      await requestManager.removeFinishedDownload(for: objects.compactMap { $0.uniqueID })
    }
  }

  nonisolated func start() {
    Task {
      await _start()
    }
  }

  func _start() async {
    isRunning = true
    await setupDownloadQueue()
  }

  nonisolated func stop() {
    Task {
      await self._stop()
    }
  }

  private func _stop() {
    isRunning = false
    cancelDownloads()
  }

  nonisolated func cancelDownloads() {
    Task {
      await self._cancelDownloads()
    }
  }

  private func _cancelDownloads() async {
    tasks.removeAll()
    taskQueue.cancelAllOperations()
    taskOperations.removeAll()
    await requestManager.cancelDownloads()
    let urlSessionTasks = await urlSession.allTasks
    for task in urlSessionTasks {
      task.cancel()
    }
  }

  nonisolated func suspendDownloads() {
    Task {
      await self._suspendDownloads()
    }
  }

  private func _suspendDownloads() async {
    os_log("Suspend active downloads", log: self.log, type: .info)
    tasks.removeAll()
    let objectIDs = taskOperations.compactMap { $0.key.objectID }
    try? await storage.perform { asyncCompanion in
      for objectID in objectIDs {
        let download = Download(
          managedObject: asyncCompanion.context
            .object(with: objectID) as! DownloadMO
        )
        download.suspend()
      }
      asyncCompanion.saveContext()
    }

    taskOperations.removeAll()
    taskQueue.cancelAllOperations()
    let urlSessionTasks = await urlSession.allTasks
    for task in urlSessionTasks {
      task.cancel()
    }
  }

  nonisolated func clearFinishedDownloads() {
    Task {
      await _clearFinishedDownloads()
    }
  }

  private func _clearFinishedDownloads() async {
    await requestManager.clearFinishedDownloads()
  }

  nonisolated func resetFailedDownloads() {
    Task {
      await _resetFailedDownloads()
    }
  }

  func _resetFailedDownloads() async {
    let failedRequests = await requestManager.getAndResetFailedDownloads()
    guard await isAllowedToTriggerDownload else { return }
    for failedRequest in failedRequests {
      addDownloadTaskOperation(downloadRequest: failedRequest)
    }
  }

  func storageExceedsCacheLimit() -> Bool {
    guard settings.cacheLimit != 0 else { return false }
    return fileManager.playableCacheSize > settings.cacheLimit
  }

  private func setupDownloadQueue() async {
    guard await isAllowedToTriggerDownload else { return }
    let downloadRequests = await requestManager.getRequestedDownloads()
    for downloadRequest in downloadRequests {
      addDownloadTaskOperation(downloadRequest: downloadRequest)
    }
  }

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

  private func manageDownload(downloadRequest: DownloadRequest) async {
    guard await isAllowedToTriggerDownload else {
      taskOperations[downloadRequest]?.complete()
      taskOperations.removeValue(forKey: downloadRequest)
      return
    }
    try? await storage.perform { asyncCompanion in
      let download = Download(
        managedObject: asyncCompanion.context
          .object(with: downloadRequest.objectID) as! DownloadMO
      )
      download.reset()
      download.isDownloading = true
      asyncCompanion.saveContext()
    }
    os_log("Fetching %s ...", log: self.log, type: .info, downloadRequest.title)

    do {
      let url = try await Task { @MainActor in
        return try await downloadDelegate!.prepareDownload(
          downloadInfo: downloadRequest.info,
          storage: self.storage
        )
      }.value
      let downloadTaskInfo = DownloadTaskInfo(request: downloadRequest, url: url)
      fetch(downloadTaskInfo: downloadTaskInfo)
    } catch {
      if let fetchError = error as? DownloadError {
        await finishDownload(downloadRequest: downloadRequest, task: nil, error: fetchError)
      } else {
        await finishDownload(downloadRequest: downloadRequest, task: nil, error: .fetchFailed)
      }
    }
  }

  func finishDownload(
    downloadRequest: DownloadRequest,
    task: URLSessionTask?,
    error: DownloadError
  ) async {
    let isCanceled = try? await storage.performAndGet { asyncCompanion in
      let download = Download(
        managedObject: asyncCompanion.context
          .object(with: downloadRequest.objectID) as! DownloadMO
      )
      if !download.isCanceled {
        download.error = error
      }
      download.isDownloading = false
      asyncCompanion.library.saveContext()
      return download.isCanceled
    }
    if let isCanceled, !isCanceled {
      await Task { @MainActor in
        return await self.downloadDelegate!.failedDownload(
          downloadInfo: downloadRequest.info,
          storage: self.storage
        )
      }.value
    }
    if let isCanceled, !isCanceled, error != .apiErrorResponse, error != .alreadyDownloaded {
      os_log(
        "Fetching %s FAILED: %s",
        log: self.log,
        type: .info,
        downloadRequest.title,
        error.description
      )
      let shortMessage =
        "Error \"\(error.description)\" occured while downloading object \"\(downloadRequest.title)\"."
      let responseError = await MainActor.run {
        ResponseError(
          type: .api,
          message: shortMessage,
          cleansedURL: task?.originalRequest?.url?.asCleansedURL(cleanser: urlCleanser)
        )
      }
      await eventLogger.report(
        topic: "Download Error",
        error: responseError,
        displayPopup: isFailWithPopupError
      )
    }

    if let task { tasks.removeValue(forKey: task) }
    taskOperations[downloadRequest]?.complete()
    taskOperations.removeValue(forKey: downloadRequest)
  }

  func finishDownload(
    downloadRequest: DownloadRequest,
    task: URLSessionTask,
    fileURL: URL,
    fileMimeType: String?
  ) async {
    let responseError = await Task { @MainActor in
      return downloadDelegate!.validateDownloadedData(
        fileURL: fileURL,
        downloadURL: task.originalRequest?.url
      )
    }.value

    if let responseError {
      os_log(
        "Fetching %s API-ERROR StatusCode: %d, Message: %s",
        log: log,
        type: .error,
        downloadRequest.title,
        responseError.statusCode,
        responseError.message
      )
      await eventLogger.report(
        topic: "Download",
        error: responseError,
        displayPopup: isFailWithPopupError
      )
      await finishDownload(downloadRequest: downloadRequest, task: task, error: .apiErrorResponse)
      return
    }

    os_log(
      "Fetching %s SUCCESS (%{iec-bytes}d) (%s)",
      log: self.log,
      type: .info,
      downloadRequest.title,
      fileManager.getFileSize(url: fileURL) ?? 0,
      fileMimeType ?? "no MIME type"
    )
    await Task { @MainActor in
      await downloadDelegate!.completedDownload(
        downloadInfo: downloadRequest.info,
        fileURL: fileURL,
        fileMimeType: fileMimeType,
        storage: self.storage
      )
    }.value

    let downloadElementUniqueId = try? await storage.performAndGet { asyncCompanion in
      let download = Download(
        managedObject: asyncCompanion.context
          .object(with: downloadRequest.objectID) as! DownloadMO
      )
      download.isDownloading = false
      asyncCompanion.saveContext()
      return download.element?.uniqueID
    }
    if let downloadElementUniqueId {
      notificationHandler.post(
        name: .downloadFinishedSuccess,
        object: self,
        userInfo: DownloadNotification(id: downloadElementUniqueId).asNotificationUserInfo
      )
    }
    if isCacheSizeLimited, storageExceedsCacheLimit() {
      await requestManager.cancelDownloads()
    }
    tasks.removeValue(forKey: task)
    taskOperations[downloadRequest]?.complete()
    taskOperations.removeValue(forKey: downloadRequest)
  }

  private var isAllowedToTriggerDownload: Bool {
    get async {
      let isConnectedToNetwork = await Task { @MainActor in
        return networkMonitor?.isConnectedToNetwork ?? false
      }.value

      return isRunning &&
        settings.isOnlineMode &&
        isConnectedToNetwork &&
        (!isCacheSizeLimited || !storageExceedsCacheLimit())
    }
  }

  @objc
  nonisolated private func networkStatusChanged(notification: Notification) {
    Task {
      guard await isRunning else { return }
      if await isAllowedToTriggerDownload {
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
