import Foundation
import os.log

class GenericLibrarySyncer {
    
    internal let log = OSLog(subsystem: AppDelegate.name, category: "librarySyncer")
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
