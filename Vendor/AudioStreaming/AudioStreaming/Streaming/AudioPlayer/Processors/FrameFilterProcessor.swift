//
//  Created by Dimitrios C on 19/05/2021.
//  Copyright © 2021 Decimal. All rights reserved.
//

import AVFoundation

///
/// - parameter buffer: A buffer of audio captured from the output of an AVAudioNode.
/// - parameter when: The time the buffer was captured.
///
public typealias FilterCallback = (
  _ buffer: AVAudioPCMBuffer,
  _ when: AVAudioTime
)
  -> ()

// MARK: - FilterEntry

/// A value type whose instances are used for frame filter
/// - Note:
/// The filter block will be called from a thread other than the main thread
public struct FilterEntry: Equatable {
  /// A string value indicating the name of the filter
  public let name: String

  /// A block in which you apply any filtering
  public let filter: FilterCallback

  public init(name: String, filter: @escaping FilterCallback) {
    self.name = name
    self.filter = filter
  }

  public static func == (lhs: FilterEntry, rhs: FilterEntry) -> Bool {
    lhs.name == rhs.name
  }
}

// MARK: - FrameFiltering

public protocol FrameFiltering {
  /// A Boolean value indicating whether there are filter entries
  var hasEntries: Bool { get }

  /// Adds a filter entry at the end of the queue
  /// - Parameter entry: An instance of `FilterEntry`
  func add(entry: FilterEntry)

  /// Adds a filter entry after the specified name of another entry
  /// - Parameters:
  ///   - entry: An instance of `FilterEntry`
  ///   - named: The name of a previously added filter
  func add(entry: FilterEntry, afterEntry named: String)

  /// Adds a filter entry with the given parameters
  /// - Parameters:
  ///   - named: The name of the entry to be added
  ///   - filter: The block for the filter handling
  func add(entry named: String, filter: @escaping FilterCallback)

  /// Adds a filter entry with the given parameters
  /// - Parameters:
  ///   - name: The name for the new entry
  ///   - filterName: The name of a previously added filters
  ///   - filter: The block for the filter handling
  func add(entry named: String, after filterName: String, filter: @escaping FilterCallback)

  /// Removes a filter entry
  /// - Parameter entry: An instance of `FilterEntry` to be removed
  func remove(entry: FilterEntry)

  /// Attempts to remove a filter entry by its name
  /// - Parameter named: A `String` representing the name of the filter entry
  func remove(entry named: String)

  /// Removes all filter entries
  func removeAll()
}

// MARK: - FrameFilterProcessor

final class FrameFilterProcessor: NSObject, FrameFiltering {
  public var hasEntries: Bool {
    lock.lock(); defer { lock.unlock() }
    return !entries.isEmpty
  }

  private let lock = UnfairLock()
  private let mixerNodeProvider: () -> AVAudioMixerNode
  private lazy var mixerNode: AVAudioMixerNode = mixerNodeProvider()

  private(set) var entries: [FilterEntry] = []

  private var hasInstalledTap: Bool = false

  init(mixerNodeProvider: @escaping (() -> AVAudioMixerNode)) {
    self.mixerNodeProvider = mixerNodeProvider
  }

  public func add(entry: FilterEntry) {
    lock.lock(); defer { lock.unlock() }
    entries.append(entry)
    installTapIfNeeded()
  }

  public func add(entry: FilterEntry, afterEntry named: String) {
    lock.lock(); defer { lock.unlock() }
    guard let entryIndex = entries.firstIndex(where: { $0.name == named }) else {
      return
    }
    if entryIndex.advanced(by: 1) > entries.count {
      entries.append(entry)
    } else {
      entries.insert(entry, at: entryIndex + 1)
    }
    installTapIfNeeded()
  }

  public func add(entry named: String, filter: @escaping FilterCallback) {
    lock.lock(); defer { lock.unlock() }
    entries.append(FilterEntry(name: named, filter: filter))
    installTapIfNeeded()
  }

  func add(entry named: String, after filterName: String, filter: @escaping FilterCallback) {
    let entry = FilterEntry(name: named, filter: filter)
    add(entry: entry, afterEntry: filterName)
  }

  public func remove(entry: FilterEntry) {
    lock.lock(); defer { lock.unlock() }
    guard let entryIndex = entries.firstIndex(where: { $0 == entry }) else {
      return
    }
    entries.remove(at: entryIndex)
    if entries.isEmpty {
      removeTap()
    }
  }

  public func remove(entry named: String) {
    lock.lock(); defer { lock.unlock() }
    guard let entryIndex = entries.firstIndex(where: { $0.name == named }) else {
      return
    }
    entries.remove(at: entryIndex)
    if entries.isEmpty {
      removeTap()
    }
  }

  public func removeAll() {
    lock.lock(); defer { lock.unlock() }
    entries.removeAll()
    removeTap()
  }

  private func process(buffer: AVAudioPCMBuffer, when: AVAudioTime) {
    lock.lock(); defer { lock.unlock() }
    guard !entries.isEmpty else { return }
    for entry in entries {
      entry.filter(buffer, when)
    }
  }

  private func installTapIfNeeded() {
    guard !hasInstalledTap else { return }
    hasInstalledTap = true
    let format = mixerNode.outputFormat(forBus: 0)
    mixerNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, when in
      guard let self = self else { return }
      guard hasEntries else { return }
      process(
        buffer: buffer,
        when: when
      )
    }
  }

  private func removeTap() {
    hasInstalledTap = false
    mixerNode.removeTap(onBus: 0)
  }
}
