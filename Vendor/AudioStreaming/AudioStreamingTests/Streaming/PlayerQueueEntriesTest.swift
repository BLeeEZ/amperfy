//
//  Created by Dimitrios Chatzieleftheriou on 04/06/2020.
//  Copyright © 2020 Decimal. All rights reserved.
//

import AVFoundation
import XCTest

@testable import AudioStreaming

// MARK: - PlayerQueueEntriesTest

class PlayerQueueEntriesTest: XCTestCase {
  func testPlayerQueueEntriesInitsEmpty() {
    let queue = PlayerQueueEntries()

    XCTAssertTrue(queue.isEmpty)
    XCTAssertEqual(queue.count, 0)
    XCTAssertEqual(queue.count(for: .buffering), 0)
    XCTAssertEqual(queue.count(for: .upcoming), 0)
  }

  func testPlayerQueueCanEnqueueAndDequeueOnCorrectType() {
    // given
    let queue = PlayerQueueEntries()
    let firstEntry = audioEntry(id: "1")

    // when
    queue.enqueue(item: firstEntry, type: .upcoming)
    let entry = queue.dequeue(type: .upcoming)
    let entry1 = queue.dequeue(type: .buffering)

    // then
    XCTAssertNotNil(entry)
    XCTAssertNil(entry1)
    XCTAssertEqual(firstEntry, entry)
  }

  func testPlayerQueueCanEnqueueAndDequeue() {
    // given
    let queue = PlayerQueueEntries()
    let firstEntry = audioEntry(id: "1")
    let secondEntry = audioEntry(id: "2")

    // when
    queue.enqueue(item: firstEntry, type: .upcoming)
    queue.enqueue(item: secondEntry, type: .buffering)
    let entry = queue.dequeue(type: .upcoming)
    let entry1 = queue.dequeue(type: .buffering)

    // then
    XCTAssertNotNil(entry)
    XCTAssertNotNil(entry1)
    XCTAssertEqual(firstEntry, entry)
  }

  func testPlayerQueueCanOutputPendingAudioEntryIds() {
    // given
    let queue = PlayerQueueEntries()
    let firstEntry = audioEntry(id: "1")
    let secondEntry = audioEntry(id: "2")

    // when
    queue.enqueue(item: firstEntry, type: .upcoming)
    queue.enqueue(item: secondEntry, type: .buffering)

    // then
    let expected = [firstEntry.id, secondEntry.id]
    let entries = queue.pendingEntriesId()
    XCTAssertFalse(entries.isEmpty)
    XCTAssertEqual(entries, expected)
  }

  func testPlayerQueueEntriesCanSkipQueues() {
    let queue = PlayerQueueEntries()

    let firstEntry = audioEntry(id: "1")
    let secondEntry = audioEntry(id: "2")
    let batchEntries = [audioEntry(id: "3"), audioEntry(id: "4")]

    queue.enqueue(item: firstEntry, type: .buffering)
    queue.skip(item: secondEntry, type: .buffering)

    let entry = queue.dequeue(type: .buffering)
    XCTAssertEqual(entry, secondEntry)

    queue.skip(items: batchEntries, type: .buffering)
    let entry1 = queue.dequeue(type: .buffering)
    XCTAssertEqual(entry1, batchEntries.last!)
  }

  func testPlayerQueueCountReturnsCorrectValue() {
    let queue = PlayerQueueEntries()

    queue.enqueue(item: audioEntry(id: "1"), type: .buffering)
    XCTAssertEqual(queue.count, 1)
    XCTAssertEqual(queue.count(for: .buffering), 1)
    XCTAssertEqual(queue.count(for: .upcoming), 0)

    queue.enqueue(item: audioEntry(id: "2"), type: .upcoming)
    XCTAssertEqual(queue.count, 2)
    XCTAssertEqual(queue.count(for: .buffering), 1)
    XCTAssertEqual(queue.count(for: .upcoming), 1)

    queue.enqueue(item: audioEntry(id: "3"), type: .buffering)
    XCTAssertEqual(queue.count, 3)
    XCTAssertEqual(queue.count(for: .buffering), 2)
    XCTAssertEqual(queue.count(for: .upcoming), 1)

    queue.enqueue(item: audioEntry(id: "4"), type: .upcoming)
    XCTAssertEqual(queue.count, 4)
    XCTAssertEqual(queue.count(for: .buffering), 2)
    XCTAssertEqual(queue.count(for: .upcoming), 2)

    _ = queue.dequeue(type: .upcoming)
    XCTAssertEqual(queue.count, 3)
    XCTAssertEqual(queue.count(for: .buffering), 2)
    XCTAssertEqual(queue.count(for: .upcoming), 1)
  }

  func testPlayerQueueCanRemoveAllElemenets() {
    let queue = PlayerQueueEntries()

    for i in 0 ..< 10 {
      queue.enqueue(item: audioEntry(id: "\(i)"), type: .buffering)
      queue.enqueue(item: audioEntry(id: "\(i)"), type: .upcoming)
    }

    queue.removeAll(for: .buffering)
    XCTAssertEqual(queue.count(for: .buffering), 0)
    XCTAssertEqual(queue.count(for: .upcoming), 10)

    queue.removeAll(for: .upcoming)
    XCTAssertEqual(queue.count(for: .upcoming), 0)
  }

  func testPlayerQueueThreadSafety() {
    var queue = PlayerQueueEntries()

    DispatchQueue.concurrentPerform(iterations: 100) { i in
      queue.enqueue(item: audioEntry(id: "\(i))"), type: .buffering)
      queue.enqueue(item: audioEntry(id: "\(i))"), type: .upcoming)
      _ = queue.dequeue(type: .buffering)
      _ = queue.dequeue(type: .upcoming)
    }

    XCTAssertTrue(queue.isEmpty)

    queue = PlayerQueueEntries()

    DispatchQueue.concurrentPerform(iterations: 100) { i in
      let entry = audioEntry(id: "\(i))")
      queue.enqueue(item: entry, type: .buffering)
      _ = queue.count(for: .buffering)
    }

    XCTAssertEqual(queue.count(for: .buffering), 100)

    queue = PlayerQueueEntries()

    DispatchQueue.concurrentPerform(iterations: 100) { i in
      let entry = audioEntry(id: "\(i))")
      queue.enqueue(item: entry, type: .buffering)
      _ = queue.pendingEntriesId()
    }

    XCTAssertEqual(queue.pendingEntriesId().count, 100)
  }
}

private let networkingClient = NetworkingClient(configuration: .ephemeral)
private func audioEntry(id: String) -> AudioEntry {
  let source =
    RemoteAudioSource(
      networking: networkingClient,
      url: URL(string: "www.a-url.com")!,
      underlyingQueue: DispatchQueue(label: "some-queue"),
      httpHeaders: [:]
    )
  let outputFormat = AVAudioFormat()
  return AudioEntry(source: source, entryId: AudioEntryId(id: id), outputAudioFormat: outputFormat)
}
