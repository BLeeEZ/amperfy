//
// Copyright © Blockchain Luxembourg S.A. All rights reserved.

@testable import AudioStreaming
import XCTest

final class ByteBufferTests: XCTestCase {
  func testWriteAndReadBytes() {
    var buffer = ByteBuffer(size: 10)

    // Write bytes to the buffer
    let testData = Data([0x01, 0x02, 0x03, 0x04])
    buffer.writeBytes(testData)
    buffer.rewind()

    // Read the written bytes
    do {
      let readData = try buffer.readBytes(4)
      XCTAssertEqual(readData, testData)
    } catch {
      XCTFail("Error reading bytes: \(error)")
    }
  }

  func testWriteAndReadInteger() {
    var buffer = ByteBuffer(size: 8)

    // Write integer to the buffer
    let testInteger: UInt32 = 123_456_789
    buffer.put(testInteger)
    buffer.rewind()

    // Read the written integer
    do {
      let readInteger: UInt32 = try buffer.getInteger()
      XCTAssertEqual(readInteger, testInteger.bigEndian)
    } catch {
      XCTFail("Error reading integer: \(error)")
    }
  }

  func testWriteAndReadFloat() {
    var buffer = ByteBuffer(size: 8)

    // Write float to the buffer
    let testFloat: Float = 123.456
    buffer.put(testFloat)
    buffer.rewind()

    // Read the written float
    do {
      let readFloat: Float = try buffer.getFloat()
      XCTAssertEqual(readFloat, testFloat, accuracy: 0.001)
    } catch {
      XCTFail("Error reading float: \(error)")
    }
  }

  func testWriteAndReadDouble() {
    var buffer = ByteBuffer(size: 8)

    // Write double to the buffer
    let testDouble = 123.456
    buffer.put(testDouble)
    buffer.rewind()

    // Read the written double
    do {
      let readDouble: Double = try buffer.getDouble()
      XCTAssertEqual(readDouble, testDouble, accuracy: 0.001)
    } catch {
      XCTFail("Error reading double: \(error)")
    }
  }
}
