import Foundation

class ConcurrentTaskGroup {
    
    private var queue = DispatchQueue(label: "SynchronizedCounter")
    private var activeTasksSemaphore: DispatchSemaphore
    private var activeTasksTracker: DispatchGroup
    private var activeTasksCount: Int
    let maxTaskSlots: Int
    
    init(taskSlotsCount: Int) {
        maxTaskSlots = taskSlotsCount
        activeTasksSemaphore = DispatchSemaphore(value: maxTaskSlots)
        activeTasksTracker = DispatchGroup()
        activeTasksCount = 0
    }
    
    var activeTasks: Int {
        var result = 0
        queue.sync { result = activeTasksCount }
        return result
    }
    
    var isTaskActive: Bool {
        var result = false
        queue.sync { result = activeTasksCount > 0 }
        return result
    }
    
    func waitForSlot() {
        activeTasksSemaphore.wait()
        queue.sync {
            activeTasksCount += 1
            activeTasksTracker.enter()
        }
    }
    
    func taskFinished() {
        queue.sync {
            activeTasksTracker.leave()
            activeTasksCount -= 1
        }
        activeTasksSemaphore.signal()
    }
    
    func waitTillAllTasksFinished() {
        activeTasksTracker.wait()
    }
    
}
