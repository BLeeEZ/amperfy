//
//  Created by Dimitrios Chatzieleftheriou on 08/06/2020.
//  Copyright © 2020 Decimal. All rights reserved.
//

import Foundation

/**
 A Timer implementation using `DispatchSource.makeTimerSource`.
 */
final class DispatchTimerSource {
  private var handler: (() -> ())?
  private let timer: DispatchSourceTimer
  var state: SourceState = .suspended

  /// The state of the timer
  enum SourceState {
    case activated
    case suspended
  }

  var isRunning: Bool {
    state == .activated
  }

  /// Initializes an new `DispatchTimerSource`
  ///
  /// - parameter interval: A `DispatchTimeInterval` value indicating the interval of te timer.
  /// - parameter queue: An optional `DispatchQueue` in which to execute the installed handlers.
  required init(queue: DispatchQueue?) {
    self.timer = DispatchSource.makeTimerSource(flags: [], queue: queue)
  }

  convenience init(interval: DispatchTimeInterval, queue: DispatchQueue?, repeats: Bool = true) {
    self.init(queue: queue)
    schedule(interval: interval, repeats: repeats)
  }

  deinit {
    timer.setEventHandler(handler: nil)
    timer.cancel()
    // balance called of cancel/resume to avoid crashes
    timer.resume()
  }

  /// Adds an event handler to the timer.
  ///
  /// - parameter handler: A closure for the event handler
  func add(handler: @escaping () -> ()) {
    let handler = handler
    timer.setEventHandler(handler: handler)
  }

  /// Removes the added event handler from the timer.
  func removeHandler() {
    timer.setEventHandler(handler: nil)
  }

  /// Activates the timer, if needed
  func activate() {
    if state == .activated { return }
    state = .activated
    timer.resume()
  }

  /// Suspends the timer, if needed.
  func suspend() {
    if state == .suspended { return }
    state = .suspended
    timer.suspend()
  }

  func schedule(interval: DispatchTimeInterval, repeats: Bool) {
    timer.schedule(deadline: .now() + interval, repeating: repeats ? interval : .never)
  }
}
