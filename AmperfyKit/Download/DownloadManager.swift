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

  private let downloadSlotCount: Int
  private let eventLogger: EventLogger
  private let urlCleanser: URLCleanser
  private var activeTaskCount: Int
  private var isRunning = false
  private var sleepTimer: Timer?
  private let timeInterval = TimeInterval(5) // time to check for available downloads to start

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
    self.log = OSLog(subsystem: "Amperfy", category: name)
    self.networkMonitor = networkMonitor
    self.storage = storage
    self.requestManager = requestManager
    self.downloadDelegate = downloadDelegate
    self.notificationHandler = notificationHandler
    self.eventLogger = eventLogger
    self.urlCleanser = urlCleanser
    self.downloadSlotCount = downloadDelegate.parallelDownloadsCount
    self.activeTaskCount = downloadSlotCount
  }

  @MainActor
  func download(object: Downloadable) {
    guard !object.isCached, storage.settings.isOnlineMode,
          (object is Artwork) || !storageExceedsCacheLimit() else { return }
    Task { @MainActor in
      if let isValidCheck = preDownloadIsValidCheck, !isValidCheck(object) { return }
      self.requestManager.add(object: object)
      triggerBackgroundDownload()
    }
  }

  @MainActor
  func download(objects: [Downloadable]) {
    Task { @MainActor in
      guard storage.settings.isOnlineMode, !storageExceedsCacheLimit() else { return }
      let downloadObjects = objects.filter { !$0.isCached }
        .filter { preDownloadIsValidCheck?($0) ?? true }
      if !downloadObjects.isEmpty {
        self.requestManager.add(objects: downloadObjects)
      }
      triggerBackgroundDownload()
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
    sleepTimer?.invalidate()
    sleepTimer = Timer.scheduledTimer(withTimeInterval: timeInterval, repeats: true) { _ in
      Task { @MainActor in
        self.triggerBackgroundDownload()
      }
    }
    triggerBackgroundDownload()
  }

  func stop() {
    isRunning = false
    sleepTimer?.invalidate()
    sleepTimer = nil
    cancelDownloads()
  }

  func cancelDownloads() {
    requestManager.cancelDownloads()
    urlSession.getAllTasks { tasks in
      tasks.forEach { $0.cancel() }
    }
  }

  func clearFinishedDownloads() {
    requestManager.clearFinishedDownloads()
  }

  func resetFailedDownloads() {
    requestManager.resetFailedDownloads()
  }

  func storageExceedsCacheLimit() -> Bool {
    guard storage.settings.cacheLimit != 0 else { return false }
    return fileManager.playableCacheSize > storage.settings.cacheLimit
  }

  func cancelPlayableDownloads() {
    requestManager.cancelPlayablesDownloads()
  }

  private func triggerBackgroundDownload() {
    Task { @MainActor in
      await self.startAvailableDownload()
    }
  }

  @MainActor
  private func startAvailableDownload() async {
    // A free download task is available
    if storage.settings.isOnlineMode,
       networkMonitor.isConnectedToNetwork,
       activeTaskCount > 0 {
      if let nextDownload = requestManager.getNextRequestToDownload() {
        // There is a download to be started
        activeTaskCount -= 1
        triggerBackgroundDownload() // trigger an additional download
        await manageDownload(download: nextDownload)
      }
    }
  }

  @MainActor
  private func manageDownload(download: Download) async {
    os_log("Fetching %s ...", log: self.log, type: .info, download.title)
    do {
      let url = try await downloadDelegate.prepareDownload(download: download)
      storage.main.perform { mainCompanion in
        mainCompanion.library.setDownloadUrl(download: download, url: url)
      }
      fetch(url: url)
    } catch {
      if let fetchError = error as? DownloadError {
        finishDownload(download: download, error: fetchError)
      } else {
        finishDownload(download: download, error: .fetchFailed)
      }
    }
  }

  @MainActor
  func finishDownload(download: Download, error: DownloadError) {
    activeTaskCount += 1
    triggerBackgroundDownload()

    if !download.isCanceled {
      download.error = error
      if error != .apiErrorResponse {
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
          cleansedURL: download.url?.asCleansedURL(cleanser: urlCleanser)
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
  }

  @MainActor
  func finishDownload(download: Download, fileURL: URL, fileMimeType: String?) async {
    activeTaskCount += 1
    triggerBackgroundDownload()

    download.fileURL = fileURL
    download.mimeType = fileMimeType
    if let responseError = downloadDelegate.validateDownloadedData(download: download) {
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
      finishDownload(download: download, error: .apiErrorResponse)
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
      if storageExceedsCacheLimit() {
        cancelPlayableDownloads()
      }
    }
  }
}
