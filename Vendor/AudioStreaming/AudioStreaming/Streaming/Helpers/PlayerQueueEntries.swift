//
//  Created by Dimitrios Chatzieleftheriou on 04/06/2020.
//  Copyright © 2020 Decimal. All rights reserved.
//

// MARK: - PlayerQueueType

enum PlayerQueueType {
  case upcoming
  case buffering
}

// MARK: - PlayerQueueEntries

/// Handles the buffering and upcoming upcoming `AudioEntries`
/// The underlying objects are defined as `Queue<AudioEntry>`
final class PlayerQueueEntries {
  private let lock = UnfairLock()
  private var bufferring: Queue<AudioEntry>
  private var upcoming: Queue<AudioEntry>

  /// Returns `true` when both underlying entries are empty
  var isEmpty: Bool {
    lock.withLock {
      bufferring.isEmpty && upcoming.isEmpty
    }
  }

  /// Returns the count of both underlying entries
  var count: Int {
    lock.withLock {
      bufferring.count + upcoming.count
    }
  }

  init() {
    self.bufferring = Queue<AudioEntry>()
    self.upcoming = Queue<AudioEntry>()
  }

  /// Returns an array containing all items in the queue for the specified `type`.
  ///
  /// - Note: This method returns the items in the queue without removing them.
  ///
  /// - Parameter type: A `PlayerQueueType` specifying the type of the queue.
  /// - Returns: An array of `AudioEntry` objects representing the items in the queue.
  func items(type: PlayerQueueType) -> [AudioEntry] {
    lock.lock(); defer { lock.unlock() }
    return queue(for: type).items
  }

  /// Adds the `item` to the underlying queue for the specified `type`
  /// - parameter item: An `AudioEntry` object to be added
  /// - parameter type: The type fo the underlying queue as expressed by `PlayerQueueType`
  func enqueue(item: AudioEntry, type: PlayerQueueType) {
    lock.lock(); defer { lock.unlock() }
    queue(for: type).enqueue(item: item)
  }

  /// Returns and removes the `item` to the underlying queue for the specified `type`
  /// - parameter item: An `AudioEntry` object to be added
  /// - parameter type: The type fo the underlying queue as expressed by `PlayerQueueType`
  /// - returns: An `AudioEntry` if found
  func dequeue(type: PlayerQueueType) -> AudioEntry? {
    lock.lock(); defer { lock.unlock() }
    return queue(for: type).dequeue()
  }

  func insert(item: AudioEntry, type: PlayerQueueType, after afterItem: AudioEntry) {
    lock.lock(); defer { lock.unlock() }
    if let indexForAfterItem = queue(for: type).items.firstIndex(of: afterItem) {
      queue(for: .upcoming).insert(item: item, at: indexForAfterItem)
    }
  }

  /// Inserts the `item` at the specified index in the underlying queue for the specified `type`.
  /// - Parameters:
  ///   - item: An `AudioEntry` object to be added.
  ///   - type: The type of the underlying queue as expressed by `PlayerQueueType`.
  ///   - index: The index at which to insert the item.
  func insert(item: AudioEntry, type: PlayerQueueType, at index: Int) {
    lock.lock(); defer { lock.unlock() }
    queue(for: type).insert(item: item, at: index)
  }

  /// Removes the item at the specified index from the underlying queue for the specified `type`.
  /// - Parameters:
  ///   - type: The type of the underlying queue as expressed by `PlayerQueueType`.
  ///   - index: The index of the item to remove.
  func remove(item: AudioEntry, type: PlayerQueueType) {
    lock.lock(); defer { lock.unlock() }
    queue(for: type).remove(item: item)
  }

  /// Appends (skips) the `items` to the underlying queue for the specified `type`
  /// - parameter item: An `AudioEntry` object to be added
  /// - parameter type: The type fo the underlying queue as expressed by `PlayerQueueType`
  func skip(items: [AudioEntry], type: PlayerQueueType) {
    lock.lock(); defer { lock.unlock() }
    queue(for: type).skip(items: items)
  }

  /// Append (skip) the `item` to the underlying queue for the specified `type`
  /// - parameter item: An `AudioEntry` object to be added
  /// - parameter type: The type fo the underlying queue as expressed by `PlayerQueueType`
  func skip(item: AudioEntry, type: PlayerQueueType) {
    lock.lock(); defer { lock.unlock() }
    queue(for: type).skip(item: item)
  }

  func count(for type: PlayerQueueType) -> Int {
    lock.lock(); defer { lock.unlock() }
    return queue(for: type).count
  }

  /// Removes all elements from the specified queue type
  func removeAll(for type: PlayerQueueType) {
    lock.lock(); defer { lock.unlock() }
    queue(for: type).removeAll()
  }

  /// Removes all elements from all queue type
  func removeAll() {
    lock.lock(); defer { lock.unlock() }
    queue(for: .buffering).removeAll()
    queue(for: .upcoming).removeAll()
  }

  /// Returns an array of `AudioEntryId` of both underlying queues
  /// - returns: The newly constructed array of `AudioEntryId` objects
  func pendingEntriesId() -> [AudioEntryId] {
    lock.lock(); defer { lock.unlock() }
    let upcomingIds = upcoming.map { $0.id }
    let bufferingIds = bufferring.map { $0.id }
    return upcomingIds + bufferingIds
  }

  func requeueBufferingEntries(block: (AudioEntry) -> ()) {
    lock.lock(); defer { lock.unlock() }
    let bufferring = queue(for: .buffering)
    bufferring.forEach(block)
    let bufferringItems = bufferring.map { $0 }
    queue(for: .upcoming).skip(items: bufferringItems)
    queue(for: .buffering).removeAll()
  }

  /// - parameter type: A `PlayerQueueType`
  /// - returns: The appropriate queue for given type
  private func queue(for type: PlayerQueueType) -> Queue<AudioEntry> {
    switch type {
    case .buffering:
      return bufferring
    case .upcoming:
      return upcoming
    }
  }
}

// MARK: CustomDebugStringConvertible

extension PlayerQueueEntries: CustomDebugStringConvertible {
  var debugDescription: String {
    "PlayerQueue upcoming: \(upcoming.count), buffering: \(bufferring.count)"
  }
}
