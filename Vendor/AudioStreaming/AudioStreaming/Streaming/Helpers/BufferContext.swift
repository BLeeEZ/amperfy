//
//  Created by Dimitrios Chatzieleftheriou on 05/08/2020.
//  Copyright © 2020 Decimal. All rights reserved.
//

import Foundation

final class BufferContext {
  let sizeInBytes: UInt32
  let totalFrameCount: UInt32

  var frameStartIndex: UInt32 = 0
  var frameUsedCount: UInt32 = 0

  var end: UInt32 {
    #if DEBUG
      assert(
        frameStartIndex < totalFrameCount,
        "frameStartIndex (\(frameStartIndex)) exceeds totalFrameCount (\(totalFrameCount)) - logic error!"
      )
      assert(
        frameUsedCount <= totalFrameCount,
        "frameUsedCount (\(frameUsedCount)) exceeds totalFrameCount (\(totalFrameCount)) - logic error!"
      )
    #endif
    return (frameStartIndex + frameUsedCount) % totalFrameCount
  }

  init(sizeInBytes: UInt32, totalFrameCount: UInt32) {
    self.sizeInBytes = sizeInBytes
    self.totalFrameCount = totalFrameCount
  }

  func reset() {
    frameStartIndex = 0
    frameUsedCount = 0
  }
}
