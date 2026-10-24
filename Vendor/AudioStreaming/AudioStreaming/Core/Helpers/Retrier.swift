//
//  Created by Dimitrios Chatzieleftheriou on 13/11/2020.
//  Copyright © 2020 Decimal. All rights reserved.
//

import Foundation

/// An object that coordinates the retrying of a method (closure)
final class Retrier {
  private var interval: DispatchTimeInterval = .seconds(1)
  private var callback: (() -> ())?

  private let maxInterval: Int
  private let timeoutTimer: DispatchTimerSource

  /// Initializes a new object with the given parameters
  /// - Parameters:
  ///   - interval: The Mach absolute time at which to execute the dispatch source's event handler.
  ///   - maxInterval: The maximum interval in which the internal timer will retry the callback.
  ///   - underlyingQueue: An optional `DispatchQueue` objects to be assigned on the timer.
  init(interval: DispatchTimeInterval, maxInterval: Int, underlyingQueue: DispatchQueue?) {
    self.interval = interval
    self.maxInterval = maxInterval
    self.timeoutTimer = DispatchTimerSource(queue: underlyingQueue)
  }

  /// Starts the process of retrying, this should be called each time the need for retry.
  ///
  /// Each time the timer fires the interval will increment
  /// itself by 1 with a maximum value of the given `maxInterval`
  ///
  /// - Parameter callback: The method to be executed when timer is fired.
  func retry(callback: @escaping () -> ()) {
    guard !timeoutTimer.isRunning else { return }
    self.callback = callback
    internalRetry()
  }

  /// Cancels retrying
  func cancel() {
    interval = .seconds(1)
    timeoutTimer.removeHandler()
    timeoutTimer.suspend()
  }

  // MARK: - Private

  private func internalRetry() {
    cancel()
    timeoutTimer.schedule(interval: interval, repeats: false)
    timeoutTimer.add { [weak self] in
      self?.callback?()
    }
    timeoutTimer.activate()
    switch interval {
    case let .seconds(value):
      interval = .seconds(min(value + 1, maxInterval))
    default:
      interval = .seconds(1)
    }
  }
}
