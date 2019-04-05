import Foundation
import os.log

class GenericLibraryBackgroundSyncer {
    
    internal let log = OSLog(subsystem: AppDelegate.name, category: "LibrarySyncer")
    internal let semaphoreGroup = DispatchGroup()
    internal var isRunning = false
    public internal(set) var isActive = false
    
    func stop() {
        isRunning = false
    }
    
    func stopAndWait() {
        stop()
        semaphoreGroup.wait()
    }
    
}
