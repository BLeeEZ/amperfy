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

import Foundation
import CoreData
import os.log
import PromiseKit

class DownloadManager: NSObject, DownloadManageable {
    
    let storage: PersistentStorage
    let requestManager: DownloadRequestManager
    let downloadDelegate: DownloadManagerDelegate
    let notificationHandler: EventNotificationHandler
    var urlSession: URLSession!
    var backgroundFetchCompletionHandler: CompleteHandlerBlock?
    let log: OSLog
    var isFailWithPopupError: Bool = true
    var preDownloadIsValidCheck: ((_ object: Downloadable) -> Bool)?
    
    private let downloadSlotCount: Int
    private let eventLogger: EventLogger
    private let activeDispatchGroup = DispatchGroup()
    private let downloadPreperationSemaphore = DispatchSemaphore(value: 1)
    private var isRunning = false
    private var isActive = false
    
    init(name: String, storage: PersistentStorage, requestManager: DownloadRequestManager, downloadDelegate: DownloadManagerDelegate, notificationHandler: EventNotificationHandler, eventLogger: EventLogger) {
        log = OSLog(subsystem: "Amperfy", category: name)
        self.storage = storage
        self.requestManager = requestManager
        self.downloadDelegate = downloadDelegate
        self.notificationHandler = notificationHandler
        self.eventLogger = eventLogger
        self.downloadSlotCount = downloadDelegate.parallelDownloadsCount
    }
    
    func download(object: Downloadable) {
        guard !object.isCached, storage.settings.isOnlineMode, (object is Artwork) || !storageExceedsCacheLimit() else { return }
        if let isValidCheck = preDownloadIsValidCheck, !isValidCheck(object) { return }
        self.requestManager.add(object: object)
    }
    
    func download(objects: [Downloadable]) {
        guard storage.settings.isOnlineMode, !storageExceedsCacheLimit() else { return }
        let downloadObjects = objects.filter{ !$0.isCached }.filter{ preDownloadIsValidCheck?($0) ?? true }
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
        requestManager.cancelDownloads()
        urlSession.getAllTasks { tasks in
            tasks.forEach{ $0.cancel() }
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
        return storage.main.library.cachedPlayableSizeInByte > storage.settings.cacheLimit
    }
    
    func cancelPlayableDownloads(){
        requestManager.cancelPlayablesDownloads()
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
                
                self.manageDownload(download: nextDownload)
                .finally {
                    self.downloadPreperationSemaphore.signal()
                }
            }
            os_log("DownloadManager stopped", log: self.log, type: .info)
            self.isActive = false
            self.activeDispatchGroup.leave()
        }
    }
    
    private func manageDownload(download: Download) -> PMKFinalizer {
        return firstlyOnMain{ () -> Promise<Void> in
            os_log("Fetching %s ...", log: self.log, type: .info, download.title)
            return Promise.value
        }.then {
            self.downloadDelegate.prepareDownload(download: download)
        }.get { url in
            download.url = url
            self.storage.main.saveContext()
            self.fetch(url: url)
        }.catch { error in
            if let fetchError = error as? DownloadError {
                self.finishDownload(download: download, error: fetchError)
            } else {
                self.finishDownload(download: download, error: .fetchFailed)
            }
        }
    }
      
    
    func finishDownload(download: Download, error: DownloadError) {
        if !download.isCanceled {
            download.error = error
            if error != .apiErrorResponse {
                os_log("Fetching %s FAILED: %s", log: self.log, type: .info, download.title, error.description)
                eventLogger.error(topic: "Download Error", statusCode: .downloadError, message: "Error \"\(error.description)\" occured while downloading object \"\(download.title)\".", displayPopup: isFailWithPopupError)
            }
            downloadDelegate.failedDownload(download: download, storage: self.storage)
        }
        download.isDownloading = false
        storage.main.library.saveContext()
    }
    
    func finishDownload(download: Download, data: Data) {
        download.resumeData = data
        if let responseError = downloadDelegate.validateDownloadedData(download: download) {
            os_log("Fetching %s API-ERROR StatusCode: %d, Message: %s", log: log, type: .error, download.title, responseError.statusCode, responseError.message)
            eventLogger.report(error: responseError, displayPopup: isFailWithPopupError)
            finishDownload(download: download, error: .apiErrorResponse)
            return
        }
        os_log("Fetching %s SUCCESS (%{iec-bytes}d)", log: self.log, type: .info, download.title, data.count)
        firstly {
            downloadDelegate.completedDownload(download: download, storage: self.storage)
        }.done {
            download.resumeData = nil
            download.isDownloading = false
            self.storage.main.saveContext()
            if let downloadElement = download.element {
                self.notificationHandler.post(name: .downloadFinishedSuccess, object: self, userInfo: DownloadNotification(id: downloadElement.uniqueID).asNotificationUserInfo)
                if self.storageExceedsCacheLimit() {
                    self.cancelPlayableDownloads()
                }
            }
        }
    }
    
}
