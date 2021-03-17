import Foundation

class DownloadSlotCounter {
    
    private var queue = DispatchQueue(label: "SynchronizedCounter")
    private var activeDownloadsSemaphore: DispatchSemaphore
    private var activeDownloadsTracker: DispatchGroup
    private var activeDownloadsCount: Int
    let maxActiveDownloads: Int
    
    init(maximumActiveDownloads: Int) {
        maxActiveDownloads = maximumActiveDownloads
        activeDownloadsSemaphore = DispatchSemaphore(value: maxActiveDownloads)
        activeDownloadsTracker = DispatchGroup()
        activeDownloadsCount = 0
    }
    
    var activeDownloads: Int {
        var result = 0
        queue.sync { result = activeDownloadsCount }
        return result
    }
    
    var isDownloadActive: Bool {
        var result = false
        queue.sync { result = activeDownloadsCount > 0 }
        return result
    }
    
    func waitForDownloadSlot() {
        activeDownloadsSemaphore.wait()
        queue.sync {
            activeDownloadsCount += 1
            activeDownloadsTracker.enter()
        }
    }
    
    func downloadFinished() {
        queue.sync {
            activeDownloadsTracker.leave()
            activeDownloadsCount -= 1
        }
        activeDownloadsSemaphore.signal()
    }
    
    func waitTillAllDownloadsFinished() {
        activeDownloadsTracker.wait()
    }
    
}
