//
//  AsyncOperation.swift
//  AmperfyKit
//
//  Created by Maximilian Bauer on 14.02.25.
//  Copyright (c) 2025 Maximilian Bauer. All rights reserved.
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

open class AsyncOperation: Operation, @unchecked Sendable {
  private let lock = NSLock()

  override open var isAsynchronous: Bool {
    true
  }

  private var _isExecuting: Bool = false
  override open private(set) var isExecuting: Bool {
    get {
      lock.withLock {
        _isExecuting
      }
    }
    set {
      willChangeValue(forKey: "isExecuting")
      lock.withLock {
        _isExecuting = newValue
      }
      didChangeValue(forKey: "isExecuting")
    }
  }

  private var _isFinished: Bool = false
  override open private(set) var isFinished: Bool {
    get {
      lock.withLock {
        _isFinished
      }
    }
    set {
      willChangeValue(forKey: "isFinished")
      lock.withLock {
        _isFinished = newValue
      }
      didChangeValue(forKey: "isFinished")
    }
  }

  override open func start() {
    guard !isCancelled else {
      finish()
      return
    }

    isFinished = false
    isExecuting = true
    main()
  }

  open func finish() {
    isExecuting = false
    isFinished = true
  }
}
