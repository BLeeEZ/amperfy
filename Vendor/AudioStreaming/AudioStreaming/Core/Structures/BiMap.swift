//
//  Created by Dimitrios Chatzieleftheriou on 26/05/2020.
//  Copyright © 2020 Decimal. All rights reserved.
//

import Foundation

/// A convenient type that holds tasks in a two-way manner, such as `URLSessionTask` to `NetworkDataStream` and reversed
struct BiMap<Left, Right> where Left: Hashable, Right: Hashable {
  private var leftToRight: [Left: Right] = [:]
  private var rightToLeft: [Right: Left] = [:]

  var isEmpty: Bool {
    leftValues.isEmpty && rightValues.isEmpty
  }

  var leftValues: [Left] {
    leftToRight.lazy.map(\.key)
  }

  var rightValues: [Right] {
    leftToRight.lazy.map(\.value)
  }

  subscript(_ left: Left) -> Right? {
    get { leftToRight[left] }
    set {
      guard let newValue = newValue else {
        guard let right = leftToRight[left] else {
          assertionFailure("inconsistency error: no right value found for left key")
          return
        }
        leftToRight.removeValue(forKey: left)
        rightToLeft.removeValue(forKey: right)
        return
      }
      leftToRight[left] = newValue
      rightToLeft[newValue] = left
    }
  }

  subscript(_ right: Right) -> Left? {
    get { rightToLeft[right] }
    set {
      guard let newValue = newValue else {
        guard let left = rightToLeft[right] else {
          assertionFailure("inconsistency error: no left value found for right key")
          return
        }
        leftToRight.removeValue(forKey: left)
        rightToLeft.removeValue(forKey: right)
        return
      }

      rightToLeft[right] = newValue
      leftToRight[newValue] = right
    }
  }
}
