//
//  Created by Dimitrios Chatzieleftheriou on 04/06/2020.
//  Copyright © 2020 Decimal. All rights reserved.
//

/**
 Operations visualised below
 ```
    enqueue(item: 1)
    +---+
    | 1 |
    +---+
    enqueue(item: 2)
    +---+ +---+
    | 2 | | 1 |
    +---+ +---+
    skip(item: 3), skip(items: [3, 4])
    +---+ +---+ +---+
    | 2 | | 1 | | 3 |
    +---+ +---+ +---+

    dequeue() -> 3
    +---+ +---+
    | 2 | | 1 |
    +---+ +---+
 ```
 */
final class Queue<Element: Equatable>: Sequence, CustomDebugStringConvertible {
  private var _storage: [Element] = []

  var isEmpty: Bool { _storage.isEmpty }

  var count: Int { _storage.count }

  var items: [Element] { _storage }

  /// Inserts an item at the end of the queue
  func enqueue(item: Element) {
    _storage.insert(item, at: 0)
  }

  /// Removes and returns the last item
  func dequeue() -> Element? {
    guard !isEmpty else { return nil }
    return _storage.removeLast()
  }

  /// Adds element at the front of the queue
  func skip(item: Element) {
    _storage.append(item)
  }

  /// Adds elements at the front of the queue
  func skip(items: [Element]) {
    for item in items {
      _storage.append(item)
    }
  }

  /// Inserts an item at a specific index in the queue
  func insert(item: Element, at index: Int) {
    guard index >= 0, index <= count else {
      fatalError("Index out of range")
    }
    _storage.insert(item, at: index)
  }

  func remove(item: Element) {
    guard let index = _storage.firstIndex(of: item) else {
      return
    }
    _storage.remove(at: index)
  }

  /// Removes the item at the specified index in the queue
  @discardableResult
  func remove(at index: Int) -> Element? {
    guard index >= 0, index < count else {
      return nil
    }
    return _storage.remove(at: index)
  }

  /// Retrieves the last item
  func peek() -> Element? {
    _storage.last
  }

  /// Revoves all elements
  func removeAll() {
    _storage.removeAll()
  }

  func makeIterator() -> Array<Element>.Iterator {
    _storage.makeIterator()
  }

  var debugDescription: String {
    "Queue with elements: \(_storage)"
  }
}
