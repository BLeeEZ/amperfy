//
//  Created by Dimitrios Chatzieleftheriou on 17/06/2020.
//  Copyright © 2020 Decimal. All rights reserved.
//

import Foundation

// MARK: - Atomic

final class Atomic<Value> {
  private let lock = UnfairLock()
  private var _value: Value

  init(_ value: Value) {
    self._value = value
  }

  var value: Value { lock.withLock { _value } }

  func write(_ transform: (inout Value) -> ()) {
    lock.withLock { transform(&self._value) }
  }
}

// MARK: Equatable

extension Atomic: Equatable where Value: Equatable {
  static func == (lhs: Atomic, rhs: Atomic) -> Bool {
    lhs.value == rhs.value
  }
}

// MARK: Hashable

extension Atomic: Hashable where Value: Hashable {
  func hash(into hasher: inout Hasher) {
    hasher.combine(value)
  }
}

// MARK: Comparable

extension Atomic: Comparable where Value: Comparable {
  static func < (lhs: Atomic<Value>, rhs: Atomic<Value>) -> Bool {
    lhs.value < rhs.value
  }
}
