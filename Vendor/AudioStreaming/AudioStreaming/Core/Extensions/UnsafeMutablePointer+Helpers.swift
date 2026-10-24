//
//  Created by Dimitrios Chatzieleftheriou on 29/05/2020.
//  Copyright © 2020 Decimal. All rights reserved.
//

import Foundation

extension UnsafeMutablePointer where Pointee == UInt8 {
  /// Allocates and performs binding to memory of an `UnsafeMutableRawPointer` to `UnsafeMutablePointer<UInt8>`
  static func uint8pointer(of size: Int) -> UnsafeMutablePointer<UInt8> {
    let alignment = MemoryLayout<UInt8>.alignment
    return UnsafeMutableRawPointer
      .allocate(byteCount: size, alignment: alignment)
      .bindMemory(to: UInt8.self, capacity: size)
  }
}

extension UnsafeMutableRawPointer {
  /// Converts an UnsafeMutableRawPointer to the given Object type
  func to<Object: AnyObject>(type _: Object.Type) -> Object {
    Unmanaged<Object>.fromOpaque(self).takeUnretainedValue()
  }

  /// Converts the given object to an UnsafeMutableRawPointer
  static func from<Object: AnyObject>(object: Object) -> UnsafeMutableRawPointer {
    Unmanaged<Object>.passUnretained(object).toOpaque()
  }
}
