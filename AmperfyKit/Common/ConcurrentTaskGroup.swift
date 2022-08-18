//
//  ConcurrentTaskGroup.swift
//  AmperfyKit
//
//  Created by Maximilian Bauer on 24.07.21.
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
