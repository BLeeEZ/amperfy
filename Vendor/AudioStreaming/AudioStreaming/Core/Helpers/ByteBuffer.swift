//
//  Created by Dimitrios Chatzieleftheriou on 4/03/2024.
//  Copyright © 2024 Decimal. All rights reserved.
//

import Foundation

// MARK: - ByteBuffer

// Struct representing a buffer for handling binary data
struct ByteBuffer {
  // Custom errors for ByteBuffer
  enum Error: Swift.Error {
    case eof // End of file
    case parse // Parsing error
  }

  // Data storage for the buffer
  private(set) var storage = Data()

  // Current offset in the buffer
  var offset: Int = 0

  // Calculated property for the number of bytes available for reading
  var bytesAvailable: Int {
    storage.count - offset
  }

  // Calculated property for the length of the buffer
  var length: Int {
    get {
      storage.count
    }
    set {
      // Adjusting the length of the buffer
      switch true {
      case storage.count < newValue:
        storage.append(Data(count: newValue - storage.count))
      case newValue < storage.count:
        storage = storage.subdata(in: 0 ..< newValue)
      default:
        break
      }
    }
  }

  // Subscript for accessing individual bytes in the buffer
  subscript(i: Int) -> UInt8 {
    get { storage[i] }
    set { storage[i] = newValue }
  }

  // Initialize the buffer with given data
  init(data: Data) {
    self.storage = data
    self.offset = 0
  }

  // Initialize the buffer with a specified size, filling it with zeros
  init(size: Int) {
    self.storage = Data(repeating: 0x00, count: size)
    self.offset = 0
  }

  // Clear the buffer (reset offset to zero)
  @discardableResult
  mutating func clear() -> Self {
    offset = 0
    return self
  }

  // Rewind the buffer (reset offset to zero)
  mutating func rewind() {
    offset = 0
  }

  // Read a specified number of bytes from the buffer
  mutating func readBytes(_ length: Int) throws -> Data {
    guard length <= bytesAvailable else {
      throw ByteBuffer.Error.eof
    }
    offset += length
    return storage.subdata(in: offset - length ..< offset)
  }

  // Write data into the buffer
  @discardableResult
  mutating func writeBytes(_ value: Data) -> Self {
    // If the offset is at the end, append the value to the data
    if offset == storage.count {
      storage.append(value)
      offset = storage.count
      return self
    }
    // Otherwise, write the value into the buffer at the current offset
    let length: Int = min(storage.count, value.count)
    storage[offset ..< offset + length] = value[0 ..< length]
    // If the value is longer than the remaining space, append the rest to the data
    if length == storage.count {
      storage.append(value[length ..< value.count])
    }
    offset += value.count
    return self
  }

  // Write integer value into the buffer
  @discardableResult
  mutating func put<T: FixedWidthInteger>(_ value: T) -> ByteBuffer {
    writeBytes(value.data)
  }

  // Write float value into the buffer
  @discardableResult
  mutating func put(_ value: Float) -> ByteBuffer {
    writeBytes(Data(value.data.reversed()))
  }

  // Write double value into the buffer
  @discardableResult
  mutating func put(_ value: Double) -> ByteBuffer {
    writeBytes(Data(value.data.reversed()))
  }

  // Read an integer value from the buffer
  mutating func getInteger<T: FixedWidthInteger>() throws -> T {
    let sizeOfInteger = MemoryLayout<T>.size
    guard sizeOfInteger <= bytesAvailable else {
      throw ByteBuffer.Error.eof
    }
    offset += sizeOfInteger
    return T(data: storage[offset - sizeOfInteger ..< offset]).bigEndian
  }

  // Read an integer value from a specific index in the buffer
  func getInteger<T: FixedWidthInteger>(_ index: Int) throws -> T {
    let sizeOfInteger = MemoryLayout<T>.size
    guard sizeOfInteger + index <= length else {
      throw ByteBuffer.Error.eof
    }
    return T(data: storage[index ..< index + sizeOfInteger]).bigEndian
  }

  // Read a float value from the buffer
  mutating func getFloat() throws -> Float {
    let sizeOfFloat = MemoryLayout<UInt32>.size
    guard sizeOfFloat <= bytesAvailable else {
      throw ByteBuffer.Error.eof
    }
    offset += sizeOfFloat
    return Float(data: Data(storage.subdata(in: offset - sizeOfFloat ..< offset).reversed()))
  }

  // Read a double value from the buffer
  mutating func getDouble() throws -> Double {
    let sizeOfDouble = MemoryLayout<UInt64>.size
    guard sizeOfDouble <= bytesAvailable else {
      throw ByteBuffer.Error.eof
    }
    offset += sizeOfDouble
    return Double(data: Data(storage.subdata(in: offset - sizeOfDouble ..< offset).reversed()))
  }
}

// Extension to provide conformance to ExpressibleByIntegerLiteral for easy conversion between integers and Data
extension ExpressibleByIntegerLiteral {
  // Convert integer to Data
  var data: Data {
    withUnsafePointer(to: self) { pointer in
      Data(bytes: pointer, count: MemoryLayout<Self>.size)
    }
  }

  // Initialize from Data
  init(data: Data) {
    let diff: Int = MemoryLayout<Self>.size - data.count
    if diff > 0 {
      var buffer = Data(repeating: 0, count: diff)
      buffer.append(data)
      self = buffer.withUnsafeBytes { $0.baseAddress!.assumingMemoryBound(to: Self.self).pointee }
      return
    }
    self = data.withUnsafeBytes { $0.baseAddress!.assumingMemoryBound(to: Self.self).pointee }
  }

  // Initialize from Data slice
  init(data: Slice<Data>) {
    self.init(data: Data(data))
  }
}
